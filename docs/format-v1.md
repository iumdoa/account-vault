# Account Vault 格式规范 (Format Version 1)

本文档是 Account Vault 账号库持久化加密文件（`.avlt`）的字节级封装规范。第一版格式（Format Version 1）在此冻结。

---

## 1. 总体设计原则

1. **全库加密 (Envelope Encryption)**：除公开的算法头部元数据外，所有凭据（包含标题、地址、账号、密码、分组、标签、备注及时间戳）全部进入密文，不暴露任何记录明文或部分索引。
2. **强身份认证与防篡改 (AEAD)**：采用 AES-256-GCM，原始头部元数据作为附加认证数据（AAD）。篡改头部参数、密文、随机数或认证标签任一部分均会导致 GCM 认证失败。
3. **抗重放与 Nonce 唯一性**：每次加密保存必须使用密码学安全随机源生成全新 12 字节 Nonce，绝不复用 Nonce，绝不使用时间戳或自增值。
4. **AAD 逐字节一致性保证**：解密时直接使用外层 Base64 解码得到的原始 `header` 字节作为 AAD，严禁在解密端先反序列化为对象再重新 `jsonEncode`，杜绝不同平台/语言 JSON 字段顺序或空格差异引发的认证失败。
5. **防御性检查顺序**：
   - 文件物理大小检查（初版上限 32 MiB）
   - 外层 JSON 结构与字段类型严格校验
   - Header 字节大小检查（上限 4 KiB）
   - 算法识别与参数白名单检查
   - KDF 派生密钥
   - AES-256-GCM 认证解密
   - 内部 Schema 与记录数据完整性校验

---

## 2. 外层封装文件结构 (`.avlt`)

文件为标准 UTF-8 编码的 JSON 文本，包含且仅包含以下四个顶级字段：

```json
{
  "header": "<Base64 编码的原始头部字节>",
  "nonce": "<Base64 编码的 12 字节随机数>",
  "ciphertext": "<Base64 编码的 AES-256-GCM 密文>",
  "tag": "<Base64 编码的 16 字节 GCM 认证标签>"
}
```

### 字段约束

| 字段 | 类型 | 约束 | 说明 |
| --- | --- | --- | --- |
| `header` | String | 标准 Base64；解码后长度不得超过 4096 字节 | 头部元数据的原始 UTF-8 字节，直接作为 AES-GCM 的 AAD |
| `nonce` | String | 标准 Base64；解码后长度必须严格等于 12 字节 | 每次加密重新生成，密码学安全随机 |
| `ciphertext` | String | 标准 Base64；解码后长度不得超过 32 MiB | 内部有效载荷加密后的密文 |
| `tag` | String | 标准 Base64；解码后长度必须严格等于 16 字节 | AES-256-GCM 的认证标签 (MAC) |

---

## 3. 头部原始元数据 (`header`)

解码外层 `header` Base64 所得的原始字节，反序列化为 UTF-8 JSON 结构：

```json
{
  "magic": "ACCOUNT_VAULT",
  "formatVersion": 1,
  "cipher": "AES-256-GCM",
  "kdf": {
    "name": "Argon2id",
    "version": 19,
    "params": {
      "memoryKiB": 65536,
      "iterations": 3,
      "parallelism": 1,
      "hashLength": 32
    },
    "salt": "<Base64 编码的 16 字节安全随机盐>"
  }
}
```

### 参数白名单与校验规则

| 字段 | 期望值 / 约束 | 校验失败错误行为 |
| --- | --- | --- |
| `magic` | 严格等于 `"ACCOUNT_VAULT"` | 报“非合法的账号库文件格式” |
| `formatVersion` | 整数 `1` | 若大于 1，报“需要更新程序以支持更高格式版本” |
| `cipher` | 严格等于 `"AES-256-GCM"` | 报“当前版本不支持该加密算法” |
| `kdf.name` | 严格等于 `"Argon2id"` | 报“当前版本不支持该密钥派生算法” |
| `kdf.version` | 整数 `19` (0x13) | 报“不支持的 Argon2 版本” |
| `kdf.params.memoryKiB` | 整数 `65536` (64 MiB) | 报“当前版本不支持该加密参数” |
| `kdf.params.iterations` | 整数 `3` | 报“当前版本不支持该加密参数” |
| `kdf.params.parallelism`| 整数 `1` | 报“当前版本不支持该加密参数” |
| `kdf.params.hashLength` | 整数 `32` | 报“当前版本不支持该加密参数” |
| `kdf.salt` | 标准 Base64；解码后必须等于 16 字节 | 报“盐长度或编码错误” |

---

## 4. 解密后明文负载 (`payload`)

AES-256-GCM 成功解密后，明文字节反序列化为 UTF-8 JSON 结构：

```json
{
  "schemaVersion": 1,
  "vaultId": "4a123456-7890-4abc-def0-1234567890ab",
  "revision": 1,
  "entries": [
    {
      "id": "e0123456-7890-4abc-def0-1234567890ab",
      "title": "核心交换机 / 管理员",
      "address": "192.168.1.1",
      "username": "admin",
      "password": "Switch_Password_#2026",
      "group": "网络设备",
      "tags": ["cisco", "switch"],
      "notes": "机房A核心设备",
      "createdAt": "2026-09-18T10:00:00.000Z",
      "updatedAt": "2026-09-18T10:00:00.000Z"
    }
  ]
}
```

### 负载字段规范

- `schemaVersion`：必须为正整数 `1`。
- `vaultId`：账号库全局唯一 UUID。
- `revision`：非负单调递增整数（每次有效保存自增 1）。
- `entries`：记录列表，最多允许 10000 条记录。
  - `id`：记录 UUID。
  - `title`：非空字符串，上限 256 字符。
  - `address`：可空字符串，上限 4096 字符，原文存储。
  - `username`：可空字符串，上限 4096 字符，原文存储。
  - `password`：可空字符串，上限 4096 字符，原文存储。
  - `username` 与 `password` 不得同时为空。
  - `group`：可空字符串，上限 64 字符。
  - `tags`：字符串列表，去重后最多 32 个，每个上限 64 字符。
  - `notes`：可空字符串，上限 65536 字符，原文存储。
  - `createdAt`：UTC ISO 8601 格式时间字符串。
  - `updatedAt`：UTC ISO 8601 格式时间字符串。

---

## 5. 错误码与错误映射规范

| 场景 | 异常类型 / 错误提示 |
| --- | --- |
| 文件超过 32 MiB | `FileTooLargeException`：“文件大小超出当前版本限制 (32 MiB)” |
| 外层 JSON 缺失必要字段或格式损坏 | `CorruptedFormatException`：“文件封装损坏或无法解析” |
| Header 字节超过 4 KiB | `CorruptedFormatException`：“头部元数据超限” |
| 未知 formatVersion | `UnsupportedVersionException`：“文件版本高于当前程序，请升级程序” |
| 外部 KDF 参数异常或非白名单 | `UnsupportedCryptoParamException`：“当前版本不支持该加密参数” |
| 主密码错误或数据被篡改导致 GCM 验签失败 | `AuthenticationFailedException`：“主密码错误或文件已损坏” |
| 解密后 Schema 版本不匹配 | `UnsupportedVersionException`：“内部数据版本高于当前程序，请升级程序” |
