// lib/presentation/design/components/app_states.dart
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tokens.dart';
import 'app_button.dart';

class _StateLayout extends StatelessWidget {
  const _StateLayout({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: iconColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.style(20, 700, letterSpacing: -0.3),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.inkSoft),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _StateLayout(
      icon: icon,
      iconColor: AppColors.green,
      title: title,
      message: message,
      action: actionLabel != null && onAction != null
          ? AppButton(
              label: actionLabel!,
              onPressed: onAction,
              size: AppButtonSize.medium,
              expand: false,
            )
          : null,
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateLayout(
      icon: Icons.cloud_off_rounded,
      iconColor: AppColors.badge,
      title: title,
      message: message,
      action: onRetry == null
          ? null
          : AppButton(
              label: 'Try again',
              onPressed: onRetry,
              kind: AppButtonKind.tonal,
              size: AppButtonSize.medium,
              expand: false,
            ),
    );
  }
}

/// Pulsing white cards used while a list loads.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({super.key, this.count = 3, this.cardHeight = 120});

  final int count;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Container(
            height: cardHeight,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton.onLight(width: 160, height: 18, radius: 6),
                SizedBox(height: 10),
                Skeleton.onLight(width: 110, height: 13, radius: 5),
                Spacer(),
                Skeleton.onLight(width: double.infinity, height: 14, radius: 6),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
