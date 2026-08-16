import 'package:flutter/material.dart';

import 'tokens.dart';

/// Shared motion helpers.
abstract final class HMotionHelpers {
  /// Standard quick card entrance: fade + slight scale.
  static Widget entrance({
    required Key key,
    required Widget child,
    Duration duration = HMotion.base,
    int delayMs = 0,
  }) {
    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: HMotion.ease,
      builder: (context, t, c) {
        final delayed = _stagger(t, delayMs, duration);
        return Opacity(
          opacity: delayed.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.94 + 0.06 * delayed,
            child: c,
          ),
        );
      },
      child: child,
    );
  }

  static double _stagger(double t, int delayMs, Duration duration) {
    if (delayMs <= 0) return t;
    final total = duration.inMilliseconds;
    final fraction = delayMs / total;
    if (t < fraction) return 0;
    return ((t - fraction) / (1 - fraction)).clamp(0.0, 1.0);
  }

  /// Ken Burns loop for hero artwork.
  static Widget kenBurns({
    required Key key,
    required Widget child,
    Duration duration = const Duration(seconds: 45),
  }) {
    return _KenBurns(key: key, duration: duration, child: child);
  }
}

class _KenBurns extends StatefulWidget {
  const _KenBurns({required super.key, required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  State<_KenBurns> createState() => _KenBurnsState();
}

class _KenBurnsState extends State<_KenBurns>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.scale(scale: 1.0 + 0.08 * t, child: child);
      },
      child: widget.child,
    );
  }
}
