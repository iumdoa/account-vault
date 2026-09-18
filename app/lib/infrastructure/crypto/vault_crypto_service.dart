import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'vault_crypto_types.dart';

/// Cryptographic service providing Argon2id key derivation and AES-256-GCM
/// authenticated encryption/decryption in background Isolates.
class VaultCryptoService {
  static final Random _secureRandom = Random.secure();

  /// Generates a cryptographically random 16-byte salt
  static Uint8List generateSalt() {
    final salt = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      salt[i] = _secureRandom.nextInt(256);
    }
    return salt;
  }

  /// Derives 32-byte AES key from master password and salt using Argon2id
  /// in a dedicated background Isolate (README Section 6.2).
  static Future<Uint8List> deriveKey({
    required String password,
    required Uint8List salt,
  }) async {
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    final saltCopy = Uint8List.fromList(salt);

    return Isolate.run(() async {
      final kdf = Argon2id(
        memory: VaultHeader.defaultMemoryKiB,
        iterations: VaultHeader.defaultIterations,
        parallelism: VaultHeader.defaultParallelism,
        hashLength: VaultHeader.defaultHashLength,
      );

      final secretKey = await kdf.deriveKey(
        secretKey: SecretKey(passwordBytes),
        nonce: saltCopy,
      );

      final bytes = await secretKey.extractBytes();
      return Uint8List.fromList(bytes);
    });
  }

  /// Encrypts vault payload with AES-256-GCM in a dedicated background Isolate.
  /// Generates a fresh 12-byte secure random nonce for every save operation.
  static Future<EncryptedVaultPackage> encrypt({
    required DecryptedVaultPayload payload,
    required Uint8List keyBytes,
    required Uint8List salt,
  }) async {
    final payloadBytes = payload.serialize();
    final headerBytes = VaultHeader.createRawHeaderBytes(salt: salt);
    final keyBytesCopy = Uint8List.fromList(keyBytes);

    return Isolate.run(() async {
      final cipher = AesGcm.with256bits();
      final nonce = cipher
          .newNonce(); // 12-byte cryptographically secure random

      final secretBox = await cipher.encrypt(
        payloadBytes,
        secretKey: SecretKey(keyBytesCopy),
        nonce: nonce,
        aad: headerBytes,
      );

      return EncryptedVaultPackage(
        rawHeaderBytes: headerBytes,
        nonce: Uint8List.fromList(secretBox.nonce),
        ciphertext: Uint8List.fromList(secretBox.cipherText),
        tag: Uint8List.fromList(secretBox.mac.bytes),
      );
    });
  }

  /// Decrypts vault package with AES-256-GCM in a dedicated background Isolate.
  /// Uses raw header bytes directly from the package as AAD (no re-encoding).
  static Future<DecryptedVaultPayload> decrypt({
    required EncryptedVaultPackage package,
    required Uint8List keyBytes,
  }) async {
    final keyBytesCopy = Uint8List.fromList(keyBytes);
    final rawHeaderBytes = package.rawHeaderBytes;
    final nonce = package.nonce;
    final ciphertext = package.ciphertext;
    final tag = package.tag;

    return Isolate.run(() async {
      final cipher = AesGcm.with256bits();
      final secretBox = SecretBox(ciphertext, nonce: nonce, mac: Mac(tag));

      List<int> decryptedBytes;
      try {
        decryptedBytes = await cipher.decrypt(
          secretBox,
          secretKey: SecretKey(keyBytesCopy),
          aad: rawHeaderBytes,
        );
      } catch (e) {
        throw const AuthenticationFailedException('主密码错误或文件已损坏');
      }

      return DecryptedVaultPayload.deserialize(
        Uint8List.fromList(decryptedBytes),
      );
    });
  }
}
