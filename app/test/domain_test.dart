import 'package:flutter_test/flutter_test.dart';

import 'package:account_vault/domain/models/vault_entry.dart';
import 'package:account_vault/domain/services/entry_search_service.dart';
import 'package:account_vault/domain/services/uuid_service.dart';

void main() {
  group('UuidService Tests', () {
    test('generates valid RFC 4122 v4 UUID format', () {
      final uuid = UuidService.generateV4();
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(uuid),
        isTrue,
      );
    });

    test('generates unique UUIDs', () {
      final set = <String>{};
      for (var i = 0; i < 1000; i++) {
        set.add(UuidService.generateV4());
      }
      expect(set.length, equals(1000));
    });
  });

  group('VaultEntry & Validator Tests', () {
    test(
      'preserves username, password, address, notes exactly without trimming',
      () {
        const rawUser = '  admin_user \t ';
        const rawPass = ' P@ssw0rd! 🔑 \n line2 ';
        const rawAddr = '  https://192.168.1.1:8443/  ';
        const rawNotes = '  Notes line 1\nNotes line 2  ';

        final sanitized = VaultEntryValidator.sanitize(
          title: '   Switch Admin   ',
          address: rawAddr,
          username: rawUser,
          password: rawPass,
          group: '  Network  ',
          tags: [' cisco ', ' switch ', ' cisco '],
          notes: rawNotes,
        );

        // Title and group trimmed; tags deduped and trimmed
        expect(sanitized.title, equals('Switch Admin'));
        expect(sanitized.group, equals('Network'));
        expect(sanitized.tags, equals(['cisco', 'switch']));

        // Credentials strictly preserved raw
        expect(sanitized.address, equals(rawAddr));
        expect(sanitized.username, equals(rawUser));
        expect(sanitized.password, equals(rawPass));
        expect(sanitized.notes, equals(rawNotes));
      },
    );

    test('validates required title and length constraints', () {
      // Empty title fails
      final res1 = VaultEntryValidator.validate(title: '   ', username: 'user');
      expect(res1.isValid, isFalse);
      expect(res1.errors['title'], contains('标题不能为空'));

      // Title > 256 fails
      final res2 = VaultEntryValidator.validate(
        title: 'A' * 257,
        username: 'user',
      );
      expect(res2.isValid, isFalse);
      expect(res2.errors['title'], contains('长度不能超过 256'));

      // Both username and password empty fails
      final res3 = VaultEntryValidator.validate(
        title: 'Valid Title',
        username: '',
        password: '',
      );
      expect(res3.isValid, isFalse);
      expect(res3.errors['credentials'], contains('账号与密码不得同时为空'));

      // Only username without password is valid
      final res4 = VaultEntryValidator.validate(
        title: 'Valid Title',
        username: 'admin',
        password: null,
      );
      expect(res4.isValid, isTrue);

      // Only password without username is valid
      final res5 = VaultEntryValidator.validate(
        title: 'Valid Title',
        username: null,
        password: 'secret_password_123',
      );
      expect(res5.isValid, isTrue);

      // Tag count limit > 32 fails
      final res6 = VaultEntryValidator.validate(
        title: 'Valid Title',
        password: 'pass',
        tags: List.generate(33, (i) => 'tag$i'),
      );
      expect(res6.isValid, isFalse);
      expect(res6.errors['tags'], contains('不能超过 32'));
    });

    test('serializes and deserializes JSON losslessly', () {
      final entry = VaultEntry(
        id: UuidService.generateV4(),
        title: '核心路由器',
        address: '10.0.0.1',
        username: ' root ',
        password: ' 🔐p@ss! \n ',
        group: '网络设备',
        tags: ['router', 'core'],
        notes: '备注第一行\n备注第二行',
        createdAt: DateTime.utc(2026, 9, 18, 10, 0, 0),
        updatedAt: DateTime.utc(2026, 9, 18, 10, 30, 0),
      );

      final json = entry.toJson();
      final restored = VaultEntry.fromJson(json);

      expect(restored.id, equals(entry.id));
      expect(restored.title, equals(entry.title));
      expect(restored.address, equals(entry.address));
      expect(restored.username, equals(entry.username));
      expect(restored.password, equals(entry.password));
      expect(restored.group, equals(entry.group));
      expect(restored.tags, equals(entry.tags));
      expect(restored.notes, equals(entry.notes));
      expect(restored.createdAt, equals(entry.createdAt));
      expect(restored.updatedAt, equals(entry.updatedAt));
    });
  });

  group('EntrySearchService Tests', () {
    final entry1 = VaultEntry(
      id: 'uuid-1',
      title: '核心交换机 / 管理员',
      address: '192.168.1.1',
      username: 'admin',
      password: 'hidden_secret_123',
      group: '网络设备',
      tags: ['cisco', 'switch', 'core'],
      notes: '机房 A 机柜 01',
      updatedAt: DateTime.utc(2026, 9, 18, 11, 0, 0),
    );

    final entry2 = VaultEntry(
      id: 'uuid-2',
      title: '核心交换机 / 只读',
      address: '192.168.1.1',
      username: 'monitor',
      password: 'readonly_pass_456',
      group: '网络设备',
      tags: ['cisco', 'switch', 'readonly'],
      notes: '监控巡检专用',
      updatedAt: DateTime.utc(2026, 9, 18, 10, 0, 0),
    );

    final entry3 = VaultEntry(
      id: 'uuid-3',
      title: 'GitHub 生产账号',
      address: 'https://github.com/company',
      username: 'devops@company.org',
      password: 'ghp_token_super_secret',
      group: '开发工具',
      tags: ['git', 'ci-cd'],
      notes: '包含组织所有者权限',
      updatedAt: DateTime.utc(2026, 9, 18, 9, 0, 0),
    );

    final entry4 = VaultEntry(
      id: 'uuid-4',
      title: 'AWS 云控制台',
      address: 'https://signin.aws.amazon.com',
      username: 'cloud-admin',
      password: 'aws_master_password',
      group: '云计算',
      tags: ['aws', 'infra'],
      notes: '主账号，已开启 MFA',
      updatedAt: DateTime.utc(2026, 9, 18, 8, 0, 0),
    );

    final allEntries = [entry1, entry2, entry3, entry4];

    test(
      'empty query returns all entries in stable order (updatedAt desc)',
      () {
        final results = EntrySearchService.search(allEntries, '   ');
        expect(results.length, equals(4));
        expect(results[0].id, equals('uuid-1'));
        expect(results[1].id, equals('uuid-2'));
        expect(results[2].id, equals('uuid-3'));
        expect(results[3].id, equals('uuid-4'));
      },
    );

    test('searches Chinese substrings in title, group, notes', () {
      final results1 = EntrySearchService.search(allEntries, '交换机');
      expect(results1.length, equals(2));
      expect(results1.map((e) => e.id), containsAll(['uuid-1', 'uuid-2']));

      final results2 = EntrySearchService.search(allEntries, '机柜');
      expect(results2.length, equals(1));
      expect(results2.first.id, equals('uuid-1'));
    });

    test('searches IP and port fragment in address', () {
      final results = EntrySearchService.search(allEntries, '192.168');
      expect(results.length, equals(2));
      expect(results.map((e) => e.id), containsAll(['uuid-1', 'uuid-2']));
    });

    test('searches case-insensitively for ASCII', () {
      final results = EntrySearchService.search(allEntries, 'GITHUB');
      expect(results.length, equals(1));
      expect(results.first.id, equals('uuid-3'));
    });

    test('multi-term search requires all terms to match', () {
      // "交换机 admin" -> matches entry1 (title + username), does not match entry2
      final results1 = EntrySearchService.search(allEntries, '交换机 admin');
      expect(results1.length, equals(1));
      expect(results1.first.id, equals('uuid-1'));

      // "交换机 devops" -> neither entry matches all terms
      final results2 = EntrySearchService.search(allEntries, '交换机 devops');
      expect(results2.isEmpty, isTrue);
    });

    test('NEVER searches password field', () {
      final results1 = EntrySearchService.search(
        allEntries,
        'hidden_secret_123',
      );
      expect(results1.isEmpty, isTrue);

      final results2 = EntrySearchService.search(allEntries, 'ghp_token');
      expect(results2.isEmpty, isTrue);
    });

    test('prioritizes exact matches over partial matches', () {
      final testEntries = [
        VaultEntry(
          id: 'partial-1',
          title: 'GitHub Enterprise Server',
          updatedAt: DateTime.utc(2026, 9, 18, 12, 0, 0),
        ),
        VaultEntry(
          id: 'exact-1',
          title: 'GitHub',
          updatedAt: DateTime.utc(2026, 9, 18, 10, 0, 0),
        ),
      ];

      final results = EntrySearchService.search(testEntries, 'GitHub');
      expect(results.first.id, equals('exact-1'));
      expect(results.last.id, equals('partial-1'));
    });
  });
}
