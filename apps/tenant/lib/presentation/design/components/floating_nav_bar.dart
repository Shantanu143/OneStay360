// lib/presentation/design/components/floating_nav_bar.dart
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';

class FloatingNavItem {
  const FloatingNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Floating glass pill with the main tabs, plus an optional round "+" button
/// beside it. Meant for [Scaffold.bottomNavigationBar]; its own background is
/// transparent so content can scroll underneath (`extendBody: true`).
///
/// The highlight glides between tabs. The whole bar steps aside while the
/// keyboard is open.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.onQuickAdd,
  });

  static const double pillHeight = 62;

  final List<FloatingNavItem> items;

  /// Index of the highlighted item, or -1 when the current screen is not one
  /// of the tabs.
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// When set, a "+" button is shown; the future completes when whatever it
  /// opened has been dismissed (the button's icon rotates meanwhile).
  final Future<void> Function()? onQuickAdd;

  /// Total height the bar occupies, so scrolling content can leave room.
  static double heightFor(BuildContext context) =>
      pillHeight + _bottomMargin(context) + 8;

  static double _bottomMargin(BuildContext context) {
    // The window's own inset: inside a Scaffold the local MediaQuery's padding
    // and viewPadding are rewritten around the bar, which would double-count.
    final inset = MediaQueryData.fromView(View.of(context)).viewPadding.bottom;
    return inset > 0 ? math.max(inset - 8, 12.0) : 16.0;
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, _bottomMargin(context)),
      child: Row(
        children: [
          Expanded(
            child: _GlassPill(
              child: _NavRow(
                items: items,
                selectedIndex: selectedIndex,
                onSelected: onSelected,
              ),
            ),
          ),
          if (onQuickAdd != null) ...[
            const SizedBox(width: 12),
            _QuickAddButton(onPressed: onQuickAdd!),
          ],
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(
      Radius.circular(FloatingNavBar.pillHeight / 2),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: FloatingNavBar.pillHeight,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: Colors.white.withValues(alpha: 0.92),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatefulWidget {
  const _NavRow({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<FloatingNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<_NavRow> createState() => _NavRowState();
}

class _NavRowState extends State<_NavRow> {
  static const double _highlightWidth = 69;
  static const double _highlightHeight = 50;

  /// Last real selection, so the highlight fades out where it was instead of
  /// jumping when no tab is selected.
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.selectedIndex >= 0) _lastIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(_NavRow old) {
    super.didUpdateWidget(old);
    if (widget.selectedIndex >= 0) _lastIndex = widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;
    final visible = widget.selectedIndex >= 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = constraints.maxWidth / n;
        final width = math.min(cell - 2, _highlightWidth);
        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOutCubic,
              left: cell * _lastIndex + (cell - width) / 2,
              top: (FloatingNavBar.pillHeight - _highlightHeight) / 2,
              width: width,
              height: _highlightHeight,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: visible ? 1 : 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.navSelected,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: _NavButton(
                      item: widget.items[i],
                      selected: i == widget.selectedIndex,
                      onTap: () => widget.onSelected(i),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? AppColors.green : AppColors.ink;
    final labelColor = selected ? AppColors.green : AppColors.navLabel;

    return Semantics(
      selected: selected,
      child: Pressable(
        scale: 0.9,
        semanticLabel: item.label,
        onTap: onTap,
        child: SizedBox(
          height: FloatingNavBar.pillHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: iconColor),
                duration: const Duration(milliseconds: 220),
                builder: (context, color, _) =>
                    Icon(item.icon, size: 22, color: color),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: AppText.navLabelStyle.copyWith(color: labelColor),
                maxLines: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(item.label),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAddButton extends StatefulWidget {
  const _QuickAddButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  State<_QuickAddButton> createState() => _QuickAddButtonState();
}

class _QuickAddButtonState extends State<_QuickAddButton> {
  bool _open = false;

  Future<void> _handleTap() async {
    if (_open) return;
    setState(() => _open = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.92,
      semanticLabel: 'Quick add',
      onTap: _handleTap,
      child: Container(
        width: FloatingNavBar.pillHeight,
        height: FloatingNavBar.pillHeight,
        decoration: BoxDecoration(
          color: AppColors.green,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.green.withValues(alpha: 0.32),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: AnimatedRotation(
          turns: _open ? 0.125 : 0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: const Icon(Icons.add_rounded, size: 32, color: Colors.white),
        ),
      ),
    );
  }
}
