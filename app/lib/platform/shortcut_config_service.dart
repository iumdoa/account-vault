import 'dart:convert';
import 'dart:io';

class ShortcutConfigException implements Exception {
  final String message;
  const ShortcutConfigException(this.message);

  @override
  String toString() => 'ShortcutConfigException: $message';
}

class ExistingBinding {
  final String key;
  final String? title;
  final String? action;

  const ExistingBinding({required this.key, this.title, this.action});
}

class ShortcutConfigService {
  final String? customConfigPath;
  final String? customLauncherPath;
  final String? customSettingsPath;
  final Future<ProcessResult> Function(
    String executable,
    List<String> arguments,
  )?
  processRunner;

  ShortcutConfigService({
    this.customConfigPath,
    this.customLauncherPath,
    this.customSettingsPath,
    this.processRunner,
  });

  String get _niriConfigPath {
    if (customConfigPath != null) return customConfigPath!;
    final niriEnv = Platform.environment['NIRI_CONFIG'];
    if (niriEnv != null && niriEnv.isNotEmpty) return niriEnv;
    final xdgConfig = Platform.environment['XDG_CONFIG_HOME'];
    if (xdgConfig != null && xdgConfig.isNotEmpty) {
      return '$xdgConfig/niri/config.kdl';
    }
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.config/niri/config.kdl';
  }

  String get _launcherPath {
    if (customLauncherPath != null) return customLauncherPath!;
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.local/bin/account-vault';
  }

  String get _settingsPath {
    if (customSettingsPath != null) return customSettingsPath!;
    final xdgData = Platform.environment['XDG_DATA_HOME'];
    if (xdgData != null && xdgData.isNotEmpty) {
      return '$xdgData/account-vault/settings.json';
    }
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.local/share/account-vault/settings.json';
  }

  bool isNiriConfigAvailable() {
    return File(_niriConfigPath).existsSync();
  }

  String getConfigFilePath() => _niriConfigPath;

  /// Retrieves the current shortcut configured in niri or settings.
  Future<String> getCurrentShortcut() async {
    final configFile = File(_niriConfigPath);
    if (configFile.existsSync()) {
      try {
        final content = await configFile.readAsString();
        final pattern = RegExp(
          r'^\s*([A-Za-z0-9_+-]+)\s+(?:repeat=\S+\s+)?(?:hotkey-overlay-title="[^"]*Account Vault[^"]*"\s+)?\{\s*spawn\s+"[^"]*account-vault"\s+"--show";\s*\}',
          multiLine: true,
        );
        final match = pattern.firstMatch(content);
        if (match != null && match.group(1) != null) {
          return match.group(1)!.trim();
        }
      } catch (_) {}
    }

    final settingsFile = File(_settingsPath);
    if (settingsFile.existsSync()) {
      try {
        final json = jsonDecode(await settingsFile.readAsString());
        if (json is Map && json['shortcut'] is String) {
          return json['shortcut'] as String;
        }
      } catch (_) {}
    }

    return 'Super+Alt+P';
  }

  /// Extracts existing non-Account-Vault keybindings from niri config for conflict detection.
  Future<List<ExistingBinding>> getExistingBindings() async {
    final configFile = File(_niriConfigPath);
    if (!configFile.existsSync()) return [];

    try {
      final content = await configFile.readAsString();
      final bindsMatch = RegExp(r'binds\s*\{([\s\S]*?)\n\}')
          .firstMatch(content);
      if (bindsMatch == null) return [];

      final block = bindsMatch.group(1) ?? '';
      final lines = block.split('\n');
      final bindings = <ExistingBinding>[];

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('//')) continue;
        if (line.contains('account-vault') || line.contains('Account Vault')) {
          continue;
        }

        final match = RegExp(
          r'^([A-Za-z0-9_+-]+)(?:\s+repeat=\S+)?(?:\s+hotkey-overlay-title="([^"]*)")?\s*\{\s*([^}]*)\}',
        ).firstMatch(line);

        if (match != null) {
          final key = match.group(1)!.trim();
          final title = match.group(2)?.trim();
          final action = match.group(3)?.trim();
          bindings.add(ExistingBinding(key: key, title: title, action: action));
        }
      }
      return bindings;
    } catch (_) {
      return [];
    }
  }

  /// Checks if [newShortcut] conflicts with an existing binding in niri config.
  Future<ExistingBinding?> checkConflict(String newShortcut) async {
    final current = await getCurrentShortcut();
    if (newShortcut.trim().toLowerCase() == current.trim().toLowerCase()) {
      return null;
    }

    final existing = await getExistingBindings();
    final normalized = newShortcut.trim().toLowerCase();
    for (final bind in existing) {
      if (bind.key.trim().toLowerCase() == normalized) {
        return bind;
      }
    }
    return null;
  }

  /// Atomically updates the shortcut in niri config with validation and fallback.
  Future<void> updateShortcut(String newShortcut) async {
    final trimmed = newShortcut.trim();
    if (trimmed.isEmpty) {
      throw const ShortcutConfigException('快捷键组合不能为空');
    }

    // Key format validation
    if (!RegExp(r'^[A-Za-z0-9_+-]+$').hasMatch(trimmed)) {
      throw const ShortcutConfigException('快捷键格式不合法，请仅使用字母、数字、下划线及 + 连接符');
    }

    final configFile = File(_niriConfigPath);
    if (!configFile.existsSync()) {
      // Non-niri environment: save to settings file only
      await _saveSettings(trimmed);
      return;
    }

    final content = await configFile.readAsString();
    final newBindLine =
        '    $trimmed repeat=false hotkey-overlay-title="Account Vault: Quick Panel" { spawn "$_launcherPath" "--show"; }';

    final pattern = RegExp(
      r'^\s*[A-Za-z0-9_+-]+\s+(?:repeat=\S+\s+)?(?:hotkey-overlay-title="[^"]*Account Vault[^"]*"\s+)?\{\s*spawn\s+"[^"]*account-vault"\s+"--show";\s*\}',
      multiLine: true,
    );

    String newContent;
    if (pattern.hasMatch(content)) {
      newContent = content.replaceAll(pattern, newBindLine);
    } else {
      // If not found, insert inside binds { ... }
      final bindsIndex = content.indexOf('binds {');
      if (bindsIndex != -1) {
        final insertPos = bindsIndex + 'binds {'.length;
        newContent =
            '${content.substring(0, insertPos)}\n    // Account Vault 全局快捷呼出\n$newBindLine\n${content.substring(insertPos)}';
      } else {
        newContent =
            '$content\n\nbinds {\n    // Account Vault 全局快捷呼出\n$newBindLine\n}\n';
      }
    }

    // Step 1: Write candidate file
    final candidateFile = File('$_niriConfigPath.candidate');
    await candidateFile.writeAsString(newContent, flush: true);

    // Step 2: Validate candidate with niri validate
    final runProcess = processRunner ?? Process.run;
    ProcessResult validateResult;
    try {
      validateResult = await runProcess('niri', [
        'validate',
        '-c',
        candidateFile.path,
      ]);
    } catch (e) {
      if (candidateFile.existsSync()) {
        try {
          await candidateFile.delete();
        } catch (_) {}
      }
      throw ShortcutConfigException('执行 niri validate 失败: $e');
    }

    if (validateResult.exitCode != 0) {
      if (candidateFile.existsSync()) {
        try {
          await candidateFile.delete();
        } catch (_) {}
      }
      final err = validateResult.stderr.toString();
      throw ShortcutConfigException(
        'niri 校验配置失败: ${err.isNotEmpty ? err : validateResult.stdout.toString()}',
      );
    }

    // Step 3: Candidate valid -> create backup of original config
    final backupFile = File('$_niriConfigPath.bak');
    await configFile.copy(backupFile.path);

    // Step 4: Atomic rename candidate to real config
    await candidateFile.rename(_niriConfigPath);

    // Step 5: Save to local settings
    await _saveSettings(trimmed);
  }

  Future<void> _saveSettings(String shortcut) async {
    final settingsFile = File(_settingsPath);
    try {
      if (!settingsFile.parent.existsSync()) {
        await settingsFile.parent.create(recursive: true);
      }
      Map<String, dynamic> data = {};
      if (settingsFile.existsSync()) {
        try {
          data = Map<String, dynamic>.from(
            jsonDecode(await settingsFile.readAsString()),
          );
        } catch (_) {}
      }
      data['shortcut'] = shortcut;
      data['updatedAt'] = DateTime.now().toIso8601String();
      await settingsFile.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {}
  }
}
