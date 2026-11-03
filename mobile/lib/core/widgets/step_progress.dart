import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_theme.dart';

/// "Paso X de Y" with a bar that grows as the user advances through a short
/// flow (for example the onboarding).
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final label = 'Paso $current de $total';
    return Semantics(
      label: label,
      container: true,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(end: current / total),
              duration: AppMotion.reduce(context) ? Duration.zero : AppMotion.medium,
              curve: AppMotion.enter,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
                color: AppColors.primary,
                backgroundColor: AppColors.sky.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
