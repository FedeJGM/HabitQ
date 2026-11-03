import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Pops its child in once: starts smaller, overshoots a little and settles at
/// full size. Used for the icon of the tab that just became selected. With
/// "reduce animations" on, the child is shown as is.
class BounceIn extends StatefulWidget {
  const BounceIn({super.key, required this.child});

  final Widget child;

  @override
  State<BounceIn> createState() => _BounceInState();
}

class _BounceInState extends State<BounceIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _started = false;
  bool _skip = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.medium);
    _scale = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _skip = AppMotion.reduce(context);
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
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
