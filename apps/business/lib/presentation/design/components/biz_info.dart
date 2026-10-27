// lib/presentation/design/components/biz_info.dart
//
// Small building blocks for read-only detail pages: label/value rows, a titled
// card, tags, a figure with its caption and a thin progress bar.
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'biz_card.dart';

/// A label on the left and its value on the right.
class BizInfoRow extends StatelessWidget {
  const BizInfoRow(this.label, this.value, {super.key, this.trailing, this.muted = false});

  final String label;
  final String value;
  final Widget? trailing;

  /// Greys the value out (a detail that hasn't been filled in).
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 108, child: Text(label, style: BizText.rowSubtitle)),
          Expanded(
            child: Text(
              value,
              style: muted ? BizText.style(15, 400, color: BizColors.inkSoft) : BizText.bodyStrong,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// A white card with a title, as the info blocks use.
class BizInfoCard extends StatelessWidget {
  const BizInfoCard({super.key, required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return BizCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: BizText.cardTitle)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

/// A small rounded label (amenities, rules).
class BizTag extends StatelessWidget {
  const BizTag(this.label, {super.key, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BizColors.page,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: BizColors.green),
            const SizedBox(width: 6),
          ],
          Text(label, style: BizText.style(13, 600)),
        ],
      ),
    );
  }
}

/// A figure with its caption, side by side with others in a row.
class BizStatBox extends StatelessWidget {
  const BizStatBox({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BizRadius.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: BizText.statCaption),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: BizText.statValue.copyWith(color: valueColor ?? BizColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// A thin progress bar in the app's greens.
class BizProgressBar extends StatelessWidget {
  const BizProgressBar({super.key, required this.fraction, this.onDark = false});

  final double fraction;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: onDark ? BizColors.cardTile : BizColors.track),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: ColoredBox(color: onDark ? BizColors.mint : BizColors.green),
            ),
          ],
        ),
      ),
    );
  }
}
