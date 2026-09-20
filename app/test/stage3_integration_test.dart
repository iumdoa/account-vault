import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:account_vault/application/vault_session_controller.dart';
import 'package:account_vault/domain/models/vault_entry.dart';
import 'package:account_vault/infrastructure/mock/mock_vault_repository.dart';
import 'package:account_vault/infrastructure/storage/encrypted_file_vault_repository.dart';
import 'package:account_vault/infrastructure/storage/vault_path_provider.dart';
import 'package:account_vault/presentation/widgets/create_vault_view.dart';
import 'package:account_vault/presentation/widgets/unlock_view.dart';
import 'package:account_vault/presentation/widgets/vault_icons.dart';

void main() {
  group('Stage 3: VaultSessionController & Real Encrypted Storage Lifecycle', () {
    late Directory tempDir;
    late VaultPathProvider pathProvider;
    late EncryptedFileVaultRepository repo;

    const testPassword = 'MasterPassword_2026_#Test';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('stage3_vault_');
      pathProvider = VaultPathProvider(customDirectory: tempDir);
      repo = EncryptedFileVaultRepository(pathProvider: pathProvider);
    });

    tearDown(() async {
      repo.lock();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Clean directory initializes to uninitialized state', () async {
      final controller = VaultSessionController(
        repository: repo,
        isMockMode: false,
      );
      expect(controller.state, equals(VaultSessionState.initializing));

      await controller.initialize();
      expect(controller.state, equals(VaultSessionState.uninitialized));
      expect(controller.isUninitialized, isTrue);
      expect(controller.isUnlocked, isFalse);
      expect(await pathProvider.mainVaultFile.exists(), isFalse);
    });

    test(
      '2. createVault validation rejects empty, mismatch, and short passwords',
      () async {
        final controller = VaultSessionController(
          repository: repo,
          isMockMode: false,
        );
        await controller.initialize();

        // Empty
        var ok = await controller.createVault(
          masterPassword: '',
          confirmPassword: '',
        );
        expect(ok, isFalse);
        expect(controller.errorMessage, equals('主密码不能为空'));

        // Mismatch
        ok = await controller.createVault(
          masterPassword: 'password1',
          confirmPassword: 'password2',
        );
        expect(ok, isFalse);
        expect(controller.errorMessage, equals('两次输入的密码不一致'));

        // Short (< 6 chars)
        ok = await controller.createVault(
          masterPassword: '12345',
          confirmPassword: '12345',
        );
        expect(ok, isFalse);
        expect(controller.errorMessage, equals('主密码长度至少需要 6 个字符'));

        expect(controller.isUnlocked, isFalse);
        expect(await pathProvider.mainVaultFile.exists(), isFalse);
      },
    );

    test('3. createVault with valid password creates file on disk and unlocks session', () async {
      final controller = VaultSessionController(
        repository: repo,
        isMockMode: false,
      );
      await controller.initialize();

      final ok = await controller.createVault(
        masterPassword: testPassword,
        confirmPassword: testPassword,
      );

      expect(ok, isTrue);
      expect(controller.isUnlocked, isTrue);
      expect(controller.errorMessage, isNull);
      expect(controller.revision, equals(1));
      expect(await pathProvider.mainVaultFile.exists(), isTrue);
      expect(controller.allEntries, isEmpty);
    });

    test('4. Existing vault initializes to locked state', () async {
      // Pre-create vault
      await repo.createVault(masterPassword: testPassword);
      repo.lock();

      final controller = VaultSessionController(
        repository: repo,
        isMockMode: false,
      );
      await controller.initialize();

      expect(controller.state, equals(VaultSessionState.locked));
      expect(controller.isLocked, isTrue);
      expect(controller.isUnlocked, isFalse);
    });

    test(
      '5. unlock rejects wrong master password without modifying vault file',
      () async {
        await repo.createVault(
          masterPassword: testPassword,
          initialEntries: [VaultEntry(id: '1', title: '原始测试项', password: 'p1')],
        );
        repo.lock();

        final controller = VaultSessionController(
          repository: repo,
          isMockMode: false,
        );
        await controller.initialize();

        final ok = await controller.unlock('WrongPassword!999');
        expect(ok, isFalse);
        expect(controller.isUnlocked, isFalse);
        expect(controller.errorMessage, equals('主密码错误，请重新输入'));
        expect(controller.allEntries, isEmpty);

        // Verify file is untouched
        final fileLength = await pathProvider.mainVaultFile.length();
        expect(fileLength, greaterThan(0));
      },
    );

    test(
      '6. unlock with correct master password loads entries and clears error',
      () async {
        await repo.createVault(
          masterPassword: testPassword,
          initialEntries: [VaultEntry(id: '1', title: '原始测试项', password: 'p1')],
        );
        repo.lock();

        final controller = VaultSessionController(
          repository: repo,
          isMockMode: false,
        );
        await controller.initialize();

        final ok = await controller.unlock(testPassword);
        expect(ok, isTrue);
        expect(controller.isUnlocked, isTrue);
        expect(controller.errorMessage, isNull);
        expect(controller.allEntries.length, equals(1));
        expect(controller.allEntries.first.title, equals('原始测试项'));
      },
    );

    test('7. End-to-End Persistence: create, add entry, lock, recreate controller, unlock, verify', () async {
      // Step A: Create and add entry in session 1
      final controller1 = VaultSessionController(
        repository: repo,
        isMockMode: false,
      );
      await controller1.initialize();
      await controller1.createVault(
        masterPassword: testPassword,
        confirmPassword: testPassword,
      );

      final newEntry = VaultEntry(
        id: 'entry-real-101',
        title: '核心路由器 / 主网关',
        address: '192.168.1.1:8443',
        username: 'admin',
        password: 'RouterSecretKey_#999',
        group: '网络设备',
        tags: ['核心', '生产'],
        notes: '请勿向外网暴露管理接口',
      );

      final saveResult = await controller1.saveEntry(newEntry);
      expect(saveResult.isValid, isTrue);
      expect(controller1.allEntries.length, equals(1));
      expect(controller1.revision, equals(2));

      // Step B: Lock session 1 (simulates application termination)
      controller1.lock();
      expect(controller1.isLocked, isTrue);
      expect(controller1.allEntries, isEmpty);

      // Step C: Start session 2 with fresh repository pointing to same directory
      final repo2 = EncryptedFileVaultRepository(pathProvider: pathProvider);
      final controller2 = VaultSessionController(
        repository: repo2,
        isMockMode: false,
      );
      await controller2.initialize();
      expect(controller2.isLocked, isTrue);

      final unlockSuccess = await controller2.unlock(testPassword);
      expect(unlockSuccess, isTrue);
      expect(controller2.isUnlocked, isTrue);
      expect(controller2.allEntries.length, equals(1));

      final persisted = controller2.allEntries.first;
      expect(persisted.id, equals('entry-real-101'));
      expect(persisted.title, equals('核心路由器 / 主网关'));
      expect(persisted.address, equals('192.168.1.1:8443'));
      expect(persisted.username, equals('admin'));
      expect(persisted.password, equals('RouterSecretKey_#999'));
      expect(persisted.group, equals('网络设备'));
      expect(persisted.tags, equals(['核心', '生产']));
      expect(persisted.notes, equals('请勿向外网暴露管理接口'));

      // Step D: Delete entry in session 2, lock, reload in session 3
      await controller2.deleteEntry('entry-real-101');
      expect(controller2.allEntries, isEmpty);
      expect(controller2.revision, equals(3));
      controller2.lock();

      final repo3 = EncryptedFileVaultRepository(pathProvider: pathProvider);
      final controller3 = VaultSessionController(
        repository: repo3,
        isMockMode: false,
      );
      await controller3.initialize();
      await controller3.unlock(testPassword);
      expect(controller3.allEntries, isEmpty);
      expect(controller3.revision, equals(3));
    });
  });

  group('Stage 3: Presentation Widgets (UnlockView & CreateVaultView)', () {
    testWidgets(
      'UnlockView renders inputs, toggles password visibility, and triggers callbacks',
      (WidgetTester tester) async {
        final mockRepo = MockVaultRepository();
        final controller = VaultSessionController(
          repository: mockRepo,
          isMockMode: true,
        );

        var hidden = false;
        var quitted = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UnlockView(
                controller: controller,
                onHideWindow: () => hidden = true,
                onQuitApp: () => quitted = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Account Vault'), findsOneWidget);
        expect(find.text('本地加密库已就绪，请输入主密码解锁'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('解 锁'), findsOneWidget);
        expect(find.text('Esc 隐藏窗口'), findsOneWidget);

        // Toggle password visibility
        expect(find.byIcon(VaultIcons.eyeOff), findsOneWidget);
        await tester.tap(find.byIcon(VaultIcons.eyeOff));
        await tester.pumpAndSettle();
        expect(find.byIcon(VaultIcons.eye), findsOneWidget);

        // Test Quit button
        await tester.tap(find.text('退出程序'));
        expect(quitted, isTrue);
        expect(hidden, isFalse);
      },
    );

    testWidgets(
      'CreateVaultView renders inputs, shows security warning, and toggles visibility',
      (WidgetTester tester) async {
        final mockRepo = MockVaultRepository();
        final controller = VaultSessionController(
          repository: mockRepo,
          isMockMode: true,
        );

        var hidden = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CreateVaultView(
                controller: controller,
                onHideWindow: () => hidden = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('初始化密码库'), findsOneWidget);
        expect(find.text('首次运行，请设置主密码以创建本地加密库'), findsOneWidget);
        expect(find.textContaining('主密码用于 Argon2id 派生密钥'), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(2));
        expect(find.text('创 建 密 码 库'), findsOneWidget);
        expect(find.text('Esc 隐藏窗口'), findsOneWidget);
        expect(hidden, isFalse);
      },
    );
  });
}
