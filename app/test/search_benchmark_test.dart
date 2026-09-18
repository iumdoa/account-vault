// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';

import 'package:account_vault/domain/models/vault_entry.dart';
import 'package:account_vault/domain/services/entry_search_service.dart';

void main() {
  test('Benchmark search on 1000 synthetic records (<100ms requirement)', () {
    final entries = <VaultEntry>[];
    final now = DateTime.now().toUtc();

    for (var i = 0; i < 1000; i++) {
      entries.add(
        VaultEntry(
          id: 'synth-$i',
          title: '服务器节点集群 / 核心交换机 $i (机房B区)',
          address: '192.168.${(i ~/ 250) + 1}.${i % 250}:8443',
          username: 'admin_$i',
          password: 'Password_Synthetic_#$i',
          group: i % 4 == 0
              ? '网络设备'
              : i % 4 == 1
                  ? '开发工具'
                  : i % 4 == 2
                      ? '云计算'
                      : '数据存储',
          tags: ['cisco', 'infra', 'cluster-$i', 'node-${i % 10}'],
          notes: '合成记录 $i 用于性能基准压测，测试多字段检索与中文包含性能。',
          updatedAt: now.subtract(Duration(minutes: i)),
        ),
      );
    }

    // Warm up
    EntrySearchService.search(entries, '交换机');

    // Benchmark 1: Chinese substring
    final sw1 = Stopwatch()..start();
    final res1 = EntrySearchService.search(entries, '交换机 25');
    sw1.stop();

    // Benchmark 2: IP fragment
    final sw2 = Stopwatch()..start();
    final res2 = EntrySearchService.search(entries, '192.168.2');
    sw2.stop();

    // Benchmark 3: Multi-term
    final sw3 = Stopwatch()..start();
    final res3 = EntrySearchService.search(entries, 'admin_500 cisco');
    sw3.stop();

    // Benchmark 4: Empty query (sort all 1000)
    final sw4 = Stopwatch()..start();
    final res4 = EntrySearchService.search(entries, '');
    sw4.stop();

    print('Benchmark Results (1000 entries):');
    print('1. Chinese substring ("交换机 25"): ${sw1.elapsedMicroseconds / 1000} ms (found ${res1.length})');
    print('2. IP fragment ("192.168.2"): ${sw2.elapsedMicroseconds / 1000} ms (found ${res2.length})');
    print('3. Multi-term ("admin_500 cisco"): ${sw3.elapsedMicroseconds / 1000} ms (found ${res3.length})');
    print('4. Empty query (stable sort 1000): ${sw4.elapsedMicroseconds / 1000} ms (found ${res4.length})');

    expect(sw1.elapsedMilliseconds, lessThan(100));
    expect(sw2.elapsedMilliseconds, lessThan(100));
    expect(sw3.elapsedMilliseconds, lessThan(100));
    expect(sw4.elapsedMilliseconds, lessThan(100));
  });
}
