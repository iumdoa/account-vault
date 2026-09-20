import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:account_vault/application/vault_session_controller.dart';
import 'package:account_vault/infrastructure/mock/mock_vault_repository.dart';
import 'package:account_vault/presentation/widgets/management_auth_dialog.dart';
import 'package:account_vault/presentation/widgets/vault_icons.dart';

void main() {
  group('ManagementAuthDialog Widget Tests', () {
    testWidgets('shows dialog, validates empty password, supports cancel', (
      WidgetTester tester,
    ) async {
      final controller = VaultSessionController(
        repository: MockVaultRepository(),
        isMockMode: true,
      );

      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    dialogResult = await ManagementAuthDialog.show(
                      context,
                      controller: controller,
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('管理权限验证'), findsOneWidget);
      expect(find.text('进入账号库管理后台需验证主密码'), findsOneWidget);

      // Submit without entering password -> error message
      await tester.tap(find.text('验 证'));
      await tester.pumpAndSettle();
      expect(find.text('请输入主密码'), findsOneWidget);

      // Cancel dialog -> returns false
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('管理权限验证'), findsNothing);
      expect(dialogResult, isFalse);
    });

    testWidgets('supports password toggle and succeeds on valid password', (
      WidgetTester tester,
    ) async {
      final controller = VaultSessionController(
        repository: MockVaultRepository(),
        isMockMode: true,
      );

      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    dialogResult = await ManagementAuthDialog.show(
                      context,
                      controller: controller,
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Toggle obscure password
      expect(find.byIcon(VaultIcons.eyeOff), findsOneWidget);
      await tester.tap(find.byIcon(VaultIcons.eyeOff));
      await tester.pumpAndSettle();
      expect(find.byIcon(VaultIcons.eye), findsOneWidget);

      // Enter password and verify
      await tester.enterText(find.byType(TextField), 'valid_secret');
      await tester.tap(find.text('验 证'));
      await tester.pumpAndSettle();

      expect(find.text('管理权限验证'), findsNothing);
      expect(dialogResult, isTrue);
    });
  });
}
