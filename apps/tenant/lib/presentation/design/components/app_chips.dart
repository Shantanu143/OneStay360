// lib/presentation/design/components/app_chips.dart
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';

class AppChipData {
  const AppChipData(this.label, {this.count, this.icon});

  final String label;
  final int? count;
  final IconData? icon;
}

/// Horizontally scrolling single-select chips (All 4 · Active · Vacant ...).
///
/// The selected chip is kept in view: opening on a chip that sits off to the
/// right (a deep link to a late tab) scrolls it into sight, and so does
/// selecting one that is cut off at an edge.
class AppFilterChips extends StatefulWidget {
  const AppFilterChips({
    super.key,
    required this.chips,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<AppChipData> chips;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  State<AppFilterChips> createState() => _AppFilterChipsState();
}

class _AppFilterChipsState extends State<AppFilterChips> {
  static const double _margin = 16;

  final ScrollController _controller = ScrollController();
  List<GlobalKey> _keys = const [];

  @override
  void initState() {
    super.initState();
    _syncKeys();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(animate: false),
    );
  }

  @override
  void didUpdateWidget(AppFilterChips old) {
    super.didUpdateWidget(old);
    _syncKeys();
    if (old.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reveal(animate: true),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncKeys() {
    if (_keys.length != widget.chips.length) {
      _keys = List.generate(widget.chips.length, (_) => GlobalKey());
    }
  }

  void _reveal({required bool animate}) {
    if (!mounted || !_controller.hasClients) return;
    final i = widget.selectedIndex;
    if (i < 0 || i >= _keys.length) return;
    final chipContext = _keys[i].currentContext;
    final viewport = context.findRenderObject();
    final chip = chipContext?.findRenderObject();
    if (chip is! RenderBox || viewport is! RenderBox || !chip.attached) return;

    final left = chip.localToGlobal(Offset.zero, ancestor: viewport).dx;
    final right = left + chip.size.width;
    final double delta;
    if (left < _margin) {
      delta = left - _margin;
    } else if (right > viewport.size.width - _margin) {
      delta = right - (viewport.size.width - _margin);
    } else {
      return;
    }
    final position = _controller.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (animate) {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A handful of chips, so they are all built: that lets us measure the
    // selected one wherever it is.
    return SizedBox(
      height: 36,
      // Full width, so a short row sits at the left instead of being centered
      // by whatever column it is in.
      width: double.infinity,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < widget.chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              KeyedSubtree(
                key: _keys[i],
                child: AppChip(
                  data: widget.chips[i],
                  selected: i == widget.selectedIndex,
                  onTap: () => widget.onSelected(i),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.data,
    required this.selected,
    required this.onTap,
    this.onCard = false,
  });

  final AppChipData data;
  final bool selected;
  final VoidCallback onTap;

  /// Set when the chip sits on a white card: the unselected fill is then the
  /// page grey, since a white chip would vanish into the card.
  final bool onCard;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    return Semantics(
      selected: selected,
      button: true,
      label: data.label,
      child: Pressable(
        scale: 0.95,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: selected ? AppColors.card : (onCard ? AppColors.page : Colors.white),
            borderRadius: BorderRadius.circular(18),
          ),
          // widthFactor keeps the chip as wide as its label, also inside a Wrap
          // (a Container with `alignment` would stretch to the full width).
          child: Center(
            widthFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data.icon != null) ...[
                  Icon(data.icon, size: 17, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(data.label, style: AppText.chip.copyWith(color: fg)),
                if (data.count != null) ...[
                  const SizedBox(width: 7),
                  Text(
                    '${data.count}',
                    style: AppText.chipCount.copyWith(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum AppTone { neutral, success, warning, danger, info, draft }

/// Small status pill: "Draft", "Active", "Overdue"...
class AppStatusPill extends StatelessWidget {
  const AppStatusPill(
    this.label, {
    super.key,
    this.tone = AppTone.neutral,
    this.dot = true,
  });

  final String label;
  final AppTone tone;

  /// Leading colored dot.
  final bool dot;

  ({Color bg, Color ink, Color dot}) get _palette {
    switch (tone) {
      case AppTone.neutral:
        return (
          bg: AppColors.page,
          ink: AppColors.inkSoft,
          dot: AppColors.inkSoft,
        );
      case AppTone.success:
        return (
          bg: AppColors.greenTint,
          ink: AppColors.greenDeep,
          dot: AppColors.green,
        );
      case AppTone.warning:
        return (
          bg: AppColors.warnTint,
          ink: AppColors.warnInk,
          dot: AppColors.orange,
        );
      case AppTone.danger:
        return (
          bg: AppColors.dangerTint,
          ink: AppColors.dangerInk,
          dot: AppColors.badge,
        );
      case AppTone.info:
        return (
          bg: AppColors.infoTint,
          ink: AppColors.infoInk,
          dot: AppColors.blue,
        );
      case AppTone.draft:
        return (
          bg: Colors.white,
          ink: AppColors.draftInk,
          dot: AppColors.orange,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: p.dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.pill.copyWith(color: p.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single-select chips that wrap onto several lines (gender, food preference,
/// payment cycle...).
class AppChoiceWrap<T> extends StatelessWidget {
  const AppChoiceWrap({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.labelOf,
    this.onCard = false,
  });

  final List<T> options;
  final T? selected;
  final ValueChanged<T> onChanged;
  final String Function(T)? labelOf;

  /// See [AppChip.onCard].
  final bool onCard;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          SizedBox(
            height: 36,
            child: AppChip(
              data: AppChipData(labelOf?.call(o) ?? '$o'),
              selected: o == selected,
              onTap: () => onChanged(o),
              onCard: onCard,
            ),
          ),
      ],
    );
  }
}
