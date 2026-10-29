import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_theme.dart';

/// White rounded card with the Figma "shadow-4" elevation. When it is
/// tappable it shrinks slightly while pressed, and it repaints on its own so
/// long lists scroll smoothly.
class HabitQCard extends StatefulWidget {
  const HabitQCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  State<HabitQCard> createState() => _HabitQCardState();
}

class _HabitQCardState extends State<HabitQCard> {
  static const _pressedScale = 0.98;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    final tappable = widget.onTap != null;
    return RepaintBoundary(
      child: AnimatedScale(
        scale: tappable && _pressed ? _pressedScale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: radius,
            boxShadow: AppShadows.card,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap,
              onHighlightChanged: tappable ? (value) => setState(() => _pressed = value) : null,
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
