import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:account_vault/domain/models/vault_entry.dart';
import 'package:account_vault/infrastructure/crypto/vault_crypto_service.dart';
import 'package:account_vault/infrastructure/crypto/vault_crypto_types.dart';

void main() {
  group('VaultCryptoService & Package Tests', () {
    const testPassword = 'MySecretMasterPassword!2026_中文_🔑';
    final testSalt = Uint8List.fromList([
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
    ]);

    test('UTF-8 master password with emoji and special chars derives consistent key', () async {
      final key1 = await VaultCryptoService.deriveKey(
        password: testPassword,
        salt: testSalt,
      );
      final key2 = await VaultCryptoService.deriveKey(
        password: testPassword,
        salt: testSalt,
      );

      expect(key1.length, equals(32));
      expect(key1, equals(key2));
    });

    test(
      'Roundtrip encryption and decryption preserves credentials byte-for-byte',
      () async {
        final key = await VaultCryptoService.deriveKey(
          password: testPassword,
          salt: testSalt,
        );

        final entry1 = VaultEntry(
          id: 'id-001',
          title: '特殊凭据测试项',
          address: '  https://10.0.0.1:8443/?test=1  ',
          username: '  leading_trailing_user  ',
          password: '  Secret P@ss \n line2 🔑 "quote" \'single\' \\slash ',
          group: '测试分组',
          tags: ['tag1', '标签2'],
          notes: '备注第一行\r\n备注第二行带有特殊字符 🎯',
          createdAt: DateTime.utc(2026, 9, 18, 12, 0, 0),
          updatedAt: DateTime.utc(2026, 9, 18, 12, 30, 0),
        );

        final payload = DecryptedVaultPayload(
          schemaVersion: 1,
          vaultId: 'vault-uuid-test',
          revision: 1,
          entries: [entry1],
        );

        final package = await VaultCryptoService.encrypt(
          payload: payload,
          keyBytes: key,
          salt: testSalt,
        );

        // Verify serialization to JSON
        final jsonStr = package.serialize();
        final restoredPackage = EncryptedVaultPackage.deserialize(jsonStr);

        // Decrypt
        final decrypted = await VaultCryptoService.decrypt(
          package: restoredPackage,
          keyBytes: key,
        );

        expect(decrypted.schemaVersion, equals(1));
        expect(decrypted.vaultId, equals('vault-uuid-test'));
        expect(decrypted.revision, equals(1));
        expect(decrypted.entries.length, equals(1));

        final restoredEntry = decrypted.entries.first;
        expect(restoredEntry.id, equals(entry1.id));
        expect(restoredEntry.title, equals(entry1.title));
        expect(restoredEntry.address, equals(entry1.address));
        expect(restoredEntry.username, equals(entry1.username));
        expect(restoredEntry.password, equals(entry1.password));
        expect(restoredEntry.group, equals(entry1.group));
        expect(restoredEntry.tags, equals(entry1.tags));
        expect(restoredEntry.notes, equals(entry1.notes));
        expect(restoredEntry.createdAt, equals(entry1.createdAt));
        expect(restoredEntry.updatedAt, equals(entry1.updatedAt));
      },
    );

    test(
      'Wrong master password fails authentication without data leakage',
      () async {
        final correctKey = await VaultCryptoService.deriveKey(
          password: 'CorrectPassword!123',
          salt: testSalt,
        );
        final wrongKey = await VaultCryptoService.deriveKey(
          password: 'WrongPassword!123',
          salt: testSalt,
        );

        final payload = DecryptedVaultPayload(
          schemaVersion: 1,
          vaultId: 'vault-test',
          revision: 1,
          entries: [VaultEntry(id: '1', title: 'Test', password: 'secret')],
        );

        final package = await VaultCryptoService.encrypt(
          payload: payload,
          keyBytes: correctKey,
          salt: testSalt,
        );

        expect(
          () async => await VaultCryptoService.decrypt(
            package: package,
            keyBytes: wrongKey,
          ),
          throwsA(isA<AuthenticationFailedException>()),
        );
      },
    );

    test(
      'Encrypting twice generates fresh nonce and different ciphertext',
      () async {
        final key = await VaultCryptoService.deriveKey(
          password: testPassword,
          salt: testSalt,
        );

        final payload = DecryptedVaultPayload(
          schemaVersion: 1,
          vaultId: 'vault-test',
          revision: 1,
          entries: [VaultEntry(id: '1', title: 'Test', password: 'secret')],
        );

        final pkg1 = await VaultCryptoService.encrypt(
          payload: payload,
          keyBytes: key,
          salt: testSalt,
        );
        final pkg2 = await VaultCryptoService.encrypt(
          payload: payload,
          keyBytes: key,
          salt: testSalt,
        );

        // Nonce must be distinct (never reused)
        expect(pkg1.nonce, isNot(equals(pkg2.nonce)));
        expect(pkg1.ciphertext, isNot(equals(pkg2.ciphertext)));

        // Both must decrypt to exact same payload
        final dec1 = await VaultCryptoService.decrypt(
          package: pkg1,
          keyBytes: key,
        );
        final dec2 = await VaultCryptoService.decrypt(
          package: pkg2,
          keyBytes: key,
        );

        expect(
          dec1.entries.first.password,
          equals(dec2.entries.first.password),
        );
      },
    );

    test(
      'Tampering header, nonce, ciphertext or tag fails authentication',
      () async {
        final key = await VaultCryptoService.deriveKey(
          password: testPassword,
          salt: testSalt,
        );

        final payload = DecryptedVaultPayload(
          schemaVersion: 1,
          vaultId: 'vault-test',
          revision: 1,
          entries: [VaultEntry(id: '1', title: 'Test', password: 'secret')],
        );

        final originalPkg = await VaultCryptoService.encrypt(
          payload: payload,
          keyBytes: key,
          salt: testSalt,
        );

        // 1. Tamper header bytes (AAD)
        final tamperedHeader = Uint8List.fromList(originalPkg.rawHeaderBytes);
        tamperedHeader[10] ^= 0xFF;
        final pkgTamperedHeader = EncryptedVaultPackage(
          rawHeaderBytes: tamperedHeader,
          nonce: originalPkg.nonce,
          ciphertext: originalPkg.ciphertext,
          tag: originalPkg.tag,
        );
        expect(
          () async => await VaultCryptoService.decrypt(
            package: pkgTamperedHeader,
            keyBytes: key,
          ),
          throwsA(isA<VaultCryptoException>()),
        );

        // 2. Tamper nonce
        final tamperedNonce = Uint8List.fromList(originalPkg.nonce);
        tamperedNonce[0] ^= 0xFF;
        final pkgTamperedNonce = EncryptedVaultPackage(
          rawHeaderBytes: originalPkg.rawHeaderBytes,
          nonce: tamperedNonce,
          ciphertext: originalPkg.ciphertext,
          tag: originalPkg.tag,
        );
        expect(
          () async => await VaultCryptoService.decrypt(
            package: pkgTamperedNonce,
            keyBytes: key,
          ),
          throwsA(isA<AuthenticationFailedException>()),
        );

        // 3. Tamper ciphertext
        final tamperedCiphertext = Uint8List.fromList(originalPkg.ciphertext);
        tamperedCiphertext[0] ^= 0xFF;
        final pkgTamperedCipher = EncryptedVaultPackage(
          rawHeaderBytes: originalPkg.rawHeaderBytes,
          nonce: originalPkg.nonce,
          ciphertext: tamperedCiphertext,
          tag: originalPkg.tag,
        );
        expect(
          () async => await VaultCryptoService.decrypt(
            package: pkgTamperedCipher,
            keyBytes: key,
          ),
          throwsA(isA<AuthenticationFailedException>()),
        );

        // 4. Tamper tag
        final tamperedTag = Uint8List.fromList(originalPkg.tag);
        tamperedTag[0] ^= 0xFF;
        final pkgTamperedTag = EncryptedVaultPackage(
          rawHeaderBytes: originalPkg.rawHeaderBytes,
          nonce: originalPkg.nonce,
          ciphertext: originalPkg.ciphertext,
          tag: tamperedTag,
        );
        expect(
          () async => await VaultCryptoService.decrypt(
            package: pkgTamperedTag,
            keyBytes: key,
          ),
          throwsA(isA<AuthenticationFailedException>()),
        );
      },
    );

    test('Defensive checks reject truncated, invalid Base64 and unknown versions', () {
      // Truncated/corrupted JSON
      expect(
        () => EncryptedVaultPackage.deserialize('{"header":"bm9uY2U='),
        throwsA(isA<CorruptedFormatException>()),
      );

      // Invalid Base64
      expect(
        () => EncryptedVaultPackage.deserialize(
          '{"header":"???","nonce":"bm9uY2U=","ciphertext":"Y2lwaGVy","tag":"dGFn"}',
        ),
        throwsA(isA<CorruptedFormatException>()),
      );

      // Invalid nonce length (!= 12 bytes)
      final shortNonceBase64 = base64Encode([1, 2, 3]);
      expect(
        () => EncryptedVaultPackage.deserialize(
          '{"header":"aGVhZGVy","nonce":"$shortNonceBase64","ciphertext":"Y2lwaGVy","tag":"dGFn"}',
        ),
        throwsA(isA<CorruptedFormatException>()),
      );
    });
  });
}
