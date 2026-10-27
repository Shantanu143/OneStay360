// lib/presentation/design/components/app_info.dart
//
// Small building blocks for read-only detail pages: label/value rows, a titled
// card, tags, a figure with its caption and a thin progress bar.
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'app_card.dart';

/// A label on the left and its value on the right.
class AppInfoRow extends StatelessWidget {
  const AppInfoRow(this.label, this.value, {super.key, this.trailing, this.muted = false});

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
          SizedBox(width: 108, child: Text(label, style: AppText.rowSubtitle)),
          Expanded(
            child: Text(
              value,
              style: muted ? AppText.style(15, 400, color: AppColors.inkSoft) : AppText.bodyStrong,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// A white card with a title, as the info blocks use.
class AppInfoCard extends StatelessWidget {
  const AppInfoCard({super.key, required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppText.cardTitle)),
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
class AppTag extends StatelessWidget {
  const AppTag(this.label, {super.key, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.green),
            const SizedBox(width: 6),
          ],
          Text(label, style: AppText.style(13, 600)),
        ],
      ),
    );
  }
}

/// A figure with its caption, side by side with others in a row.
class AppStatBox extends StatelessWidget {
  const AppStatBox({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.statCaption),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppText.statValue.copyWith(color: valueColor ?? AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// A thin progress bar in the app's greens.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({super.key, required this.fraction, this.onDark = false});

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
            ColoredBox(color: onDark ? AppColors.cardTile : AppColors.track),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: ColoredBox(color: onDark ? AppColors.mint : AppColors.green),
            ),
          ],
        ),
      ),
    );
  }
}
