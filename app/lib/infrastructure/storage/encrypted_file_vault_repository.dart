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

  /// Closes session and clears memory references
  void lock() {
    _sessionKey = null;
    _salt = null;
    _vaultId = null;
    _revision = 0;
    _entries = [];
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
      _entries = decrypted.payload.entries;

      // Commit as new main revision
      await _commitTransaction(_entries);
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
  Future<void> _commitTransaction(List<VaultEntry> nextEntries) async {
    final nextRevision = _revision + 1;
    final nextPayload = DecryptedVaultPayload(
      schemaVersion: DecryptedVaultPayload.currentSchemaVersion,
      vaultId: _vaultId!,
      revision: nextRevision,
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
    final sink = tempFile.openWrite(mode: FileMode.writeOnly);
    sink.write(fileBytes);
    await sink.flush();
    await sink.close();
    await VaultPathProvider.secureFilePermissions(tempFile);

    onAfterWriteTemp?.call();

    // 4. Self-verify temp file before any replacement
    try {
      final verifyContent = await tempFile.readAsString();
      final verifyPkg = EncryptedVaultPackage.deserialize(verifyContent);
      final verifiedPayload = await VaultCryptoService.decrypt(
        package: verifyPkg,
        keyBytes: _sessionKey!,
      );
      if (verifiedPayload.revision != nextRevision) {
        throw const CorruptedFormatException('自检临时文件 revision 校验失败');
      }
    } catch (e) {
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
