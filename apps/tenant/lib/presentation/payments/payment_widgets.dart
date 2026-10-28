// lib/presentation/payments/payment_widgets.dart
//
// Pieces shared by the rent screen and the first-bill screen.
import 'package:flutter/material.dart';

import '../common/device_actions.dart';
import '../common/widgets.dart';
import '../design/components/app_button.dart';
import '../design/components/app_card.dart';
import '../design/motion.dart';
import '../design/tokens.dart';

/// Dark card with the amount front and centre.
class AmountCard extends StatelessWidget {
  const AmountCard({super.key, required this.label, required this.amount, this.caption, this.warn = false});

  final String label;
  final double amount;
  final String? caption;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.hero)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.cardLabel),
          const SizedBox(height: 6),
          AnimatedNumber(value: amount, style: AppText.heroAmount.copyWith(fontSize: 34)),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(caption!, style: AppText.heroCaption.copyWith(color: warn ? AppColors.amber : null)),
          ],
        ],
      ),
    );
  }
}

/// A payment method to choose: radio-style card.
class MethodTile extends StatelessWidget {
  const MethodTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.98,
      onTap: onTap,
      semanticLabel: title,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.control + 2),
          border: Border.all(color: selected ? AppColors.green : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? AppColors.green : AppColors.page,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 21, color: selected ? Colors.white : AppColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(title, style: AppText.rowTitle)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.greenTint, borderRadius: BorderRadius.circular(8)),
                          child: Text(badge!, style: AppText.style(11, 700, color: AppColors.greenDeep)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.rowSubtitle),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.green : Colors.transparent,
                border: Border.all(color: selected ? AppColors.green : AppColors.chevron, width: 2),
              ),
              child: selected ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The owner's UPI id: copy it, or open a UPI app with everything filled in.
class UpiCard extends StatelessWidget {
  const UpiCard({super.key, required this.upiId, this.onOpenApp});

  final String upiId;
  final VoidCallback? onOpenApp;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Owner's UPI ID", style: AppText.caption),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: SelectableText(upiId, style: AppText.style(17, 700))),
              IconButton(
                tooltip: 'Copy UPI ID',
                icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.green),
                onPressed: () => copyText(context, upiId, message: 'UPI ID copied'),
              ),
            ],
          ),
          if (onOpenApp != null) ...[
            const SizedBox(height: 10),
            AppButton(
              label: 'Open UPI app',
              icon: Icons.open_in_new_rounded,
              kind: AppButtonKind.outline,
              size: AppButtonSize.medium,
              onPressed: onOpenApp,
            ),
          ],
        ],
      ),
    );
  }
}

/// A copyable detail line ("IFSC  HDFC0001  ⧉").
class CopyRow extends StatelessWidget {
  const CopyRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: AppText.body.copyWith(color: AppColors.inkSoft))),
          Expanded(child: Text(value, style: AppText.bodyStrong)),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Copy $label',
            icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.green),
            onPressed: () => copyText(context, value, message: '$label copied'),
          ),
        ],
      ),
    );
  }
}

class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.infoTint, borderRadius: BorderRadius.circular(AppRadius.control)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.infoInk),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppText.style(14, 500, color: AppColors.infoInk, height: 1.4))),
        ],
      ),
    );
  }
}

/// The happy ending: a big check that pops in.
class PaymentDone extends StatelessWidget {
  const PaymentDone({super.key, required this.title, required this.message, required this.onDone, this.icon = Icons.check_rounded});

  final String title;
  final String message;
  final VoidCallback onDone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (context, s, child) => Transform.scale(scale: s, child: child),
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(color: AppColors.greenTint, shape: BoxShape.circle),
                child: Icon(icon, size: 52, color: AppColors.green),
              ),
            ),
            const SizedBox(height: 22),
            Text(title, textAlign: TextAlign.center, style: AppText.style(24, 700, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: 28),
            AppButton(label: 'Done', expand: false, onPressed: onDone),
          ],
        ),
      ),
    );
  }
}
