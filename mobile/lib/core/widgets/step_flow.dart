import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_motion.dart';
import '../theme/app_theme.dart';

/// Building blocks of the "one question at a time" flows (the habit
/// questionnaire and the onboarding profile): the animated step container,
/// the answer tile, the progress bar and the Atrás/Siguiente row. Kept here so
/// both flows share the same motion instead of duplicating it.

/// Shows [child] for the current [step] and cross-fades with a small slide
/// when the step changes. [direction] is 1 when moving forward and -1 when
/// moving back, so the content always slides the way the user is going.
class StepSwitcher extends StatelessWidget {
  const StepSwitcher({
    super.key,
    required this.step,
    required this.direction,
    required this.child,
    this.alignment = Alignment.center,
  });

  final int step;
  final int direction;
  final Widget child;

  /// Where the content sits inside the available space. Centered by default;
  /// use [Alignment.topCenter] to keep it right under the header.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.medium,
      switchInCurve: AppMotion.enter,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) {
        final entering = child.key == ValueKey(step);
        final offset = Tween<Offset>(
          begin: Offset(entering ? 0.12 * direction : -0.12 * direction, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(step),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

/// Bar that grows smoothly towards [value] (0..1).
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({super.key, required this.value, this.barKey});

  final double value;

  /// Key given to the underlying [LinearProgressIndicator] (for tests).
  final Key? barKey;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: AppMotion.reduce(context) ? Duration.zero : AppMotion.medium,
      curve: AppMotion.enter,
      builder: (context, animated, _) => LinearProgressIndicator(
        key: barKey,
        value: animated,
        minHeight: 8,
        borderRadius: BorderRadius.circular(4),
        color: AppColors.primary,
        backgroundColor: AppColors.sky.withValues(alpha: 0.4),
      ),
    );
  }
}

/// Atrás / forward buttons of a step flow. A null [onBack] or [onForward]
/// disables that button; [isLoading] swaps the forward label for a spinner.
class StepNavigation extends StatelessWidget {
  const StepNavigation({
    super.key,
    required this.onBack,
    required this.onForward,
    required this.forwardLabel,
    this.isLoading = false,
  });

  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final String forwardLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: onBack,
          style: TextButton.styleFrom(minimumSize: const Size(96, 48), foregroundColor: AppColors.textPrimary),
          child: const Text('Atrás'),
        ),
        FilledButton(
          onPressed: onForward,
          style: FilledButton.styleFrom(minimumSize: const Size(140, 48), shape: const StadiumBorder()),
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(forwardLabel),
        ),
      ],
    );
  }
}

/// A large tappable answer. Reports the center of the tile (in global
/// coordinates) so a category animation can start from it.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final ValueChanged<Offset> onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      onTap: enabled ? () => onTap(_center(context)) : null,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.14) : Colors.white,
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.sky,
              width: selected ? 2 : 1.2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: enabled ? () => onTap(_center(context)) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    AnimatedScale(
                      scale: selected ? 1 : 0,
                      duration: AppMotion.fast,
                      curve: Curves.easeOutBack,
                      child: const Icon(Symbols.check_circle_rounded, fill: 1, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _center(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Offset.zero;
    return box.localToGlobal(box.size.center(Offset.zero));
  }
}
