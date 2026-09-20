import 'package:account_vault/application/vault_session_controller.dart';
import 'package:account_vault/infrastructure/mock/mock_vault_repository.dart';
import 'package:account_vault/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'arrow navigation scrolls beyond the viewport and handles repeats',
    (tester) async {
      tester.view.physicalSize = const Size(800, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = VaultSessionController(
        repository: MockVaultRepository(),
        isMockMode: true,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(AccountVaultApp(controller: controller));
      await tester.pumpAndSettle();

      final list = find.byKey(const ValueKey('quick-entry-list'));
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      final search = tester.widget<TextField>(find.byType(TextField));
      final firstTitle = controller.filteredEntries.first.title;
      void expectSelectionVisible() {
        final viewport = tester.getRect(list);
        final title = tester.getRect(
          find.text(controller.selectedEntry!.title),
        );
        expect(title.top, greaterThanOrEqualTo(viewport.top));
        expect(title.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(search.focusNode!.hasFocus, isTrue);
      }

      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(controller.selectedIndex, 4);
      expect(scrollable.position.pixels, greaterThan(0));
      expectSelectionVisible();
      expect(
        tester.getRect(find.text(firstTitle)).bottom,
        lessThan(tester.getRect(list).top),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      for (var i = 0; i < 30; i++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expectSelectionVisible();
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      expect(controller.selectedIndex, controller.filteredEntries.length - 1);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      for (var i = 0; i < 30; i++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expectSelectionVisible();
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      expect(controller.selectedIndex, 0);
      expect(scrollable.position.pixels, 0);

      controller.selectIndex(controller.filteredEntries.length - 1);
      await tester.pumpAndSettle();
      expectSelectionVisible();
      await tester.enterText(find.byType(TextField), '交换机');
      await tester.pumpAndSettle();
      expect(controller.selectedIndex, 0);
      expect(scrollable.position.pixels, 0);
      expectSelectionVisible();

      // Arrow keys belong to the IME while composing text.
      search.controller!.value = const TextEditingValue(
        text: '交换机',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(controller.selectedIndex, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
