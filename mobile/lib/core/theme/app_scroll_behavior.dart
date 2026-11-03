import 'package:flutter/material.dart';

/// One scroll feel for the whole app: a soft bounce at the edges on every
/// platform, and lists that always respond to the finger even when they are
/// shorter than the screen. Flutter renders it at the refresh rate the display
/// grants, so on a 120 Hz phone the scroll runs at 120 fps.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
