// lib/app/session_views.dart
//
// Full-screen states shown by the AuthGate around the main app: branded
// splash, "no business yet" and "couldn't load".
import 'package:flutter/material.dart';

import '../presentation/design/components/biz_brand_logo.dart';
import '../presentation/design/components/biz_button.dart';
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
    final scale = Tween<double>(begin: 0.94, end: 1.04)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_pulse);

    return Scaffold(
      backgroundColor: BizColors.card,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: scale,
              child: const BizBrandLogo(height: 64, framed: true, alignment: CrossAxisAlignment.center),
            ),
            const SizedBox(height: 18),
            Text('For PG & hostel owners',
                style: BizText.style(14, 500, color: BizColors.onCardMuted)),
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
      backgroundColor: BizColors.page,
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
                  Text(title,
                      textAlign: TextAlign.center,
                      style: BizText.style(24, 700, letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: BizText.body.copyWith(color: BizColors.inkSoft)),
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

/// Signed in, but not part of any business yet.
class NoBusinessView extends StatelessWidget {
  const NoBusinessView({
    super.key,
    required this.onCreateBusiness,
    required this.onSignOut,
  });

  final VoidCallback onCreateBusiness;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: Icons.apartment_rounded,
      iconColor: BizColors.green,
      title: 'No active business',
      message:
          'Create a business to start managing properties, or open an invite link from your owner to join one.',
      actions: [
        BizButton(label: 'Create business', onPressed: onCreateBusiness),
        const SizedBox(height: 10),
        BizButton(
          label: 'Sign out',
          kind: BizButtonKind.ghost,
          size: BizButtonSize.medium,
          onPressed: onSignOut,
        ),
      ],
    );
  }
}

/// The owner turned this person's access off.
class AccessOffView extends StatelessWidget {
  const AccessOffView({
    super.key,
    required this.businessName,
    required this.onCheckAgain,
    required this.onSignOut,
  });

  final String businessName;
  final VoidCallback onCheckAgain;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final where = businessName.isEmpty ? 'this business' : businessName;
    return _CenteredMessage(
      icon: Icons.lock_outline_rounded,
      iconColor: BizColors.orange,
      title: 'Your access is off',
      message: 'The owner of $where has turned your access off, so you can\'t open its properties for now. '
          'Ask them to turn it back on.',
      actions: [
        BizButton(label: 'Check again', onPressed: onCheckAgain),
        const SizedBox(height: 10),
        BizButton(
          label: 'Sign out',
          kind: BizButtonKind.ghost,
          size: BizButtonSize.medium,
          onPressed: onSignOut,
        ),
      ],
    );
  }
}

/// Loading the business failed (offline, permission...). Retry or sign out.
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
      iconColor: BizColors.badge,
      title: "Couldn't load your business",
      message: message,
      actions: [
        BizButton(label: 'Try again', onPressed: onRetry),
        const SizedBox(height: 10),
        BizButton(
          label: 'Sign out',
          kind: BizButtonKind.ghost,
          size: BizButtonSize.medium,
          onPressed: onSignOut,
        ),
      ],
    );
  }
}
