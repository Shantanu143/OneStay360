// lib/presentation/views/home/home_header.dart
import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/motion.dart';

/// "Apex Living & Stays ⌄ / Hi, Rajesh" with the bell and avatar on the right.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.businessName,
    required this.firstName,
    required this.initials,
    required this.unreadCount,
    required this.onBusinessTap,
    required this.onBellTap,
    required this.onAvatarTap,
  });

  final String businessName;
  final String firstName;
  final String initials;
  final int unreadCount;
  final VoidCallback onBusinessTap;
  final VoidCallback onBellTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Pressable(
                  scale: 0.97,
                  onTap: onBusinessTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BizText.business,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: BizColors.green,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    firstName.isEmpty ? 'Hi there' : 'Hi, $firstName',
                    maxLines: 1,
                    style: BizText.greeting,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _BellButton(count: unreadCount, onTap: onBellTap),
          const SizedBox(width: 10),
          _AvatarButton(initials: initials, onTap: onAvatarTap),
        ],
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.92,
      onTap: onTap,
      semanticLabel: count > 0
          ? 'Notifications, $count unread'
          : 'Notifications',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 22,
                color: BizColors.ink,
              ),
            ),
            if (count > 0)
              Positioned(
                top: 3,
                right: 3,
                child: _CountBadge(key: ValueKey(count), count: count),
              ),
          ],
        ),
      ),
    );
  }
}

/// Red count bubble that pops in (and pops again whenever the count changes).
class _CountBadge extends StatelessWidget {
  const _CountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: Container(
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BizColors.badge,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(count > 9 ? '9+' : '$count', style: BizText.badge),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.initials, required this.onTap});

  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.92,
      onTap: onTap,
      semanticLabel: 'Profile',
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: BizColors.card,
          shape: BoxShape.circle,
        ),
        child: initials.isEmpty
            ? const Icon(
                Icons.person_outline_rounded,
                size: 22,
                color: Colors.white,
              )
            : Text(initials, style: BizText.avatarInitials),
      ),
    );
  }
}
