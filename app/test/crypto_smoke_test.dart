// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';

void main() {
  test('Verify Argon2id and AES-256-GCM API and measure baseline performance', () async {
    const password = 'TestMasterPassword!2026';
    final salt = List<int>.generate(16, (i) => i + 1);

    final kdf = Argon2id(
      memory: 65536, // 64 MB
      iterations: 3,
      parallelism: 1,
      hashLength: 32,
    );

    final swKdf = Stopwatch()..start();
    final secretKey = await kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    swKdf.stop();
    final derivedKeyBytes = await secretKey.extractBytes();
    print(
      'Argon2id KDF time: ${swKdf.elapsedMilliseconds} ms, derivedKeyLength: ${derivedKeyBytes.length}',
    );

    expect(derivedKeyBytes.length, equals(32));

    // AES-256-GCM test with AAD
    final cipher = AesGcm.with256bits();
    final nonce = cipher.newNonce();
    final aad = utf8.encode('{"magic":"ACCOUNT_VAULT","version":1}');
    final plaintext = utf8.encode('{"test":"payload_content_12345"}');

    final swEnc = Stopwatch()..start();
    final secretBox = await cipher.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
      aad: aad,
    );
    swEnc.stop();
    print('AES-256-GCM encrypt time: ${swEnc.elapsedMicroseconds / 1000} ms');

    // Decrypt
    final swDec = Stopwatch()..start();
    final decryptedBytes = await cipher.decrypt(
      secretBox,
      secretKey: secretKey,
      aad: aad,
    );
    swDec.stop();
    print('AES-256-GCM decrypt time: ${swEnc.elapsedMicroseconds / 1000} ms');

    expect(
      utf8.decode(decryptedBytes),
      equals('{"test":"payload_content_12345"}'),
    );
  });
}
