import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:account_vault/application/vault_session_controller.dart';
import 'package:account_vault/infrastructure/mock/mock_vault_repository.dart';
import 'package:account_vault/main.dart';

void main() {
  testWidgets('QuickPanelView and ManagementView flow test', (
    WidgetTester tester,
  ) async {
    final repo = MockVaultRepository();
    final controller = VaultSessionController(
      repository: repo,
      isMockMode: true,
    );

    await tester.pumpWidget(AccountVaultApp(controller: controller));
    await tester.pumpAndSettle();

    // 1. Initial QuickPanelView state (no new account button here)
    expect(find.byType(TextField), findsOneWidget);
    expect(
      find.text('阶段 1 内存模式：内置 20 条覆盖设备、网站与应用的虚构凭据，修改不持久化到硬盘'),
      findsOneWidget,
    );
    expect(find.text('核心三层交换机 / 管理员'), findsOneWidget);
    expect(find.text('新建账号'), findsNothing);

    // 2. Search filtering
    await tester.enterText(find.byType(TextField), '交换机');
    await tester.pumpAndSettle();

    expect(find.text('核心三层交换机 / 管理员'), findsOneWidget);
    expect(find.text('核心三层交换机 / 只读巡检'), findsOneWidget);
    expect(find.text('汇聚交换机 01 (楼宇B)'), findsOneWidget);
    expect(find.text('AWS 生产云控制台'), findsNothing);

    // 3. Open Management View
    await tester.tap(find.text('管理页面'));
    await tester.pumpAndSettle();

    expect(find.text('账号库管理'), findsOneWidget);
    expect(find.text('新建账号'), findsOneWidget);

    // 4. Open New Entry Dialog from Management View
    await tester.tap(find.text('新建账号'));
    await tester.pumpAndSettle();

    expect(find.text('新增账号记录'), findsOneWidget);

    // Test validation on empty title
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('标题不能为空'), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    // 5. Return to Quick Panel
    await tester.tap(find.byTooltip('返回快捷面板'));
    await tester.pumpAndSettle();

    expect(find.text('管理页面'), findsOneWidget);
    expect(find.text('新建账号'), findsNothing);

    // 7. Test Group Filter Chips on Quick Panel
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('网络设备'), findsWidgets);

    // Tap on '网络设备' group chip
    await tester.tap(find.text('网络设备').first);
    await tester.pumpAndSettle();

    expect(controller.selectedGroup, equals('网络设备'));
    expect(find.text('核心三层交换机 / 管理员'), findsOneWidget);
    expect(find.text('AWS 生产云控制台'), findsNothing);

    // Tap on '全部' chip to reset group filter
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();

    expect(controller.selectedGroup, isNull);

    // Clear search query to restore all entries
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    expect(find.text('AWS 生产云控制台'), findsOneWidget);

    // 8. Verify Ctrl+N does nothing in QuickPanelView
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('新增账号记录'), findsNothing);

    // 9. Go to ManagementView and verify Ctrl+N opens EntryFormDialog
    await tester.tap(find.text('管理页面'));
    await tester.pumpAndSettle();
    expect(find.text('账号库管理'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('新增账号记录'), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });
}
