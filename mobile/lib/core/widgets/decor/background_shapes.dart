import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Soft organic shapes and a dotted pattern behind the screens, like the
/// illustrations of the Figma mockups. Static (never animated) and tinted from
/// the palette, so it adds depth without competing with the content.
class BackgroundShapes extends StatelessWidget {
  const BackgroundShapes({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: RepaintBoundary(
        key: ValueKey('background-shapes'),
        child: CustomPaint(painter: _ShapesPainter(), size: Size.infinite),
      ),
    );
  }
}

class _ShapesPainter extends CustomPainter {
  const _ShapesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = AppColors.sky.withValues(alpha: 0.30);
    canvas.drawPath(_blob(Offset(w * 1.0, h * 0.08), w * 0.42, 1), paint);

    paint.color = AppColors.primary.withValues(alpha: 0.08);
    canvas.drawPath(_blob(Offset(-w * 0.08, h * 0.52), w * 0.34, 2), paint);

    paint.color = AppColors.sky.withValues(alpha: 0.26);
    canvas.drawPath(_blob(Offset(w * 0.95, h * 0.92), w * 0.5, 3), paint);

    // Dotted pattern, as in the login illustration.
    paint.color = AppColors.skyDeep.withValues(alpha: 0.30);
    final origin = Offset(w * 0.05, h * 0.11);
    const spacing = 11.0;
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 6; col++) {
        canvas.drawCircle(origin + Offset(col * spacing, row * spacing), 1.4, paint);
      }
    }
  }

  /// Smooth closed blob: a few points around [center] with uneven radii,
  /// joined with Catmull-Rom curves.
  Path _blob(Offset center, double radius, int seed) {
    const points = 7;
    final random = math.Random(seed);
    final vertices = [
      for (var i = 0; i < points; i++)
        center +
            Offset.fromDirection(
              (i / points) * 2 * math.pi,
              radius * (0.82 + random.nextDouble() * 0.28),
            ),
    ];
    Offset at(int i) => vertices[(i + points) % points];

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 0; i < points; i++) {
      final c1 = at(i) + (at(i + 1) - at(i - 1)) / 6;
      final c2 = at(i + 1) - (at(i + 2) - at(i)) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, at(i + 1).dx, at(i + 1).dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_ShapesPainter oldDelegate) => false;
}
