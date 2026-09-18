import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:account_vault/main.dart';

void main() {
  testWidgets('QuickPanelHome smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AccountVaultApp());

    // Verify that the search input is present
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('阶段 0 桌面可行性验证壳已就绪'), findsOneWidget);
    expect(find.text('dev.local.account_vault'), findsOneWidget);
    expect(find.text('隐藏面板'), findsOneWidget);
    expect(find.text('退出程序'), findsOneWidget);
  });
}
