import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';
import 'habit_domain_visuals.dart';

/// Particles of a habit category (zzz for sleep, drops for hydration...) that
/// fly out of the answer the user just picked. It plays once, never blocks
/// touches, and with "reduce animations" on it paints nothing and ends at once.
///
/// [origin] is in this widget's own coordinates (usually the whole screen).
class DomainBurst extends StatefulWidget {
  const DomainBurst({
    super.key,
    required this.domain,
    required this.origin,
    this.onFinished,
    this.seed = 1,
  });

  final String domain;
  final Offset origin;
  final VoidCallback? onFinished;

  /// Makes the layout deterministic; a new seed gives a different scatter.
  final int seed;

  @override
  State<DomainBurst> createState() => _DomainBurstState();
}

class _DomainBurstState extends State<DomainBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  BurstPainter? _painter;
  bool _started = false;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.slow * 3.5)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onFinished?.call();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduce = AppMotion.reduce(context);
    if (_reduce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished?.call();
      });
      return;
    }
    _painter = BurstPainter(
      animation: _controller,
      origin: widget.origin,
      visual: DomainVisual.of(widget.domain),
      seed: widget.seed,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _painter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painter = _painter;
    if (_reduce || painter == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          key: const ValueKey('domain-burst-paint'),
          painter: painter,
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Spec {
  _Spec({
    required this.particle,
    required this.color,
    required this.angle,
    required this.speed,
    required this.size,
    required this.sway,
    required this.phase,
    required this.spin,
    required this.delay,
  });

  final BurstParticle particle;
  final Color color;
  final double angle;
  final double speed;
  final double size;
  final double sway;
  final double phase;
  final double spin;

  /// Fraction of the animation to wait before this particle appears.
  final double delay;
}

/// Draws the particles of a [DomainVisual] as a function of the animation.
class BurstPainter extends CustomPainter {
  BurstPainter({
    required Animation<double> animation,
    required this.origin,
    required this.visual,
    required this.seed,
  })  : _animation = animation,
        super(repaint: animation) {
    final random = math.Random(seed);
    _specs = [
      for (var i = 0; i < _count; i++) _spec(random, i),
    ];
    for (final spec in _specs) {
      _glyphs[spec] = _layout(spec);
    }
  }

  static const _count = 16;

  final Animation<double> _animation;
  final Offset origin;
  final DomainVisual visual;
  final int seed;

  late final List<_Spec> _specs;
  final Map<_Spec, TextPainter> _glyphs = {};

  _Spec _spec(math.Random random, int i) {
    final particle = visual.particles[i % visual.particles.length];
    final color = visual.colors[random.nextInt(visual.colors.length)];
    final double angle;
    switch (visual.motion) {
      case BurstMotion.radial:
        angle = (i / _count) * 2 * math.pi + random.nextDouble() * 0.3;
      case BurstMotion.floatUp:
        angle = -math.pi / 2 + (random.nextDouble() - 0.5) * 1.1;
      case BurstMotion.fall:
        angle = math.pi / 2 + (random.nextDouble() - 0.5) * 0.9;
    }
    return _Spec(
      particle: particle,
      color: color,
      angle: angle,
      speed: 0.55 + random.nextDouble() * 0.6,
      size: 16 + random.nextDouble() * 12,
      sway: 6 + random.nextDouble() * 10,
      phase: random.nextDouble() * 2 * math.pi,
      spin: (random.nextDouble() - 0.5) * 0.9,
      delay: visual.motion == BurstMotion.radial ? 0 : random.nextDouble() * 0.28,
    );
  }

  TextPainter _layout(_Spec spec) {
    final TextSpan span;
    switch (spec.particle) {
      case LetterParticle(:final letter):
        span = TextSpan(
          text: letter,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: spec.size,
            color: spec.color,
          ),
        );
      case IconParticle(:final icon):
        span = TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: spec.size,
            color: spec.color,
          ),
        );
    }
    return TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
  }

  Offset _position(_Spec spec, double t) {
    final local = ((t - spec.delay) / (1 - spec.delay)).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(local);
    const reach = 150.0;
    switch (visual.motion) {
      case BurstMotion.radial:
        final distance = spec.speed * reach * eased;
        return origin +
            Offset(math.cos(spec.angle) * distance, math.sin(spec.angle) * distance + 30 * local * local);
      case BurstMotion.floatUp:
        final distance = spec.speed * reach * 1.1 * local;
        final sway = math.sin(local * 2 * math.pi * 1.2 + spec.phase) * spec.sway;
        return origin + Offset(math.cos(spec.angle) * distance + sway, math.sin(spec.angle) * distance);
      case BurstMotion.fall:
        final drop = 190 * local * local + 40 * local;
        return origin +
            Offset(math.cos(spec.angle) * spec.speed * 70 * eased, -50 + drop * spec.speed);
    }
  }

  double _opacity(_Spec spec, double t) {
    final local = ((t - spec.delay) / (1 - spec.delay)).clamp(0.0, 1.0);
    if (local <= 0) return 0;
    final fadeIn = (local / 0.12).clamp(0.0, 1.0);
    final fadeOut = 1 - ((local - 0.6) / 0.4).clamp(0.0, 1.0);
    return math.min(fadeIn, fadeOut);
  }

  /// Where each particle is at [t] (0..1); used by tests to check determinism.
  List<Offset> debugPositions(double t) => [for (final spec in _specs) _position(spec, t)];

  void dispose() {
    for (final glyph in _glyphs.values) {
      glyph.dispose();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = _animation.value;
    for (final spec in _specs) {
      final opacity = _opacity(spec, t);
      if (opacity <= 0) continue;
      final glyph = _glyphs[spec]!;
      final position = _position(spec, t);
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(spec.spin * t * 2);
      canvas.saveLayer(
        Rect.fromLTWH(-glyph.width, -glyph.height, glyph.width * 2, glyph.height * 2),
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
      glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
      canvas.restore();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(BurstPainter oldDelegate) => false;
}
