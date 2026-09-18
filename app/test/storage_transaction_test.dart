import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:account_vault/domain/models/vault_entry.dart';
import 'package:account_vault/infrastructure/crypto/vault_crypto_types.dart';
import 'package:account_vault/infrastructure/storage/encrypted_file_vault_repository.dart';
import 'package:account_vault/infrastructure/storage/vault_path_provider.dart';

void main() {
  group('EncryptedFileVaultRepository Storage & Transaction Tests', () {
    late Directory tempDir;
    late VaultPathProvider pathProvider;
    late EncryptedFileVaultRepository repo;

    const testPassword = 'Master_Password_Test_#2026';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vault_test_');
      pathProvider = VaultPathProvider(customDirectory: tempDir);
      repo = EncryptedFileVaultRepository(pathProvider: pathProvider);
    });

    tearDown(() async {
      repo.lock();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Full lifecycle: create, unlock, add, edit, delete, reload', () async {
      expect(await repo.vaultExists(), isFalse);

      // 1. Create vault with initial entry
      final initialEntry = VaultEntry(
        id: 'entry-1',
        title: '路由器管理',
        username: 'admin',
        password: 'Password123!',
      );

      await repo.createVault(
        masterPassword: testPassword,
        initialEntries: [initialEntry],
      );

      expect(await repo.vaultExists(), isTrue);
      expect(await pathProvider.mainVaultFile.exists(), isTrue);
      expect(repo.revision, equals(1));

      // 2. Lock and re-unlock
      repo.lock();
      expect(repo.isUnlocked, isFalse);

      final unlockedEntries = await repo.unlock(masterPassword: testPassword);
      expect(unlockedEntries.length, equals(1));
      expect(unlockedEntries.first.title, equals('路由器管理'));
      expect(unlockedEntries.first.password, equals('Password123!'));
      expect(repo.revision, equals(1));

      // 3. Save new entry
      final newEntry = VaultEntry(
        id: 'entry-2',
        title: '交换机管理',
        username: 'netadmin',
        password: 'SwitchPassword_456#',
      );
      await repo.save(newEntry);
      expect(repo.revision, equals(2));

      // 4. Edit first entry
      final editedEntry = initialEntry.copyWith(title: '核心路由器 / 主节点');
      await repo.save(editedEntry);
      expect(repo.revision, equals(3));

      // 5. Delete entry
      await repo.delete('entry-2');
      expect(repo.revision, equals(4));

      // 6. Lock and unlock again to verify on-disk state
      repo.lock();
      final finalEntries = await repo.unlock(masterPassword: testPassword);
      expect(finalEntries.length, equals(1));
      expect(finalEntries.first.title, equals('核心路由器 / 主节点'));
      expect(repo.revision, equals(4));
    });

    test(
      'Rotation of vault.previous.avlt maintains previous valid snapshot',
      () async {
        await repo.createVault(
          masterPassword: testPassword,
          initialEntries: [
            VaultEntry(id: '1', title: 'Version 1 Entry', password: 'p1'),
          ],
        );

        expect(await pathProvider.previousVaultFile.exists(), isFalse);

        // Save v2 -> previous becomes v1
        await repo.save(
          VaultEntry(id: '2', title: 'Version 2 Entry', password: 'p2'),
        );
        expect(await pathProvider.previousVaultFile.exists(), isTrue);

        // Save v3 -> previous becomes v2
        await repo.save(
          VaultEntry(id: '3', title: 'Version 3 Entry', password: 'p3'),
        );

        // Test restore from previous: should recover v2 state (contains entries 1 and 2, but not 3)
        await repo.restoreFromPrevious(testPassword);
        final restored = await repo.getAll();
        expect(
          restored.map((e) => e.title),
          containsAll(['Version 1 Entry', 'Version 2 Entry']),
        );
        expect(restored.any((e) => e.id == '3'), isFalse);
      },
    );

    test('Fault Injection: Exception before write temp file keeps main file intact', () async {
      await repo.createVault(
        masterPassword: testPassword,
        initialEntries: [
          VaultEntry(id: '1', title: 'Original Entry', password: 'p1'),
        ],
      );

      // Inject fault before write temp
      repo.onBeforeWriteTemp = () {
        throw Exception('Simulated crash before write temp');
      };

      await expectLater(
        repo.save(VaultEntry(id: '2', title: 'New Entry', password: 'p2')),
        throwsA(isA<Exception>()),
      );

      // Clear fault hook, re-unlock, and verify original data is intact
      repo.onBeforeWriteTemp = null;
      repo.lock();

      final entries = await repo.unlock(masterPassword: testPassword);
      expect(entries.length, equals(1));
      expect(entries.first.title, equals('Original Entry'));
    });

    test(
      'Fault Injection: Exception before rename keeps main file intact',
      () async {
        await repo.createVault(
          masterPassword: testPassword,
          initialEntries: [
            VaultEntry(id: '1', title: 'Original Entry', password: 'p1'),
          ],
        );

        // Inject fault right before atomic rename
        repo.onBeforeRenameMain = () {
          throw Exception('Simulated power loss before rename main');
        };

        await expectLater(
          repo.save(VaultEntry(id: '2', title: 'New Entry', password: 'p2')),
          throwsA(isA<Exception>()),
        );

        repo.onBeforeRenameMain = null;
        repo.lock();

        // Verify main file was NOT modified or deleted
        final entries = await repo.unlock(masterPassword: testPassword);
        expect(entries.length, equals(1));
        expect(entries.first.title, equals('Original Entry'));
      },
    );

    test('Concurrent saves are strictly serialized in queue without race conditions', () async {
      await repo.createVault(masterPassword: testPassword);

      // Fire 10 concurrent saves simultaneously
      final futures = <Future<void>>[];
      for (var i = 0; i < 10; i++) {
        futures.add(
          repo.save(
            VaultEntry(id: 'concurrent-$i', title: 'Item $i', password: 'p$i'),
          ),
        );
      }

      await Future.wait(futures);

      expect(repo.revision, equals(11)); // 1 (create) + 10 (saves)
      final all = await repo.getAll();
      expect(all.length, equals(10));
    });

    test(
      'Corrupted main file fails unlock without generating empty vault',
      () async {
        await repo.createVault(masterPassword: testPassword);

        // Corrupt the main vault file
        await pathProvider.mainVaultFile.writeAsString('{"corrupted": true}');

        repo.lock();
        await expectLater(
          repo.unlock(masterPassword: testPassword),
          throwsA(isA<CorruptedFormatException>()),
        );

        // Ensure the corrupted file is still there and wasn't wiped into an empty vault
        expect(await pathProvider.mainVaultFile.exists(), isTrue);
        final content = await pathProvider.mainVaultFile.readAsString();
        expect(content, equals('{"corrupted": true}'));
      },
    );
  });
}
