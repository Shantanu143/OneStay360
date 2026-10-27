// lib/presentation/design/components/biz_list_row.dart
import 'package:flutter/material.dart';

import '../motion.dart';

import '../tokens.dart';
import 'biz_card.dart';

/// A rounded square icon tile (orange pencil, blue calendar...).
class BizIconTile extends StatelessWidget {
  const BizIconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
    this.iconSize = 20,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, size: iconSize, color: Colors.white),
    );
  }
}

/// Icon tile + title + subtitle + chevron, on its own white card (a "banner"
/// row such as "1 property is still a draft").
class BizListRow extends StatelessWidget {
  const BizListRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.flat = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Replaces the chevron.
  final Widget? trailing;

  /// No card of its own: for rows grouped inside one shared card.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final row = _row();
    if (!flat) {
      return BizCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: row,
      );
    }
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: row,
    );
    return onTap == null
        ? padded
        : Pressable(
            scale: 0.99,
            onTap: onTap,
            semanticLabel: title,
            child: padded,
          );
  }

  Widget _row() {
    return Row(
      children: [
        BizIconTile(icon: icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BizText.rowTitle,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BizText.rowSubtitle,
                ),
            ],
          ),
        ),
        if (trailing != null)
          trailing!
        else if (onTap != null)
          const Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: BizColors.chevron,
          ),
      ],
    );
  }
}
