// lib/presentation/views/home/needs_attention_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/tokens.dart';
import '../../design/motion.dart';

/// One tappable row of the "Needs attention" list.
class AttentionItem {
  const AttentionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// White card listing what the owner should act on. While [loading] it shows
/// placeholder rows; when the data lands the card grows smoothly and the rows
/// fade in.
class NeedsAttentionCard extends StatelessWidget {
  const NeedsAttentionCard({
    super.key,
    required this.items,
    required this.loading,
  });

  final List<AttentionItem> items;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (loading) {
      content = const _SkeletonRows(key: ValueKey('loading'));
    } else if (items.isEmpty) {
      content = const _AllCaughtUp(key: ValueKey('empty'));
    } else {
      content = Column(
        key: ValueKey('items-${items.length}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const _RowDivider(),
            _AttentionRow(item: items[i]),
          ],
        ],
      );
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, if (current != null) current],
          ),
          child: content,
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 64,
      endIndent: 42,
      color: BizColors.hairline,
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: Colors.white),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item});

  final AttentionItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        item.onTap();
      },
      splashFactory: NoSplash.splashFactory,
      highlightColor: BizColors.ink.withValues(alpha: 0.05),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 59),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11.75),
          child: Row(
            children: [
              _IconTile(icon: item.icon, color: item.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BizText.rowTitle,
                    ),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BizText.rowSubtitle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Transform.translate(
                offset: const Offset(2, 0),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: BizColors.chevron,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllCaughtUp extends StatelessWidget {
  const _AllCaughtUp({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const _IconTile(icon: Icons.check_rounded, color: BizColors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("You're all caught up", style: BizText.rowTitle),
                  const SizedBox(height: 1),
                  Text(
                    'Nothing needs your attention right now',
                    style: BizText.rowSubtitle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonRows extends StatelessWidget {
  const _SkeletonRows({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row() => const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Skeleton.onLight(width: 36, height: 36, radius: 10),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton.onLight(width: 150, height: 14, radius: 6),
              SizedBox(height: 7),
              Skeleton.onLight(width: 110, height: 11, radius: 5),
            ],
          ),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [row(), const _RowDivider(), row()],
    );
  }
}
