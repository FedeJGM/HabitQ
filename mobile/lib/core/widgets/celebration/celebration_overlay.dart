import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_theme.dart';
import '../habitq_card.dart';

/// Fireworks drawn over the screen when a task is completed. With
/// [dayComplete] the show is bigger and a banner congratulates the user.
///
/// It plays once and calls [onFinished]; it never blocks touches and, when the
/// system asks to reduce animations, it skips the particles (the banner, which
/// carries information, still shows).
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({
    super.key,
    this.dayComplete = false,
    this.onFinished,
    this.seed = 7,
  });

  final bool dayComplete;
  final VoidCallback? onFinished;

  /// Makes the particle layout deterministic (and different on every burst).
  final int seed;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Burst> _bursts;
  bool _started = false;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.dayComplete ? AppMotion.celebrationDay : AppMotion.celebration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onFinished?.call();
      });
    _bursts = _buildBursts(widget.dayComplete, widget.seed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduce = AppMotion.reduce(context);
    if (_reduce && !widget.dayComplete) {
      // Nothing to show: finish right after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished?.call();
      });
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduce && !widget.dayComplete) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!_reduce)
            RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey('firework-particles'),
                painter: _FireworkPainter(_controller, _bursts),
                size: Size.infinite,
              ),
            ),
          if (widget.dayComplete) _DayCompleteBanner(animation: _controller),
        ],
      ),
    );
  }
}

class _Particle {
  const _Particle(this.angle, this.speed, this.size, this.color);

  final double angle;
  final double speed;
  final double size;
  final Color color;
}

class _Burst {
  const _Burst(this.cx, this.cy, this.delay, this.particles);

  /// Center as a fraction of the overlay size.
  final double cx;
  final double cy;

  /// Start of the burst as a fraction of the whole animation.
  final double delay;
  final List<_Particle> particles;
}

const _palette = [AppColors.primary, AppColors.primaryDark, AppColors.accent, AppColors.sun];

List<_Burst> _buildBursts(bool dayComplete, int seed) {
  final random = math.Random(seed);
  final layout = dayComplete
      ? const [
          (0.50, 0.30, 0.00),
          (0.20, 0.45, 0.12),
          (0.80, 0.40, 0.20),
          (0.35, 0.62, 0.30),
          (0.65, 0.55, 0.38),
        ]
      : const [
          (0.50, 0.35, 0.00),
          (0.25, 0.50, 0.15),
          (0.75, 0.45, 0.30),
        ];
  final count = dayComplete ? 34 : 26;
  return [
    for (final (cx, cy, delay) in layout)
      _Burst(cx, cy, delay, [
        for (var i = 0; i < count; i++)
          _Particle(
            (i / count) * 2 * math.pi + random.nextDouble() * 0.25,
            0.55 + random.nextDouble() * 0.45,
            2.2 + random.nextDouble() * 2.2,
            _palette[random.nextInt(_palette.length)],
          ),
      ]),
  ];
}

class _FireworkPainter extends CustomPainter {
  _FireworkPainter(this.animation, this.bursts) : super(repaint: animation);

  final Animation<double> animation;
  final List<_Burst> bursts;

  static const _gravity = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final reach = size.shortestSide * 0.38;
    final paint = Paint()..strokeCap = StrokeCap.round;

    Offset position(Offset center, _Particle p, double local) {
      final eased = Curves.easeOutCubic.transform(local);
      final distance = p.speed * reach * eased;
      return center +
          Offset(
            math.cos(p.angle) * distance,
            math.sin(p.angle) * distance + _gravity * reach * local * local,
          );
    }

    for (final burst in bursts) {
      if (t <= burst.delay) continue;
      final local = ((t - burst.delay) / (1 - burst.delay)).clamp(0.0, 1.0);
      final fade = 1 - Curves.easeInQuad.transform(local);
      final center = Offset(size.width * burst.cx, size.height * burst.cy);
      final previous = (local - 0.07).clamp(0.0, 1.0);
      for (final p in burst.particles) {
        final end = position(center, p, local);
        paint.color = p.color.withValues(alpha: 0.6 * fade);
        paint.strokeWidth = p.size * 0.8;
        canvas.drawLine(position(center, p, previous), end, paint);
        paint.color = p.color.withValues(alpha: fade);
        canvas.drawCircle(end, p.size * (1 - 0.5 * local), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_FireworkPainter oldDelegate) => oldDelegate.bursts != bursts;
}

class _DayCompleteBanner extends StatelessWidget {
  const _DayCompleteBanner({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final fadeIn = Curves.easeOut.transform((t / 0.18).clamp(0.0, 1.0));
        final fadeOut = 1 - Curves.easeIn.transform(((t - 0.82) / 0.18).clamp(0.0, 1.0));
        final scale = 0.9 + 0.1 * Curves.easeOutBack.transform((t / 0.25).clamp(0.0, 1.0));
        return Align(
          alignment: const Alignment(0, -0.6),
          child: Opacity(
            opacity: math.min(fadeIn, fadeOut),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: const HabitQCard(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.emoji_events_rounded, fill: 1, size: 34, color: AppColors.accent),
            SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Día completo!',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Terminaste todas tus tareas de hoy.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
