// lib/presentation/design/components/biz_step_pills.dart
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';

/// Wizard progress: a scrolling row of numbered pills (done / current /
/// upcoming) and a slim progress bar underneath. Completed steps are
/// tappable to jump back; later steps are not.
class BizStepPills extends StatefulWidget {
  const BizStepPills({
    super.key,
    required this.steps,
    required this.current,
    this.onStepTap,
  });

  final List<String> steps;

  /// Zero-based index of the active step.
  final int current;

  /// Called with the index of a completed step the user taps.
  final ValueChanged<int>? onStepTap;

  @override
  State<BizStepPills> createState() => _BizStepPillsState();
}

class _BizStepPillsState extends State<BizStepPills> {
  late List<GlobalKey> _keys = _makeKeys();

  List<GlobalKey> _makeKeys() =>
      List.generate(widget.steps.length, (_) => GlobalKey());

  @override
  void didUpdateWidget(BizStepPills oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps.length != widget.steps.length) _keys = _makeKeys();
    if (oldWidget.current != widget.current) _scrollToCurrent();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToCurrent(animate: false),
    );
  }

  void _scrollToCurrent({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = widget.current < _keys.length
          ? _keys[widget.current].currentContext
          : null;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.3,
        duration: animate ? const Duration(milliseconds: 320) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final fraction = widget.steps.isEmpty
        ? 0.0
        : ((widget.current + 1) / widget.steps.length).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: widget.steps.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _StepPill(
              key: _keys[i],
              index: i,
              label: widget.steps[i],
              state: i < widget.current
                  ? _StepState.done
                  : (i == widget.current
                        ? _StepState.current
                        : _StepState.upcoming),
              onTap: i < widget.current && widget.onStepTap != null
                  ? () => widget.onStepTap!(i)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0xFFDCDCE0)),
                  ),
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fraction),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          key: const ValueKey('step-progress-fill'),
                          widthFactor: v,
                          heightFactor: 1,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: BizColors.green,
                              borderRadius: BorderRadius.all(
                                Radius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _StepState { done, current, upcoming }

class _StepPill extends StatelessWidget {
  const _StepPill({
    super.key,
    required this.index,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final int index;
  final String label;
  final _StepState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final current = state == _StepState.current;
    final done = state == _StepState.done;

    final pill = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(7, 0, 14, 0),
      decoration: BoxDecoration(
        color: current ? BizColors.ink : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: current
            ? [
                BoxShadow(
                  color: BizColors.ink.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: current
                  ? Colors.white.withValues(alpha: 0.18)
                  : (done ? BizColors.greenTint : BizColors.page),
            ),
            child: done
                ? const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: BizColors.greenDeep,
                  )
                : Text(
                    '${index + 1}',
                    style: BizText.style(
                      13,
                      700,
                      color: current ? Colors.white : BizColors.inkSoft,
                      height: 1,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: BizText.style(
              14,
              600,
              color: current ? Colors.white : BizColors.ink,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      selected: current,
      button: onTap != null,
      label: 'Step ${index + 1}, $label',
      child: onTap == null
          ? pill
          : Pressable(scale: 0.96, onTap: onTap, child: pill),
    );
  }
}
