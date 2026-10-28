// lib/presentation/design/components/app_header.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion.dart';
import '../tokens.dart';

/// Page header: optional back button, a grey eyebrow line, the title, and
/// round action buttons on the right.
///
/// Tab roots use the big 34px title; pushed pages (with a back button) use a
/// compact 26px title so long names fit.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.actions = const [],
    this.showBack = false,
    this.onBack,
  });

  final String title;
  final String? eyebrow;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final titleStyle = showBack ? AppText.pushedTitle : AppText.pageTitle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showBack) ...[
            AppRoundButton(
              icon: Icons.arrow_back_ios_new_rounded,
              iconSize: 18,
              tooltip: 'Back',
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.eyebrow,
                  ),
                  const SizedBox(height: 4),
                ],
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: showBack ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
              ],
            ),
          ),
          for (final action in actions) ...[const SizedBox(width: 10), action],
        ],
      ),
    );
  }
}

/// 44px white circle with an icon (sort, notifications, back...).
class AppRoundButton extends StatelessWidget {
  const AppRoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.iconSize = 22,
    this.badgeCount = 0,
    this.dark = false,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double iconSize;

  /// Red count bubble (0 hides it).
  final int badgeCount;

  /// Dark filled variant (used for the profile avatar slot).
  final bool dark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = Pressable(
      scale: 0.92,
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap!();
            },
      haptic: false,
      semanticLabel: tooltip,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: dark ? AppColors.card : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: dark ? Colors.white : AppColors.ink,
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.badge,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: AppText.badge,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
