import 'dart:convert';
import 'dart:typed_data';

import '../../domain/models/vault_entry.dart';

/// Base exception for vault cryptography and format errors
abstract class VaultCryptoException implements Exception {
  final String message;
  const VaultCryptoException(this.message);

  @override
  String toString() => message;
}

/// Thrown when AES-GCM MAC validation fails (wrong password or corrupted ciphertext/AAD)
class AuthenticationFailedException extends VaultCryptoException {
  const AuthenticationFailedException([super.message = '主密码错误或文件已损坏']);
}

/// Thrown when file encapsulation structure or Base64 encoding is corrupted
class CorruptedFormatException extends VaultCryptoException {
  const CorruptedFormatException([super.message = '文件封装损坏或无法解析']);
}

/// Thrown when file version is higher than supported
class UnsupportedVersionException extends VaultCryptoException {
  const UnsupportedVersionException([super.message = '文件版本高于当前程序，请升级程序']);
}

/// Thrown when KDF algorithm or parameters are outside the supported whitelist
class UnsupportedCryptoParamException extends VaultCryptoException {
  const UnsupportedCryptoParamException([super.message = '当前版本不支持该加密参数']);
}

/// Thrown when file size exceeds limits (32 MiB)
class FileTooLargeException extends VaultCryptoException {
  const FileTooLargeException([super.message = '文件大小超出当前版本限制 (32 MiB)']);
}

/// Encapsulates the parsed and verified header metadata
class VaultHeader {
  static const String expectedMagic = 'ACCOUNT_VAULT';
  static const int currentFormatVersion = 1;
  static const String expectedCipher = 'AES-256-GCM';
  static const String expectedKdfName = 'Argon2id';
  static const int expectedKdfVersion = 19; // 0x13
  static const int defaultMemoryKiB = 65536; // 64 MiB
  static const int defaultIterations = 3;
  static const int defaultParallelism = 1;
  static const int defaultHashLength = 32;

  final String magic;
  final int formatVersion;
  final String cipher;
  final String kdfName;
  final int kdfVersion;
  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final int hashLength;
  final Uint8List salt;
  final Uint8List rawHeaderBytes;

  const VaultHeader({
    required this.magic,
    required this.formatVersion,
    required this.cipher,
    required this.kdfName,
    required this.kdfVersion,
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
    required this.hashLength,
    required this.salt,
    required this.rawHeaderBytes,
  });

  /// Serializes header object to canonical raw UTF-8 JSON bytes
  static Uint8List createRawHeaderBytes({
    required Uint8List salt,
    int memoryKiB = defaultMemoryKiB,
    int iterations = defaultIterations,
    int parallelism = defaultParallelism,
    int hashLength = defaultHashLength,
  }) {
    final map = {
      'magic': expectedMagic,
      'formatVersion': currentFormatVersion,
      'cipher': expectedCipher,
      'kdf': {
        'name': expectedKdfName,
        'version': expectedKdfVersion,
        'params': {
          'memoryKiB': memoryKiB,
          'iterations': iterations,
          'parallelism': parallelism,
          'hashLength': hashLength,
        },
        'salt': base64Encode(salt),
      },
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  /// Parses and validates raw header bytes against format whitelist
  static VaultHeader parseAndValidate(Uint8List rawBytes) {
    if (rawBytes.length > 4096) {
      throw const CorruptedFormatException('头部元数据超过 4 KiB 限制');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(rawBytes));
    } catch (_) {
      throw const CorruptedFormatException('头部 JSON 解析失败');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const CorruptedFormatException('头部结构格式不正确');
    }

    final magic = decoded['magic'];
    if (magic != expectedMagic) {
      throw const CorruptedFormatException('非合法的账号库文件标识');
    }

    final formatVersion = decoded['formatVersion'];
    if (formatVersion is! int || formatVersion < 1) {
      throw const CorruptedFormatException('格式版本缺失或非法');
    }
    if (formatVersion > currentFormatVersion) {
      throw const UnsupportedVersionException('需要更新程序以支持更高格式版本');
    }

    final cipher = decoded['cipher'];
    if (cipher != expectedCipher) {
      throw const UnsupportedCryptoParamException('当前版本不支持该加密算法');
    }

    final kdf = decoded['kdf'];
    if (kdf is! Map<String, dynamic>) {
      throw const CorruptedFormatException('KDF 结构缺失');
    }

    final kdfName = kdf['name'];
    if (kdfName != expectedKdfName) {
      throw const UnsupportedCryptoParamException('当前版本不支持该密钥派生算法');
    }

    final kdfVersion = kdf['version'];
    if (kdfVersion != expectedKdfVersion) {
      throw const UnsupportedCryptoParamException('不支持的 Argon2 版本');
    }

    final params = kdf['params'];
    if (params is! Map<String, dynamic>) {
      throw const CorruptedFormatException('KDF 参数缺失');
    }

    final memoryKiB = params['memoryKiB'];
    final iterations = params['iterations'];
    final parallelism = params['parallelism'];
    final hashLength = params['hashLength'];

    if (memoryKiB != defaultMemoryKiB ||
        iterations != defaultIterations ||
        parallelism != defaultParallelism ||
        hashLength != defaultHashLength) {
      throw const UnsupportedCryptoParamException('当前版本不支持该加密参数组合');
    }

    final saltStr = kdf['salt'];
    if (saltStr is! String) {
      throw const CorruptedFormatException('盐数据缺失');
    }

    Uint8List salt;
    try {
      salt = Uint8List.fromList(base64Decode(saltStr));
    } catch (_) {
      throw const CorruptedFormatException('盐 Base64 解码失败');
    }

    if (salt.length != 16) {
      throw const CorruptedFormatException('盐长度必须为 16 字节');
    }

    return VaultHeader(
      magic: magic as String,
      formatVersion: formatVersion,
      cipher: cipher as String,
      kdfName: kdfName as String,
      kdfVersion: kdfVersion as int,
      memoryKiB: memoryKiB as int,
      iterations: iterations as int,
      parallelism: parallelism as int,
      hashLength: hashLength as int,
      salt: salt,
      rawHeaderBytes: rawBytes,
    );
  }
}

/// Encapsulates the outer `.avlt` file representation
class EncryptedVaultPackage {
  static const int maxFileBytes = 32 * 1024 * 1024; // 32 MiB

  final Uint8List rawHeaderBytes;
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List tag;

  const EncryptedVaultPackage({
    required this.rawHeaderBytes,
    required this.nonce,
    required this.ciphertext,
    required this.tag,
  });

  /// Serializes into outer JSON string format
  String serialize() {
    final map = {
      'header': base64Encode(rawHeaderBytes),
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(ciphertext),
      'tag': base64Encode(tag),
    };
    return jsonEncode(map);
  }

  /// Deserializes and performs defensive structural checks
  static EncryptedVaultPackage deserialize(String jsonString) {
    if (jsonString.length > maxFileBytes) {
      throw const FileTooLargeException('文件大小超出当前版本限制 (32 MiB)');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (_) {
      throw const CorruptedFormatException('外层封装文件非合法 JSON');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const CorruptedFormatException('外层封装必须为 JSON 键值对');
    }

    final headerStr = decoded['header'];
    final nonceStr = decoded['nonce'];
    final ciphertextStr = decoded['ciphertext'];
    final tagStr = decoded['tag'];

    if (headerStr is! String ||
        nonceStr is! String ||
        ciphertextStr is! String ||
        tagStr is! String) {
      throw const CorruptedFormatException(
        '外层封装缺少必需字段 (header/nonce/ciphertext/tag)',
      );
    }

    Uint8List rawHeaderBytes;
    Uint8List nonce;
    Uint8List ciphertext;
    Uint8List tag;

    try {
      rawHeaderBytes = Uint8List.fromList(base64Decode(headerStr));
      nonce = Uint8List.fromList(base64Decode(nonceStr));
      ciphertext = Uint8List.fromList(base64Decode(ciphertextStr));
      tag = Uint8List.fromList(base64Decode(tagStr));
    } catch (_) {
      throw const CorruptedFormatException('外层字段存在非法 Base64 数据');
    }

    if (nonce.length != 12) {
      throw const CorruptedFormatException('Nonce 长度必须为 12 字节');
    }

    if (tag.length != 16) {
      throw const CorruptedFormatException('认证标签长度必须为 16 字节');
    }

    return EncryptedVaultPackage(
      rawHeaderBytes: rawHeaderBytes,
      nonce: nonce,
      ciphertext: ciphertext,
      tag: tag,
    );
  }
}

/// Decrypted plaintext payload inside the vault
class DecryptedVaultPayload {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String vaultId;
  final int revision;
  final Set<String> protectedGroups;
  final List<VaultEntry> entries;

  const DecryptedVaultPayload({
    required this.schemaVersion,
    required this.vaultId,
    required this.revision,
    this.protectedGroups = const {},
    required this.entries,
  });

  Uint8List serialize() {
    final map = {
      'schemaVersion': schemaVersion,
      'vaultId': vaultId,
      'revision': revision,
      if (protectedGroups.isNotEmpty)
        'protectedGroups': protectedGroups.toList()..sort(),
      'entries': entries.map((e) => e.toJson()).toList(),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  static DecryptedVaultPayload deserialize(Uint8List bytes) {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const CorruptedFormatException('内部解密载荷不是合法的 UTF-8 JSON');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const CorruptedFormatException('内部解密载荷格式错误');
    }

    final schemaVer = decoded['schemaVersion'];
    if (schemaVer is! int || schemaVer < 1) {
      throw const CorruptedFormatException('内部 Schema 版本缺失');
    }
    if (schemaVer > currentSchemaVersion) {
      throw const UnsupportedVersionException('内部数据版本高于当前程序，请升级程序');
    }

    final vaultId = decoded['vaultId'];
    if (vaultId is! String || vaultId.isEmpty) {
      throw const CorruptedFormatException('缺少 vaultId');
    }

    final revision = decoded['revision'];
    if (revision is! int || revision < 0) {
      throw const CorruptedFormatException('非法 revision 序号');
    }

    final rawProtected = decoded['protectedGroups'];
    final Set<String> protectedGroups = {};
    if (rawProtected is List) {
      for (final g in rawProtected) {
        if (g is String && g.trim().isNotEmpty) {
          protectedGroups.add(g.trim());
        }
      }
    }

    final rawEntries = decoded['entries'];
    if (rawEntries is! List<dynamic>) {
      throw const CorruptedFormatException('entries 必须为列表');
    }

    if (rawEntries.length > 10000) {
      throw const CorruptedFormatException('账号库记录数超过最大限制 (10000 条)');
    }

    final entries = <VaultEntry>[];
    for (final item in rawEntries) {
      if (item is! Map<String, dynamic>) {
        throw const CorruptedFormatException('存在非法的记录项格式');
      }
      entries.add(VaultEntry.fromJson(item));
    }

    return DecryptedVaultPayload(
      schemaVersion: schemaVer,
      vaultId: vaultId,
      revision: revision,
      protectedGroups: protectedGroups,
      entries: entries,
    );
  }
}
