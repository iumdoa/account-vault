import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:account_vault/application/vault_session_controller.dart';
import 'package:account_vault/domain/models/vault_entry.dart';
import 'package:account_vault/infrastructure/crypto/vault_crypto_types.dart';
import 'package:account_vault/infrastructure/mock/mock_vault_repository.dart';
import 'package:account_vault/infrastructure/storage/encrypted_file_vault_repository.dart';
import 'package:account_vault/infrastructure/storage/vault_path_provider.dart';
import 'package:account_vault/presentation/widgets/backup_export_dialog.dart';
import 'package:account_vault/presentation/widgets/backup_restore_dialog.dart';

void main() {
  group('Stage 4: Encrypted Backup & Whole Vault Restore Tests', () {
    late Directory tempDir;
    late Directory backupDir;
    late VaultPathProvider pathProvider;
    late EncryptedFileVaultRepository repo;

    const originalPassword = 'OriginalPassword_#2026';
    const backupPassword = 'DifferentBackupPassword_#8888';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('backup_test_data_');
      backupDir = await Directory.systemTemp.createTemp('backup_test_export_');
      pathProvider = VaultPathProvider(customDirectory: tempDir);
      repo = EncryptedFileVaultRepository(pathProvider: pathProvider);
    });

    tearDown(() async {
      repo.lock();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      if (await backupDir.exists()) await backupDir.delete(recursive: true);
    });

    test(
      'Export backup creates verified snapshot with 0600 permissions',
      () async {
        final entry1 = VaultEntry(
          id: 'entry-01',
          title: '生产数据库集群',
          address: '10.10.10.1:5432',
          username: 'postgres',
          password: 'SuperDatabasePassword_123#',
        );

        await repo.createVault(
          masterPassword: originalPassword,
          initialEntries: [entry1],
        );

        final exportFile = File('${backupDir.path}/test-export.avlt');
        expect(await exportFile.exists(), isFalse);

        await repo.exportBackup(exportFile);

        expect(await exportFile.exists(), isTrue);
        expect(await exportFile.length(), greaterThan(0));

        // Test decrypting exported file directly
        final preview = await repo.previewBackup(
          backupFile: exportFile,
          masterPassword: originalPassword,
        );
        expect(preview.entries.length, equals(1));
        expect(preview.entries.first.title, equals('生产数据库集群'));
        expect(
          preview.entries.first.password,
          equals('SuperDatabasePassword_123#'),
        );
      },
    );

    test(
      'Export rejects overwriting current main vault or previous vault',
      () async {
        await repo.createVault(masterPassword: originalPassword);

        // Overwriting main vault directly is blocked
        expect(
          repo.exportBackup(pathProvider.mainVaultFile),
          throwsA(isA<CorruptedFormatException>()),
        );

        // Overwriting previous vault directly is blocked
        expect(
          repo.exportBackup(pathProvider.previousVaultFile),
          throwsA(isA<CorruptedFormatException>()),
        );
      },
    );

    test(
      'Preview backup fails with wrong password without modifying anything',
      () async {
        await repo.createVault(
          masterPassword: originalPassword,
          initialEntries: [VaultEntry(id: '1', title: '测试记录', password: 'p1')],
        );

        final exportFile = File('${backupDir.path}/vault-backup.avlt');
        await repo.exportBackup(exportFile);

        expect(
          repo.previewBackup(
            backupFile: exportFile,
            masterPassword: 'WrongPassword_XYZ',
          ),
          throwsA(isA<AuthenticationFailedException>()),
        );
      },
    );

    test('Whole vault restore adopts backup password, generates safety backup, and preserves records', () async {
      // 1. Create source vault A with Password A
      final sourceDir = await Directory.systemTemp.createTemp('source_vault_');
      final sourceProvider = VaultPathProvider(customDirectory: sourceDir);
      final sourceRepo = EncryptedFileVaultRepository(
        pathProvider: sourceProvider,
      );

      final backupEntry = VaultEntry(
        id: 'backup-entry-99',
        title: '异地冷备凭据',
        username: 'backup_admin',
        password: r'ColdBackupPassword_$$$',
      );

      await sourceRepo.createVault(
        masterPassword: backupPassword,
        initialEntries: [backupEntry],
      );

      final backupFile = File('${backupDir.path}/external-backup.avlt');
      await sourceRepo.exportBackup(backupFile);
      sourceRepo.lock();
      await sourceDir.delete(recursive: true);

      // 2. Main vault has local entry with Password A
      final localEntry = VaultEntry(
        id: 'local-entry-1',
        title: '现有本地记录',
        password: 'LocalOldPassword_123',
      );
      await repo.createVault(
        masterPassword: originalPassword,
        initialEntries: [localEntry],
      );

      // 3. Controller executes restoreFromBackup
      final controller = VaultSessionController(
        repository: repo,
        isMockMode: false,
      );
      await controller.initialize();
      await controller.unlock(originalPassword);
      expect(controller.allEntries.length, equals(1));
      expect(controller.allEntries.first.title, equals('现有本地记录'));

      // 4. Preview backup
      final preview = await controller.previewBackup(
        backupFile: backupFile,
        masterPassword: backupPassword,
      );
      expect(preview, isNotNull);
      expect(preview!.entries.length, equals(1));
      expect(preview.entries.first.title, equals('异地冷备凭据'));

      // 5. Execute restore
      final restoreResult = await controller.restoreFromBackup(
        backupFile: backupFile,
        masterPassword: backupPassword,
      );

      expect(restoreResult.success, isTrue);
      expect(restoreResult.safetyBackupFile, isNotNull);
      expect(await restoreResult.safetyBackupFile!.exists(), isTrue);

      // Verify restored content is in memory
      expect(controller.allEntries.length, equals(1));
      expect(controller.allEntries.first.title, equals('异地冷备凭据'));
      expect(
        controller.allEntries.first.password,
        equals(r'ColdBackupPassword_$$$'),
      );

      // 6. Lock and verify we can unlock using backupPassword (README Section 9.2 semantic requirement!)
      controller.lock();
      expect(controller.isLocked, isTrue);

      // Old password must fail
      final oldUnlock = await controller.unlock(originalPassword);
      expect(oldUnlock, isFalse);

      // New backup password succeeds
      final newUnlock = await controller.unlock(backupPassword);
      expect(newUnlock, isTrue);
      expect(controller.allEntries.first.title, equals('异地冷备凭据'));

      // 7. Verify safety backup file can still be read with originalPassword!
      final safetyDecrypted = await repo.previewBackup(
        backupFile: restoreResult.safetyBackupFile!,
        masterPassword: originalPassword,
      );
      expect(safetyDecrypted.entries.first.title, equals('现有本地记录'));
    });

    test(
      'Corrupted backup file does not overwrite current active vault',
      () async {
        await repo.createVault(
          masterPassword: originalPassword,
          initialEntries: [
            VaultEntry(id: 'keep-me', title: '绝密凭据', password: 'KeepMeSafe!'),
          ],
        );

        final controller = VaultSessionController(
          repository: repo,
          isMockMode: false,
        );
        await controller.initialize();
        await controller.unlock(originalPassword);

        final corruptedBackup = File('${backupDir.path}/corrupted.avlt');
        await corruptedBackup.writeAsString(
          '{"corrupted": true, "header": "bad"}',
        );

        final result = await controller.restoreFromBackup(
          backupFile: corruptedBackup,
          masterPassword: 'any',
        );

        expect(result.success, isFalse);
        expect(controller.errorMessage, isNotNull);

        // Active vault remains intact!
        expect(controller.allEntries.length, equals(1));
        expect(controller.allEntries.first.title, equals('绝密凭据'));

        controller.lock();
        final unlockOk = await controller.unlock(originalPassword);
        expect(unlockOk, isTrue);
        expect(controller.allEntries.first.title, equals('绝密凭据'));
      },
    );
  });

  group('Stage 4: Backup UI Dialog Widget Tests', () {
    testWidgets('BackupExportDialog renders default path and triggers export', (
      WidgetTester tester,
    ) async {
      final mockRepo = MockVaultRepository();
      final controller = VaultSessionController(
        repository: mockRepo,
        isMockMode: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BackupExportDialog(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('导出加密备份'), findsOneWidget);
      expect(find.textContaining('将当前密码库全部凭据'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('浏览...'), findsOneWidget);
      expect(find.text('导出'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    });

    testWidgets('BackupRestoreDialog renders inputs and allows cancel', (
      WidgetTester tester,
    ) async {
      final mockRepo = MockVaultRepository();
      final controller = VaultSessionController(
        repository: mockRepo,
        isMockMode: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BackupRestoreDialog(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('从备份整库恢复'), findsOneWidget);
      expect(find.text('浏览...'), findsOneWidget);
      expect(find.text('检查并预览备份内容'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    });
  });
}
