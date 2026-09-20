import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:account_vault/application/vault_session_controller.dart';
import 'package:account_vault/domain/models/vault_entry.dart';
import 'package:account_vault/infrastructure/crypto/vault_crypto_types.dart';
import 'package:account_vault/infrastructure/mock/mock_vault_repository.dart';
import 'package:account_vault/infrastructure/storage/encrypted_file_vault_repository.dart';
import 'package:account_vault/infrastructure/storage/vault_path_provider.dart';
import 'package:account_vault/main.dart';
import 'package:account_vault/presentation/widgets/protected_groups_dialog.dart';

void main() {
  group('Protected Groups - Crypto Payload & Storage Persistence', () {
    test('DecryptedVaultPayload serializes and deserializes protectedGroups', () {
      final payload = DecryptedVaultPayload(
        schemaVersion: 1,
        vaultId: 'vault-1',
        revision: 1,
        protectedGroups: {'个人账号', '财务管理'},
        entries: [
          VaultEntry(id: '1', title: '私人邮箱', group: '个人账号'),
          VaultEntry(id: '2', title: '公网路由器', group: '网络设备'),
        ],
      );

      final bytes = payload.serialize();
      final decoded = DecryptedVaultPayload.deserialize(bytes);

      expect(decoded.protectedGroups, containsAll(['个人账号', '财务管理']));
      expect(decoded.entries.length, 2);
    });

    test('DecryptedVaultPayload backwards compatibility when protectedGroups is omitted', () {
      final payload = DecryptedVaultPayload(
        schemaVersion: 1,
        vaultId: 'vault-old',
        revision: 1,
        entries: [VaultEntry(id: '1', title: '旧记录')],
      );

      final bytes = payload.serialize();
      final decoded = DecryptedVaultPayload.deserialize(bytes);

      expect(decoded.protectedGroups, isEmpty);
      expect(decoded.entries.length, 1);
    });

    test('EncryptedFileVaultRepository persists and reloads protectedGroups', () async {
      final tempDir = await Directory.systemTemp.createTemp('protected_vault_');
      final pathProvider = VaultPathProvider(customDirectory: tempDir);
      final repo = EncryptedFileVaultRepository(pathProvider: pathProvider);

      try {
        const password = 'Test_Master_Password_#2026';
        await repo.createVault(
          masterPassword: password,
          initialEntries: [
            VaultEntry(id: '1', title: '核心路由器', group: '网络设备'),
            VaultEntry(id: '2', title: '个人支付宝', group: '个人账号'),
          ],
        );

        // Update protected groups
        await repo.setProtectedGroups({'个人账号'});
        expect(repo.protectedGroups, equals({'个人账号'}));

        // Lock session
        repo.lock();
        expect(repo.protectedGroups, isEmpty);

        // Reload fresh repository from disk
        final repo2 = EncryptedFileVaultRepository(pathProvider: pathProvider);
        final loadedEntries = await repo2.unlock(masterPassword: password);

        expect(loadedEntries.length, 2);
        expect(repo2.protectedGroups, equals({'个人账号'}));
      } finally {
        repo.lock();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });

  group('Protected Groups - Controller Isolation Logic', () {
    late MockVaultRepository repo;
    late VaultSessionController controller;

    setUp(() async {
      repo = MockVaultRepository();
      controller = VaultSessionController(
        repository: repo,
        isMockMode: true,
      );
      await controller.initialize();
      // Set '云计算' as protected group
      await controller.updateProtectedGroups({'云计算'});
    });

    test('All view filters out entries belonging to locked protected groups', () {
      controller.setGroupFilter(null); // '全部'
      final filteredTitles = controller.filteredEntries.map((e) => e.title).toList();

      // Network devices (unprotected) are present
      expect(filteredTitles, contains('核心三层交换机 / 管理员'));
      // Cloud services (protected) are filtered out
      expect(filteredTitles, isNot(contains('AWS 生产云控制台')));
      expect(filteredTitles, isNot(contains('阿里云企业控制台')));
    });

    test('Searching in All does not expose locked protected group entries', () {
      controller.setQuery('AWS');
      expect(controller.filteredEntries, isEmpty);

      controller.setQuery('交换机');
      expect(controller.filteredEntries, isNotEmpty);
      expect(controller.filteredEntries.first.title, contains('交换机'));
    });

    test('Selecting unprotected group directly displays its entries', () {
      controller.setGroupFilter('网络设备');
      expect(controller.selectedGroup, equals('网络设备'));
      expect(controller.filteredEntries, isNotEmpty);
      expect(controller.filteredEntries.every((e) => e.group == '网络设备'), isTrue);
    });

    test('Selecting locked group without auth shows 0 entries', () {
      controller.setGroupFilter('云计算');
      expect(controller.selectedGroup, equals('云计算'));
      // Locked, so candidates is empty
      expect(controller.filteredEntries, isEmpty);
    });

    test('Unlocking protected group reveals its entries, and relocks when switching away', () {
      // Direct unlock
      controller.unlockAndSelectGroupDirectly('云计算');
      expect(controller.isGroupUnlocked('云计算'), isTrue);
      expect(controller.filteredEntries, isNotEmpty);
      expect(controller.filteredEntries.any((e) => e.title == 'AWS 生产云控制台'), isTrue);

      // Switching away to '网络设备' immediately relocks '云计算'
      controller.setGroupFilter('网络设备');
      expect(controller.isGroupUnlocked('云计算'), isFalse);

      // Switching back without unlock shows empty
      controller.setGroupFilter('云计算');
      expect(controller.filteredEntries, isEmpty);
    });

    test('Management mode displays all entries including protected ones', () {
      controller.setManagementMode(true);
      controller.setGroupFilter(null);
      final titles = controller.filteredEntries.map((e) => e.title).toList();

      expect(titles, contains('核心三层交换机 / 管理员'));
      expect(titles, contains('AWS 生产云控制台'));

      // Exiting management mode re-locks
      controller.setManagementMode(false);
      final titlesAfter = controller.filteredEntries.map((e) => e.title).toList();
      expect(titlesAfter, isNot(contains('AWS 生产云控制台')));
    });
  });

  group('Protected Groups - UI Widget Interaction Tests', () {
    testWidgets('QuickPanelView group chip lock indicators and authentication flow', (
      WidgetTester tester,
    ) async {
      final repo = MockVaultRepository();
      final controller = VaultSessionController(
        repository: repo,
        isMockMode: true,
      );
      await controller.initialize();
      await controller.updateProtectedGroups({'云计算'});

      await tester.pumpWidget(AccountVaultApp(controller: controller));
      await tester.pumpAndSettle();

      // 1. Initial state: '云计算' chip has lock icon, AWS console hidden
      expect(find.text('AWS 生产云控制台'), findsNothing);
      expect(find.text('核心三层交换机 / 管理员'), findsOneWidget);

      // 2. Tap on unprotected '网络设备' chip -> switches directly without auth dialog
      await tester.tap(find.text('网络设备').first);
      await tester.pumpAndSettle();
      expect(controller.selectedGroup, equals('网络设备'));
      expect(find.text('管理权限验证'), findsNothing);

      // 3. Tap on locked '云计算' chip -> triggers ManagementAuthDialog
      await tester.tap(find.text('云计算').first);
      await tester.pumpAndSettle();

      expect(find.text('解锁「云计算」'), findsOneWidget);
      expect(find.text('该分组已被安全锁定，需验证主密码后访问'), findsOneWidget);

      // Enter password and submit
      await tester.enterText(find.byType(TextField).last, 'mock_master_key');
      await tester.tap(find.text('验 证'));
      await tester.pumpAndSettle();

      // Now unlocked!
      expect(find.text('AWS 生产云控制台'), findsOneWidget);

      // 4. Switch away to '全部' -> '云计算' immediately relocks!
      await tester.tap(find.text('全部'));
      await tester.pumpAndSettle();

      expect(find.text('AWS 生产云控制台'), findsNothing);
      expect(controller.isGroupUnlocked('云计算'), isFalse);
    });

    testWidgets('ProtectedGroupsDialog allows adding and toggling protected groups', (
      WidgetTester tester,
    ) async {
      final repo = MockVaultRepository();
      final controller = VaultSessionController(
        repository: repo,
        isMockMode: true,
      );
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ProtectedGroupsDialog.show(context, controller: controller),
                child: const Text('Open Settings'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.text('分组安全保护设置'), findsOneWidget);
      expect(find.text('网络设备'), findsOneWidget);

      // Toggle '网络设备' protection switch
      final switches = find.byType(Switch);
      expect(switches, findsWidgets);
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      // Add a brand new protected group
      await tester.enterText(find.byType(TextField), '绝密机房');
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      expect(find.text('绝密机房'), findsOneWidget);

      // Save settings
      await tester.tap(find.text('保存设置'));
      await tester.pumpAndSettle();

      expect(controller.isGroupProtected('绝密机房'), isTrue);
    });
  });
}
