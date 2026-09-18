import 'dart:io';

/// Interacts with native desktop dialog tools (e.g. zenity on Linux) with graceful fallback
class NativeDialogService {
  static bool? _zenityAvailable;

  static Future<bool> isZenityAvailable() async {
    if (_zenityAvailable != null) return _zenityAvailable!;
    if (!Platform.isLinux) {
      _zenityAvailable = false;
      return false;
    }
    try {
      final res = await Process.run('which', ['zenity']);
      _zenityAvailable = res.exitCode == 0;
    } catch (_) {
      _zenityAvailable = false;
    }
    return _zenityAvailable!;
  }

  /// Prompts user to pick a save destination file
  static Future<String?> pickSaveFile({
    required String defaultFilename,
    String? initialDirectory,
  }) async {
    if (await isZenityAvailable()) {
      try {
        final defaultPath = initialDirectory != null
            ? '$initialDirectory/$defaultFilename'
            : defaultFilename;
        final res = await Process.run('zenity', [
          '--file-selection',
          '--save',
          '--confirm-overwrite',
          '--title=导出加密备份',
          '--filename=$defaultPath',
          '--file-filter=Account Vault (*.avlt) | *.avlt',
          '--file-filter=All Files | *',
        ]);
        if (res.exitCode == 0) {
          final path = res.stdout.toString().trim();
          if (path.isNotEmpty) return path;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Prompts user to pick an existing backup file to restore
  static Future<String?> pickOpenFile({String? initialDirectory}) async {
    if (await isZenityAvailable()) {
      try {
        final args = <String>[
          '--file-selection',
          '--title=选择备份文件',
          '--file-filter=Account Vault (*.avlt) | *.avlt',
          '--file-filter=All Files | *',
        ];
        if (initialDirectory != null) {
          args.add('--filename=$initialDirectory/');
        }
        final res = await Process.run('zenity', args);
        if (res.exitCode == 0) {
          final path = res.stdout.toString().trim();
          if (path.isNotEmpty) return path;
        }
      } catch (_) {}
    }
    return null;
  }
}
