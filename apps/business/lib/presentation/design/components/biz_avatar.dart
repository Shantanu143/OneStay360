// lib/presentation/design/components/biz_avatar.dart
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';

/// Initials in a circle ("RS"). Falls back to a person icon for empty names.
class BizAvatar extends StatelessWidget {
  const BizAvatar({
    super.key,
    required this.initials,
    this.size = 44,
    this.background = BizColors.card,
    this.foreground = Colors.white,
  });

  final String initials;
  final double size;
  final Color background;
  final Color foreground;

  /// "Rajesh Sharma" -> "RS".
  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: initials.isEmpty
          ? Icon(
              Icons.person_outline_rounded,
              size: size * 0.5,
              color: foreground,
            )
          : Text(
              initials,
              style: BizText.style(
                size * 0.34,
                700,
                color: foreground,
                letterSpacing: 0.2,
                height: 1,
              ),
            ),
    );
  }
}

/// The profile avatar in a page header: a tappable [BizAvatar].
class BizAvatarButton extends StatelessWidget {
  const BizAvatarButton({
    super.key,
    required this.initials,
    required this.onTap,
  });

  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.92,
      onTap: onTap,
      semanticLabel: 'Profile',
      child: BizAvatar(initials: initials),
    );
  }
}
