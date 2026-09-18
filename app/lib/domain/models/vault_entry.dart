/// Represents a single credential record in the vault.
///
/// Note: username and password MUST be preserved with exact characters
/// (no trimming, no unicode normalization, no case modification).
class VaultEntry {
  final String id;
  final String title;
  final String? address;
  final String? username;
  final String? password;
  final String? group;
  final List<String> tags;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  VaultEntry({
    required this.id,
    required this.title,
    this.address,
    this.username,
    this.password,
    this.group,
    List<String>? tags,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : tags = List.unmodifiable(tags ?? const <String>[]),
       createdAt = (createdAt ?? DateTime.now()).toUtc(),
       updatedAt = (updatedAt ?? DateTime.now()).toUtc();

  VaultEntry copyWith({
    String? id,
    String? title,
    String? address,
    String? username,
    String? password,
    String? group,
    List<String>? tags,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VaultEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      address: address ?? this.address,
      username: username ?? this.username,
      password: password ?? this.password,
      group: group ?? this.group,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (address != null) 'address': address,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      if (group != null) 'group': group,
      'tags': tags,
      if (notes != null) 'notes': notes,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory VaultEntry.fromJson(Map<String, dynamic> json) {
    return VaultEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      address: json['address'] as String?,
      username: json['username'] as String?,
      password: json['password'] as String?,
      group: json['group'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultEntry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'VaultEntry(id: $id, title: $title, address: $address, username: $username)';
}

/// Validation result with detailed field-level errors
class ValidationResult {
  final bool isValid;
  final Map<String, String> errors;

  const ValidationResult._({required this.isValid, required this.errors});

  factory ValidationResult.success() =>
      const ValidationResult._(isValid: true, errors: {});

  factory ValidationResult.failure(Map<String, String> errors) =>
      ValidationResult._(isValid: false, errors: errors);

  String? get firstErrorMessage => errors.values.firstOrNull;
}

/// Centralized validator and sanitizer for vault entries
class VaultEntryValidator {
  static const int maxTitleLength = 256;
  static const int maxAddressLength = 4096;
  static const int maxUsernameLength = 4096;
  static const int maxPasswordLength = 4096;
  static const int maxGroupLength = 64;
  static const int maxTagCount = 32;
  static const int maxTagLength = 64;
  static const int maxNotesLength = 65536;

  /// Sanitizes non-credential fields:
  /// - Title: trims leading and trailing whitespace
  /// - Group: trims leading and trailing whitespace
  /// - Tags: trims and deduplicates
  /// - Credentials (username, password, address, notes): strictly preserved raw
  static ({
    String title,
    String? address,
    String? username,
    String? password,
    String? group,
    List<String> tags,
    String? notes,
  })
  sanitize({
    required String title,
    String? address,
    String? username,
    String? password,
    String? group,
    List<String>? tags,
    String? notes,
  }) {
    final sanitizedTitle = title.trim();
    final sanitizedGroup = group?.trim();
    final sanitizedTags = <String>[];
    if (tags != null) {
      for (final t in tags) {
        final cleanTag = t.trim();
        if (cleanTag.isNotEmpty && !sanitizedTags.contains(cleanTag)) {
          sanitizedTags.add(cleanTag);
        }
      }
    }

    return (
      title: sanitizedTitle,
      address: address, // preserved raw
      username: username, // preserved raw
      password: password, // preserved raw
      group: sanitizedGroup?.isEmpty == true ? null : sanitizedGroup,
      tags: sanitizedTags,
      notes: notes, // preserved raw
    );
  }

  /// Validates all length limits and required constraints
  static ValidationResult validate({
    required String title,
    String? address,
    String? username,
    String? password,
    String? group,
    List<String>? tags,
    String? notes,
  }) {
    final errors = <String, String>{};

    if (title.trim().isEmpty) {
      errors['title'] = '标题不能为空';
    } else if (title.length > maxTitleLength) {
      errors['title'] = '标题长度不能超过 $maxTitleLength 字符';
    }

    final hasUsername = username != null && username.isNotEmpty;
    final hasPassword = password != null && password.isNotEmpty;
    if (!hasUsername && !hasPassword) {
      errors['credentials'] = '账号与密码不得同时为空';
    }

    if (address != null && address.length > maxAddressLength) {
      errors['address'] = '地址长度不能超过 $maxAddressLength 字符';
    }

    if (username != null && username.length > maxUsernameLength) {
      errors['username'] = '账号长度不能超过 $maxUsernameLength 字符';
    }

    if (password != null && password.length > maxPasswordLength) {
      errors['password'] = '密码长度不能超过 $maxPasswordLength 字符';
    }

    if (group != null && group.length > maxGroupLength) {
      errors['group'] = '分组长度不能超过 $maxGroupLength 字符';
    }

    if (tags != null) {
      if (tags.length > maxTagCount) {
        errors['tags'] = '标签数量不能超过 $maxTagCount 个';
      }
      for (final tag in tags) {
        if (tag.length > maxTagLength) {
          errors['tags'] = '单个标签长度不能超过 $maxTagLength 字符';
          break;
        }
      }
    }

    if (notes != null && notes.length > maxNotesLength) {
      errors['notes'] = '备注长度不能超过 $maxNotesLength 字符';
    }

    if (errors.isNotEmpty) {
      return ValidationResult.failure(errors);
    }
    return ValidationResult.success();
  }
}
