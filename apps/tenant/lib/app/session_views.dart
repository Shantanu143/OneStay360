// lib/app/session_views.dart
//
// Full-screen states shown by the AuthGate around the main app: branded
// splash and "couldn't load".
import 'package:flutter/material.dart';

import '../presentation/design/components/app_brand_logo.dart';
import '../presentation/design/components/app_button.dart';
import '../presentation/design/motion.dart';
import '../presentation/design/tokens.dart';

/// Dark brand splash with a gently pulsing mark. Shown while the app works
/// out who is signed in and loads their business.
class BrandSplash extends StatefulWidget {
  const BrandSplash({super.key});

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(
      begin: 0.94,
      end: 1.04,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_pulse);

    return Scaffold(
      backgroundColor: AppColors.card,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: scale,
              child: const AppBrandLogo(height: 64, framed: true, alignment: CrossAxisAlignment.center),
            ),
            const SizedBox(height: 18),
            Text(
              'Your home away from home',
              style: AppText.style(14, 500, color: AppColors.onCardMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actions,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Reveal(
              animation: const AlwaysStoppedAnimation(1),
              start: 0,
              end: 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 40, color: iconColor),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppText.style(24, 700, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 28),
                  ...actions,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Preparing the account failed (offline, permission...). Retry or sign out.
class SessionErrorView extends StatelessWidget {
  const SessionErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: Icons.cloud_off_rounded,
      iconColor: AppColors.badge,
      title: "Couldn't load your account",
      message: message,
      actions: [
        AppButton(label: 'Try again', onPressed: onRetry),
        const SizedBox(height: 10),
        AppButton(
          label: 'Sign out',
          kind: AppButtonKind.ghost,
          size: AppButtonSize.medium,
          onPressed: onSignOut,
        ),
      ],
    );
  }
}
