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
  }) : color = AppColors.ink,
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

/// Fades and lifts [child] in once, when it first appears. Skipped when the
/// platform asks for reduced motion.
class EntranceFade extends StatefulWidget {
  const EntranceFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.dy = 16,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double dy;

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Reveal(
      animation: _c,
      start: 0,
      end: 1,
      dy: widget.dy,
      child: widget.child,
    );
  }
}

/// Fades between [child] values when [child]'s key changes (loading to
/// loaded, one state to the next).
class SmoothSwitch extends StatelessWidget {
  const SmoothSwitch({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 280),
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: child,
    );
  }
}
