import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Fades its child in while rising a few pixels, once, when it first appears.
/// Give each item of a list a growing [delay] to get a staggered entrance.
///
/// The delay lives inside the animation (no timers), so it always finishes and
/// the screen settles. With "reduce animations" on, or [animate] false, the
/// child is shown right away.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.animate = true,
  });

  final Widget child;
  final Duration delay;
  final bool animate;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  bool _started = false;
  bool _skip = false;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + AppMotion.slow;
    _controller = AnimationController(vsync: this, duration: total);
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        widget.delay.inMilliseconds / total.inMilliseconds,
        1,
        curve: AppMotion.enter,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _skip = !widget.animate || AppMotion.reduce(context);
    if (!_skip) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_skip) return widget.child;
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(_curve),
        child: widget.child,
      ),
    );
  }
}
