import 'dart:io';

import 'package:path/path.dart' as p;

import '../crypto/vault_crypto_service.dart';

/// Manages platform-specific data directories, file paths, and permissions (README Section 7.1)
class VaultPathProvider {
  final Directory directory;

  VaultPathProvider({Directory? customDirectory})
    : directory = customDirectory ?? _resolveDefaultDirectory();

  static Directory _resolveDefaultDirectory() {
    if (Platform.isLinux) {
      final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
      if (xdgDataHome != null && xdgDataHome.trim().isNotEmpty) {
        return Directory(p.join(xdgDataHome, 'account-vault'));
      }
      final home = Platform.environment['HOME'] ?? '';
      return Directory(p.join(home, '.local', 'share', 'account-vault'));
    }

    // Default fallback
    return Directory(p.join(Directory.current.path, '.account-vault-data'));
  }

  File get mainVaultFile => File(p.join(directory.path, 'vault.avlt'));
  File get previousVaultFile =>
      File(p.join(directory.path, 'vault.previous.avlt'));
  File get lockFile => File(p.join(directory.path, 'vault.lock'));

  static String formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y$m$d-$h$min$s';
  }

  static String generateBackupFilename({DateTime? timestamp}) {
    final ts = formatTimestamp(timestamp ?? DateTime.now().toUtc());
    return 'account-vault-backup-$ts.avlt';
  }

  File generatePreRestoreSafetyFile({DateTime? timestamp}) {
    final ts = formatTimestamp(timestamp ?? DateTime.now().toUtc());
    return File(p.join(directory.path, 'vault.pre-restore.$ts.avlt'));
  }

  static Directory resolveDefaultBackupDirectory() {
    final home = Platform.environment['HOME'] ?? '';
    final docs = Directory(p.join(home, 'Documents'));
    if (docs.existsSync()) return docs;
    final homeDir = Directory(home);
    if (homeDir.existsSync()) return homeDir;
    return Directory.current;
  }

  File generateTempFile() {
    final randId = VaultCryptoService.generateSalt()
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .take(8)
        .join();
    return File(p.join(directory.path, 'vault.tmp.$randId.avlt'));
  }

  /// Ensures directory exists with restrictive permissions (0700 on POSIX)
  Future<void> ensureDirectoryReady() async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      if (Platform.isLinux || Platform.isMacOS) {
        try {
          await Process.run('chmod', ['0700', directory.path]);
        } catch (_) {}
      }
    }
  }

  /// Sets restrictive file permissions (0600 on POSIX)
  static Future<void> secureFilePermissions(File file) async {
    if (Platform.isLinux || Platform.isMacOS) {
      if (await file.exists()) {
        try {
          await Process.run('chmod', ['0600', file.path]);
        } catch (_) {}
      }
    }
  }

  /// Cleans up orphan temporary files (.tmp.*.avlt)
  Future<void> cleanOrphanTempFiles() async {
    if (!await directory.exists()) return;

    try {
      final entities = await directory.list().toList();
      for (final entity in entities) {
        if (entity is File) {
          final filename = p.basename(entity.path);
          if (filename.startsWith('vault.tmp.') && filename.endsWith('.avlt')) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}
