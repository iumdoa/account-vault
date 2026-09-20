import 'dart:ui' as ui;

import 'package:account_vault/presentation/widgets/copy_icon.dart';
import 'package:account_vault/presentation/widgets/vault_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('copy glyph is visible without hover or icon fonts', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: const IconTheme(
              data: IconThemeData(color: VaultIcons.muted),
              child: CopyIcon(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final pixels = data!.buffer.asUint8List();
        var visiblePixels = 0;
        for (var i = 3; i < pixels.length; i += 4) {
          if (pixels[i] > 128) visiblePixels++;
        }
        expect(visiblePixels, greaterThan(100));
        expect(visiblePixels, lessThan(image.width * image.height ~/ 2));
      } finally {
        image.dispose();
      }
    });
  });
}
