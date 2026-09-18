import 'dart:io';

import 'package:account_vault/platform/shortcut_config_service.dart';
import 'package:account_vault/presentation/widgets/settings_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShortcutConfigService Tests', () {
    late Directory tempDir;
    late File niriConfigFile;
    late File settingsFile;

    const sampleKdl = '''
window-rule {
    match app-id=r#"^dev\\.local\\.account_vault\$"#
    open-floating true
}

binds {
    Ctrl+T hotkey-overlay-title="Open a Terminal: alacritty" { spawn "alacritty"; }
    Ctrl+D hotkey-overlay-title="Run an Application: fuzzel" { spawn "fuzzel"; }
    Alt+A hotkey-overlay-title="WeChat Screenshot" { spawn "niri-portal-shortcuts" "trigger" "Alt+A"; }

    // Account Vault 全局快捷呼出
    Super+Alt+P repeat=false hotkey-overlay-title="Account Vault: Quick Panel" { spawn "/home/iumdoa/.local/bin/account-vault" "--show"; }

    Ctrl+Left  { focus-column-left; }
}
''';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('shortcut_test_');
      niriConfigFile = File('${tempDir.path}/config.kdl');
      settingsFile = File('${tempDir.path}/settings.json');
      await niriConfigFile.writeAsString(sampleKdl);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('getCurrentShortcut parses Super+Alt+P from sample kdl', () async {
      final service = ShortcutConfigService(
        customConfigPath: niriConfigFile.path,
        customSettingsPath: settingsFile.path,
      );

      final current = await service.getCurrentShortcut();
      expect(current, equals('Super+Alt+P'));
    });

    test(
      'getExistingBindings parses other binds and excludes account-vault',
      () async {
        final service = ShortcutConfigService(
          customConfigPath: niriConfigFile.path,
          customSettingsPath: settingsFile.path,
        );

        final bindings = await service.getExistingBindings();
        final keys = bindings.map((b) => b.key).toList();
        expect(keys, contains('Ctrl+T'));
        expect(keys, contains('Alt+A'));
        expect(keys, contains('Ctrl+Left'));
        expect(keys, isNot(contains('Super+Alt+P')));
      },
    );

    test('checkConflict detects collisions with existing bindings', () async {
      final service = ShortcutConfigService(
        customConfigPath: niriConfigFile.path,
        customSettingsPath: settingsFile.path,
      );

      // Alt+A conflicts with WeChat Screenshot
      final conflict = await service.checkConflict('Alt+A');
      expect(conflict, isNotNull);
      expect(conflict!.key, equals('Alt+A'));
      expect(conflict.title, contains('WeChat Screenshot'));

      // Current shortcut does not conflict with itself
      final selfConflict = await service.checkConflict('Super+Alt+P');
      expect(selfConflict, isNull);

      // Fresh key has no conflict
      final cleanConflict = await service.checkConflict('Super+Alt+V');
      expect(cleanConflict, isNull);
    });

    test(
      'updateShortcut validates and atomically commits new shortcut',
      () async {
        final service = ShortcutConfigService(
          customConfigPath: niriConfigFile.path,
          customSettingsPath: settingsFile.path,
          processRunner: (exe, args) async {
            expect(exe, equals('niri'));
            expect(args.first, equals('validate'));
            expect(args[1], equals('-c'));
            // Mock successful validation
            return ProcessResult(1234, 0, 'valid', '');
          },
        );

        await service.updateShortcut('Super+Alt+V');

        // Check current shortcut updated in file
        final updatedShortcut = await service.getCurrentShortcut();
        expect(updatedShortcut, equals('Super+Alt+V'));

        // Check backup file exists
        final backupFile = File('${niriConfigFile.path}.bak');
        expect(backupFile.existsSync(), isTrue);

        // Check candidate file was renamed / cleaned up
        final candidateFile = File('${niriConfigFile.path}.candidate');
        expect(candidateFile.existsSync(), isFalse);
      },
    );

    test('updateShortcut aborts and throws on validation failure', () async {
      final service = ShortcutConfigService(
        customConfigPath: niriConfigFile.path,
        customSettingsPath: settingsFile.path,
        processRunner: (exe, args) async {
          // Mock failed validation
          return ProcessResult(1234, 1, '', 'Syntax error in keybind');
        },
      );

      expect(
        () => service.updateShortcut('Super+Alt+InvalidKey!'),
        throwsA(isA<ShortcutConfigException>()),
      );

      // Main config should remain untouched with Super+Alt+P
      final current = await service.getCurrentShortcut();
      expect(current, equals('Super+Alt+P'));

      // Candidate file should be cleaned up
      final candidateFile = File('${niriConfigFile.path}.candidate');
      expect(candidateFile.existsSync(), isFalse);
    });
  });

  group('SettingsDialog Widget Tests', () {
    testWidgets('SettingsDialog renders and interacts with presets', (
      tester,
    ) async {
      final mockService = ShortcutConfigService(
        customConfigPath: '/tmp/nonexistent_niri_config.kdl',
        customSettingsPath: '/tmp/nonexistent_settings.json',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    SettingsDialog.show(context, shortcutService: mockService),
                child: const Text('Open Settings'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.text('系统与偏好设置'), findsOneWidget);
      expect(find.text('推荐常用组合：'), findsOneWidget);
      expect(find.text('Super+Alt+V'), findsOneWidget);
      expect(find.text('保存并立即生效'), findsOneWidget);

      // Tap on preset Super+Alt+V
      await tester.tap(find.text('Super+Alt+V'));
      await tester.pumpAndSettle();

      final input = tester.widget<TextField>(find.byType(TextField));
      expect(input.controller?.text, equals('Super+Alt+V'));

      // Close dialog
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('系统与偏好设置'), findsNothing);
    });
  });
}
