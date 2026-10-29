import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_theme.dart';

/// Circular progress (0..1) that sweeps from sky blue to green and fills in
/// once when it appears or when [value] changes. With "reduce animations" on
/// it shows the final value at once. [child] is drawn in the middle.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.child,
    this.size = 64,
    this.strokeWidth = 7,
    this.semanticLabel,
  });

  final double value;
  final Widget child;
  final double size;
  final double strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    final duration = AppMotion.reduce(context) ? Duration.zero : AppMotion.slow * 2;
    return Semantics(
      label: semanticLabel,
      container: semanticLabel != null,
      child: ExcludeSemantics(
        excluding: semanticLabel != null,
        child: SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: target),
            duration: duration,
            curve: AppMotion.enter,
            builder: (context, animated, child) => CustomPaint(
              key: const ValueKey('progress-ring-paint'),
              painter: RingPainter(value: animated, strokeWidth: strokeWidth),
              child: Center(child: child),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class RingPainter extends CustomPainter {
  const RingPainter({required this.value, required this.strokeWidth});

  final double value;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(strokeWidth / 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppColors.sky.withValues(alpha: 0.35);
    canvas.drawArc(arc, 0, 2 * math.pi, false, track);

    if (value <= 0) return;
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [AppColors.skyDeep, AppColors.primary],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(arc, -math.pi / 2, 2 * math.pi * value, false, progress);
  }

  @override
  bool shouldRepaint(RingPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.strokeWidth != strokeWidth;
}
