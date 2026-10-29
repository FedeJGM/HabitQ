import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Counts an integer up (or down) to [value] when it appears or changes, and
/// builds what to show for each intermediate number. With "reduce animations"
/// on it shows the final value at once.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({super.key, required this.value, required this.builder});

  final int value;
  final Widget Function(BuildContext context, int current) builder;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduce(context)) return builder(context, value);
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: AppMotion.slow * 2,
      curve: AppMotion.enter,
      builder: (context, current, _) => builder(context, current),
    );
  }
}
