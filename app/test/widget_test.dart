import 'package:flutter/material.dart';
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

    // 1. Initial QuickPanelView state
    expect(find.byType(TextField), findsOneWidget);
    expect(
      find.text('阶段 1 内存模式：内置 20 条覆盖设备、网站与应用的虚构凭据，修改不持久化到硬盘'),
      findsOneWidget,
    );
    expect(find.text('核心三层交换机 / 管理员'), findsOneWidget);

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

    // 4. Open New Entry Dialog
    await tester.tap(find.text('新建账号'));
    await tester.pumpAndSettle();

    expect(find.text('新增账号记录'), findsOneWidget);

    // 5. Test validation on empty title
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('标题不能为空'), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    // 6. Return to Quick Panel
    await tester.tap(find.byTooltip('返回快捷面板'));
    await tester.pumpAndSettle();

    expect(find.text('管理页面'), findsOneWidget);
  });
}
