import 'package:flutter/material.dart';

/// Shared timing for every animation in the app, so motion feels consistent.
/// All animations are finite: nothing loops, so screens still settle.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  /// One completed task.
  static const Duration celebration = Duration(milliseconds: 1800);

  /// The whole day completed (longer, with the banner).
  static const Duration celebrationDay = Duration(milliseconds: 2600);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOutCubic;

  /// True when the system asks to reduce animations (Android "Remove
  /// animations", iOS "Reduce Motion"). Decorative motion must be skipped.
  static bool reduce(BuildContext context) => MediaQuery.disableAnimationsOf(context);
}
