import 'package:flutter/material.dart';

/// A small outline copy glyph that does not depend on a bundled icon font.
class CopyIcon extends StatelessWidget {
  const CopyIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    return ExcludeSemantics(
      child: CustomPaint(
        size: const Size.square(18),
        painter: _CopyIconPainter(
          (theme.color ?? Colors.white).withValues(alpha: theme.opacity ?? 1),
        ),
      ),
    );
  }
}

class _CopyIconPainter extends CustomPainter {
  const _CopyIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 18, size.height / 18);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(4, 12)
        ..lineTo(3, 12)
        ..quadraticBezierTo(2, 12, 2, 11)
        ..lineTo(2, 3)
        ..quadraticBezierTo(2, 2, 3, 2)
        ..lineTo(11, 2)
        ..quadraticBezierTo(12, 2, 12, 3)
        ..lineTo(12, 4),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 6, 10, 10),
        const Radius.circular(1.5),
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CopyIconPainter oldDelegate) =>
      color != oldDelegate.color;
}
