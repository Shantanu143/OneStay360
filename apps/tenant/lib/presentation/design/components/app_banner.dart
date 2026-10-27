// lib/presentation/design/components/app_banner.dart
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';
import 'app_chips.dart';

/// A tinted message strip: info, warnings and gentle explanations.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    this.tone = AppTone.info,
    this.icon,
    this.onTap,
  });

  final String message;
  final AppTone tone;
  final IconData? icon;
  final VoidCallback? onTap;

  ({Color bg, Color ink, IconData icon}) get _p => switch (tone) {
    AppTone.warning => (
      bg: AppColors.warnTint,
      ink: AppColors.warnInk,
      icon: Icons.info_outline_rounded,
    ),
    AppTone.danger => (
      bg: AppColors.dangerTint,
      ink: AppColors.dangerInk,
      icon: Icons.error_outline_rounded,
    ),
    AppTone.success => (
      bg: AppColors.greenTint,
      ink: AppColors.greenDeep,
      icon: Icons.check_circle_outline_rounded,
    ),
    _ => (
      bg: AppColors.infoTint,
      ink: AppColors.infoInk,
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
              style: AppText.style(13, 500, color: p.ink, height: 1.35),
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
