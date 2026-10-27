// lib/presentation/design/motion.dart
//
// Small motion primitives shared by the home screen and the floating nav.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Fades and lifts [child] into place while [animation] moves through the
/// [start]..[end] slice of its 0..1 range. Drive several of these off one
/// controller to get a staggered page entrance.
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.animation,
    required this.start,
    required this.end,
    required this.child,
    this.dy = 18,
  });

  final Animation<double> animation;
  final double start;
  final double end;
  final double dy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = animation.drive(
      CurveTween(curve: Interval(start, end, curve: Curves.easeOutCubic)),
    );
    return FadeTransition(
      opacity: t,
      child: AnimatedBuilder(
        animation: t,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - t.value) * dy),
          child: child,
        ),
      ),
    );
  }
}

/// Scales its child down slightly while pressed and springs back on release.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.scale = 0.97,
    this.haptic = true,
    this.semanticLabel,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double scale;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value || !mounted) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setDown(true) : null,
        onTapUp: enabled ? (_) => _setDown(false) : null,
        onTapCancel: enabled ? () => _setDown(false) : null,
        onTap: enabled
            ? () {
                if (widget.haptic) HapticFeedback.lightImpact();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: Duration(milliseconds: _down ? 90 : 260),
          curve: _down ? Curves.easeOut : Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A softly pulsing placeholder block shown while data is loading.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
    this.color = Colors.white,
    this.opacity = 0.14,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;
  final double opacity;

  /// Variant for light surfaces.
  const Skeleton.onLight({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  }) : color = BizColors.ink,
       opacity = 0.07;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _pulse.stop();
      _started = false;
    } else if (!_started) {
      _started = true;
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = Tween<double>(
      begin: 0.55,
      end: 1,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_pulse);
    return FadeTransition(
      opacity: fade,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: widget.opacity),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
