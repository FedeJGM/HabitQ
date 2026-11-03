import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Page transition for the tabs and pushed screens: the new page fades in while
/// rising a few pixels. The page below stays still, so switching tabs feels
/// like a quick cross-fade instead of the heavy default zoom. With "reduce
/// animations" on, the page just appears.
class FadeSlideTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlideTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.medium;

  @override
  Duration get reverseTransitionDuration => AppMotion.medium;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduce(context)) return child;
    final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
