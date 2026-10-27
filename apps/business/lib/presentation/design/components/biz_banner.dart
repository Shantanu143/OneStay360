// lib/presentation/design/components/biz_banner.dart
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';
import 'biz_chips.dart';

/// A tinted message strip: info, warnings and gentle explanations.
class BizBanner extends StatelessWidget {
  const BizBanner({
    super.key,
    required this.message,
    this.tone = BizTone.info,
    this.icon,
    this.onTap,
  });

  final String message;
  final BizTone tone;
  final IconData? icon;
  final VoidCallback? onTap;

  ({Color bg, Color ink, IconData icon}) get _p => switch (tone) {
    BizTone.warning => (
      bg: BizColors.warnTint,
      ink: BizColors.warnInk,
      icon: Icons.info_outline_rounded,
    ),
    BizTone.danger => (
      bg: BizColors.dangerTint,
      ink: BizColors.dangerInk,
      icon: Icons.error_outline_rounded,
    ),
    BizTone.success => (
      bg: BizColors.greenTint,
      ink: BizColors.greenDeep,
      icon: Icons.check_circle_outline_rounded,
    ),
    _ => (
      bg: BizColors.infoTint,
      ink: BizColors.infoInk,
      icon: Icons.info_outline_rounded,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? p.icon, size: 18, color: p.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: BizText.style(13, 500, color: p.ink, height: 1.35),
            ),
          ),
        ],
      ),
    );
    return onTap == null
        ? body
        : Pressable(scale: 0.98, onTap: onTap, child: body);
  }
}
