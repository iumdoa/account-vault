import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/models/vault_entry.dart';
import '../../domain/repositories/vault_repository.dart';
import '../../domain/services/uuid_service.dart';
import '../crypto/vault_crypto_service.dart';
import '../crypto/vault_crypto_types.dart';
import 'vault_path_provider.dart';

/// Exception thrown when trying to create a vault that already exists
class VaultAlreadyExistsException extends VaultCryptoException {
  const VaultAlreadyExistsException([super.message = '账号库已存在，无法重复创建']);
}

/// Exception thrown when trying to perform operations without an active unlocked session
class VaultLockedException extends VaultCryptoException {
  const VaultLockedException([super.message = '账号库尚未解锁']);
}

/// Production encrypted file repository adhering strictly to transactional atomic
/// saving, backup rotation, and fault recovery (README Section 7).
class EncryptedFileVaultRepository implements VaultRepository {
  final VaultPathProvider pathProvider;

  // Serial queue to guarantee all modifications are strictly sequential
  Future<void> _lastTransaction = Future.value();

  // Active in-memory session state
  Uint8List? _sessionKey;
  Uint8List? _salt;
  String? _vaultId;
  int _revision = 0;
  List<VaultEntry> _entries = [];
  Set<String> _protectedGroups = {};

  // Fault injection hooks for unit testing failure scenarios
  void Function()? onBeforeWriteTemp;
  void Function()? onAfterWriteTemp;
  void Function()? onBeforeBackupPrevious;
  void Function()? onBeforeRenameMain;

  EncryptedFileVaultRepository({required this.pathProvider});

  bool get isUnlocked => _sessionKey != null;
  String? get vaultId => _vaultId;
  int get revision => _revision;
  Uint8List? get sessionKey => _sessionKey;
  Uint8List? get salt => _salt;

  @override
  Set<String> get protectedGroups => Set.unmodifiable(_protectedGroups);

  @override
  Future<void> setProtectedGroups(Set<String> groups) async {
    if (!isUnlocked) throw const VaultLockedException();
    return _enqueue(() async {
      await _commitTransaction(_entries, nextProtectedGroups: groups);
    });
  }

  /// Closes session and clears memory references
  void lock() {
    _sessionKey = null;
    _salt = null;
    _vaultId = null;
    _revision = 0;
    _entries = [];
    _protectedGroups = {};
  }

  /// Verifies whether the candidate password matches the current session key
  Future<bool> verifyMasterPassword(String password) async {
    if (_sessionKey == null || _salt == null) return false;
    try {
      final candidateKey = await VaultCryptoService.deriveKey(
        password: password,
        salt: _salt!,
      );
      if (candidateKey.length != _sessionKey!.length) return false;
      var diff = 0;
      for (var i = 0; i < candidateKey.length; i++) {
        diff |= candidateKey[i] ^ _sessionKey![i];
      }
      return diff == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> vaultExists() async {
    return await pathProvider.mainVaultFile.exists();
  }

  Future<bool> previousExists() async {
    return await pathProvider.previousVaultFile.exists();
  }

  /// Creates a brand new encrypted vault file (README Section 7.2)
  Future<void> createVault({
    required String masterPassword,
    List<VaultEntry>? initialEntries,
  }) async {
    await pathProvider.ensureDirectoryReady();

    if (await pathProvider.mainVaultFile.exists()) {
      throw const VaultAlreadyExistsException();
    }

    final newSalt = VaultCryptoService.generateSalt();
    final newKey = await VaultCryptoService.deriveKey(
      password: masterPassword,
      salt: newSalt,
    );
    final newVaultId = UuidService.generateV4();
    final entries = initialEntries ?? const <VaultEntry>[];

    _sessionKey = newKey;
    _salt = newSalt;
    _vaultId = newVaultId;
    _revision = 0;
    _entries = [];

    return _enqueue(() async {
      await _commitTransaction(entries);
    });
  }

  /// Unlocks existing vault using master password
  Future<List<VaultEntry>> unlock({required String masterPassword}) async {
    final file = pathProvider.mainVaultFile;
    if (!await file.exists()) {
      throw const CorruptedFormatException('账号库文件不存在');
    }

    final payload = await _readAndDecryptFile(file, masterPassword);
    _sessionKey = payload.sessionKey;
    _salt = payload.salt;
    _vaultId = payload.payload.vaultId;
    _revision = payload.payload.revision;
    _protectedGroups = Set<String>.from(payload.payload.protectedGroups);
    _entries = payload.payload.entries;

    // Clean up any orphan temp files on startup
    await pathProvider.cleanOrphanTempFiles();

    return List<VaultEntry>.unmodifiable(_entries);
  }

  /// Inspects and decrypts a specific file (used for previous vault recovery verification)
  Future<
    ({DecryptedVaultPayload payload, Uint8List sessionKey, Uint8List salt})
  >
  _readAndDecryptFile(File file, String masterPassword) async {
    final length = await file.length();
    if (length > EncryptedVaultPackage.maxFileBytes) {
      throw const FileTooLargeException();
    }

    final jsonString = await file.readAsString();
    final package = EncryptedVaultPackage.deserialize(jsonString);

    // Validate header whitelist before executing KDF
    final header = VaultHeader.parseAndValidate(package.rawHeaderBytes);

    final key = await VaultCryptoService.deriveKey(
      password: masterPassword,
      salt: header.salt,
    );

    final decrypted = await VaultCryptoService.decrypt(
      package: package,
      keyBytes: key,
    );

    return (payload: decrypted, sessionKey: key, salt: header.salt);
  }

  @override
  Future<List<VaultEntry>> getAll() async {
    if (!isUnlocked) throw const VaultLockedException();
    return List<VaultEntry>.unmodifiable(_entries);
  }

  @override
  Future<VaultEntry?> getById(String id) async {
    if (!isUnlocked) throw const VaultLockedException();
    return _entries.cast<VaultEntry?>().firstWhere(
      (e) => e?.id == id,
      orElse: () => null,
    );
  }

  @override
  Future<void> save(VaultEntry entry) async {
    if (!isUnlocked) throw const VaultLockedException();

    return _enqueue(() async {
      final updatedList = List<VaultEntry>.from(_entries);
      final index = updatedList.indexWhere((e) => e.id == entry.id);
      if (index >= 0) {
        updatedList[index] = entry;
      } else {
        updatedList.add(entry);
      }
      await _commitTransaction(updatedList);
    });
  }

  @override
  Future<void> delete(String id) async {
    if (!isUnlocked) throw const VaultLockedException();

    return _enqueue(() async {
      final updatedList = List<VaultEntry>.from(_entries)
        ..removeWhere((e) => e.id == id);
      await _commitTransaction(updatedList);
    });
  }

  /// Replaces the entire vault entries (used for restore)
  Future<void> replaceAllEntries(List<VaultEntry> newEntries) async {
    if (!isUnlocked) throw const VaultLockedException();

    return _enqueue(() async {
      await _commitTransaction(newEntries);
    });
  }

  /// Restores vault from vault.previous.avlt
  Future<void> restoreFromPrevious(String masterPassword) async {
    final prevFile = pathProvider.previousVaultFile;
    if (!await prevFile.exists()) {
      throw const CorruptedFormatException('回退文件不存在');
    }

    final decrypted = await _readAndDecryptFile(prevFile, masterPassword);

    return _enqueue(() async {
      _sessionKey = decrypted.sessionKey;
      _salt = decrypted.salt;
      _vaultId = decrypted.payload.vaultId;
      _revision = decrypted.payload.revision;
      _protectedGroups = Set<String>.from(decrypted.payload.protectedGroups);
      _entries = decrypted.payload.entries;

      // Commit as new main revision
      await _commitTransaction(_entries, nextProtectedGroups: _protectedGroups);
    });
  }

  /// Exports an independent, encrypted snapshot backup to [destinationFile] (README Section 9.1).
  /// Verifies the exported file immediately by decrypting and checking integrity.
  Future<void> exportBackup(File destinationFile) async {
    if (!isUnlocked) throw const VaultLockedException();

    // Prevent exporting directly over main, previous, or lock file
    final destPath = destinationFile.absolute.path;
    if (destPath == pathProvider.mainVaultFile.absolute.path ||
        destPath == pathProvider.previousVaultFile.absolute.path ||
        destPath == pathProvider.lockFile.absolute.path) {
      throw const CorruptedFormatException('导出目标不能是当前主库或回退库');
    }

    return _enqueue(() async {
      final mainFile = pathProvider.mainVaultFile;
      if (!await mainFile.exists()) {
        throw const CorruptedFormatException('主库文件不存在，无法导出备份');
      }

      // Ensure parent directory exists
      final parentDir = destinationFile.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      // Write atomically via a temp file in destination's directory
      final tempDest = File('${destinationFile.path}.tmp');
      await mainFile.copy(tempDest.path);
      await VaultPathProvider.secureFilePermissions(tempDest);

      // Self-verify backup file before finalizing
      try {
        final verifyContent = await tempDest.readAsString();
        final verifyPkg = EncryptedVaultPackage.deserialize(verifyContent);
        final verified = await VaultCryptoService.decrypt(
          package: verifyPkg,
          keyBytes: _sessionKey!,
        );
        if (verified.entries.length != _entries.length) {
          throw const CorruptedFormatException('备份文件自检校验记录数不一致');
        }
      } catch (e) {
        try {
          await tempDest.delete();
        } catch (_) {}
        rethrow;
      }

      // Finalize atomic move
      await tempDest.rename(destinationFile.path);
      await VaultPathProvider.secureFilePermissions(destinationFile);
    });
  }

  /// Previews an external backup file without modifying current state (README Section 9.2)
  Future<DecryptedVaultPayload> previewBackup({
    required File backupFile,
    required String masterPassword,
  }) async {
    if (!await backupFile.exists()) {
      throw const CorruptedFormatException('备份文件不存在');
    }

    final result = await _readAndDecryptFile(backupFile, masterPassword);
    return result.payload;
  }

  /// Restores entire vault from external [backupFile] using its [masterPassword] (README Section 9.2).
  /// Generates a safety pre-restore backup of the existing vault before overwriting.
  Future<File?> restoreFromBackup({
    required File backupFile,
    required String masterPassword,
  }) async {
    if (!await backupFile.exists()) {
      throw const CorruptedFormatException('备份文件不存在');
    }

    // Decrypt and validate backup first
    final decrypted = await _readAndDecryptFile(backupFile, masterPassword);

    return _enqueue(() async {
      File? safetyBackupFile;
      final mainFile = pathProvider.mainVaultFile;
      if (await mainFile.exists()) {
        safetyBackupFile = pathProvider.generatePreRestoreSafetyFile();
        await mainFile.copy(safetyBackupFile.path);
        await VaultPathProvider.secureFilePermissions(safetyBackupFile);
      }

      // Adopt backup credentials and state
      _sessionKey = decrypted.sessionKey;
      _salt = decrypted.salt;
      _vaultId = decrypted.payload.vaultId;
      _revision = decrypted.payload.revision;
      _protectedGroups = Set<String>.from(decrypted.payload.protectedGroups);
      _entries = decrypted.payload.entries;

      // Commit as active main vault
      await _commitTransaction(_entries, nextProtectedGroups: _protectedGroups);

      return safetyBackupFile;
    });
  }

  /// Atomic transactional save pipeline adhering strictly to README Section 7.2:
  /// 1. Next revision candidate.
  /// 2. Encrypt to new file bytes.
  /// 3. Write to unique temp file, flush and close.
  /// 4. Read back & verify temp file can be decrypted and revision is valid.
  /// 5. If main vault exists, copy main vault to temp file, flush, and atomically rename to previous.
  /// 6. Atomically rename new temp file to overwrite main vault.
  /// 7. Update in-memory state and publish success.
  Future<void> _commitTransaction(
    List<VaultEntry> nextEntries, {
    Set<String>? nextProtectedGroups,
  }) async {
    final targetProtectedGroups = nextProtectedGroups ?? _protectedGroups;
    final nextRevision = _revision + 1;
    final nextPayload = DecryptedVaultPayload(
      schemaVersion: DecryptedVaultPayload.currentSchemaVersion,
      vaultId: _vaultId!,
      revision: nextRevision,
      protectedGroups: targetProtectedGroups,
      entries: nextEntries,
    );

    // 2. Encrypt candidate snapshot
    final package = await VaultCryptoService.encrypt(
      payload: nextPayload,
      keyBytes: _sessionKey!,
      salt: _salt!,
    );
    final fileBytes = package.serialize();

    onBeforeWriteTemp?.call();

    // 3. Write to unique temp file
    final tempFile = pathProvider.generateTempFile();
    await tempFile.writeAsString(fileBytes, flush: true);
    await VaultPathProvider.secureFilePermissions(tempFile);

    onAfterWriteTemp?.call();

    // 4. Self-verify temp file before any replacement
    try {
      final verifyContent = await tempFile.readAsString();
      final verifyPackage = EncryptedVaultPackage.deserialize(verifyContent);
      final decrypted = await VaultCryptoService.decrypt(
        package: verifyPackage,
        keyBytes: _sessionKey!,
      );
      if (decrypted.revision != nextRevision) {
        throw const CorruptedFormatException('自检版本号与预期不符');
      }
    } catch (_) {
      try {
        await tempFile.delete();
      } catch (_) {}
      rethrow;
    }

    onBeforeBackupPrevious?.call();

    // 5. If main vault exists, rotate to vault.previous.avlt atomically
    final mainFile = pathProvider.mainVaultFile;
    if (await mainFile.exists()) {
      final backupTemp = pathProvider.generateTempFile();
      await mainFile.copy(backupTemp.path);
      await VaultPathProvider.secureFilePermissions(backupTemp);
      await backupTemp.rename(pathProvider.previousVaultFile.path);
    }

    onBeforeRenameMain?.call();

    // 6. Atomically rename temp file over main vault (NEVER delete main first!)
    await tempFile.rename(mainFile.path);

    // 7. Publish updated in-memory state
    _revision = nextRevision;
    _entries = List.unmodifiable(nextEntries);
    _protectedGroups = Set<String>.from(targetProtectedGroups);
  }

  /// Serializes operations to avoid concurrent file overwrite races
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _lastTransaction = _lastTransaction.then(
      (_) async {
        try {
          final res = await action();
          completer.complete(res);
        } catch (e, st) {
          completer.completeError(e, st);
        }
      },
      onError: (_) async {
        try {
          final res = await action();
          completer.complete(res);
        } catch (e, st) {
          completer.completeError(e, st);
        }
      },
    );
    return completer.future;
  }
}
