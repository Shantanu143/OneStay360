// lib/presentation/design/components/biz_chips.dart
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';

class BizChipData {
  const BizChipData(this.label, {this.count, this.icon});

  final String label;
  final int? count;
  final IconData? icon;
}

/// Horizontally scrolling single-select chips (All 4 · Active · Vacant ...).
///
/// The selected chip is kept in view: opening on a chip that sits off to the
/// right (a deep link to a late tab) scrolls it into sight, and so does
/// selecting one that is cut off at an edge.
class BizFilterChips extends StatefulWidget {
  const BizFilterChips({
    super.key,
    required this.chips,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<BizChipData> chips;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  State<BizFilterChips> createState() => _BizFilterChipsState();
}

class _BizFilterChipsState extends State<BizFilterChips> {
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
  void didUpdateWidget(BizFilterChips old) {
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
                child: BizChip(
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

class BizChip extends StatelessWidget {
  const BizChip({
    super.key,
    required this.data,
    required this.selected,
    required this.onTap,
    this.onCard = false,
  });

  final BizChipData data;
  final bool selected;
  final VoidCallback onTap;

  /// Set when the chip sits on a white card: the unselected fill is then the
  /// page grey, since a white chip would vanish into the card.
  final bool onCard;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : BizColors.ink;
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
            color: selected ? BizColors.card : (onCard ? BizColors.page : Colors.white),
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
                Text(data.label, style: BizText.chip.copyWith(color: fg)),
                if (data.count != null) ...[
                  const SizedBox(width: 7),
                  Text(
                    '${data.count}',
                    style: BizText.chipCount.copyWith(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.7)
                          : BizColors.inkSoft,
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

enum BizTone { neutral, success, warning, danger, info, draft }

/// Small status pill: "Draft", "Active", "Overdue"...
class BizStatusPill extends StatelessWidget {
  const BizStatusPill(
    this.label, {
    super.key,
    this.tone = BizTone.neutral,
    this.dot = true,
  });

  final String label;
  final BizTone tone;

  /// Leading colored dot.
  final bool dot;

  ({Color bg, Color ink, Color dot}) get _palette {
    switch (tone) {
      case BizTone.neutral:
        return (
          bg: BizColors.page,
          ink: BizColors.inkSoft,
          dot: BizColors.inkSoft,
        );
      case BizTone.success:
        return (
          bg: BizColors.greenTint,
          ink: BizColors.greenDeep,
          dot: BizColors.green,
        );
      case BizTone.warning:
        return (
          bg: BizColors.warnTint,
          ink: BizColors.warnInk,
          dot: BizColors.orange,
        );
      case BizTone.danger:
        return (
          bg: BizColors.dangerTint,
          ink: BizColors.dangerInk,
          dot: BizColors.badge,
        );
      case BizTone.info:
        return (
          bg: BizColors.infoTint,
          ink: BizColors.infoInk,
          dot: BizColors.blue,
        );
      case BizTone.draft:
        return (
          bg: Colors.white,
          ink: BizColors.draftInk,
          dot: BizColors.orange,
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
              style: BizText.pill.copyWith(color: p.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single-select chips that wrap onto several lines (gender, food preference,
/// payment cycle...).
class BizChoiceWrap<T> extends StatelessWidget {
  const BizChoiceWrap({
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

  /// See [BizChip.onCard].
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
            child: BizChip(
              data: BizChipData(labelOf?.call(o) ?? '$o'),
              selected: o == selected,
              onTap: () => onChanged(o),
              onCard: onCard,
            ),
          ),
      ],
    );
  }
}
