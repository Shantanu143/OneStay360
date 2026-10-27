// lib/presentation/views/home/home_sheets.dart
//
// Bottom sheets opened from the home screen: the "+" quick-add menu and the
// rent reminders list.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/tokens.dart';
import '../../view_models/business_dashboard_viewmodel.dart';
import '../../design/motion.dart';
import 'home_format.dart';

Future<void> _showBizSheet(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: BizColors.ink.withValues(alpha: 0.38),
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      reverseDuration: Duration(milliseconds: 260),
      reverseCurve: Curves.easeInCubic,
    ),
    builder: builder,
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD9DCDB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(title, style: BizText.style(20, 800, letterSpacing: -0.4)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: BizText.rowSubtitle),
          ],
          const SizedBox(height: 14),
          Flexible(child: child),
        ],
      ),
    );
  }
}

// ─── Quick add ────────────────────────────────────────────────────────────────

class QuickAction {
  const QuickAction({
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

/// Opens the quick-add menu. Completes once the sheet is dismissed; a chosen
/// action runs after the sheet has closed.
Future<void> showQuickAddSheet(
  BuildContext context, {
  required List<QuickAction> actions,
}) async {
  QuickAction? chosen;
  await _showBizSheet(
    context,
    (sheetContext) => _SheetFrame(
      title: 'Quick add',
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          thickness: 1,
          indent: 56,
          color: BizColors.hairline,
        ),
        itemBuilder: (_, i) {
          final action = actions[i];
          return Pressable(
            scale: 0.98,
            onTap: () {
              chosen = action;
              Navigator.of(sheetContext).pop();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: action.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(action.icon, size: 22, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(action.title, style: BizText.rowTitle),
                        Text(action.subtitle, style: BizText.rowSubtitle),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: BizColors.chevron,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
  chosen?.onTap();
}

// ─── Reminders ────────────────────────────────────────────────────────────────

/// Digits-only WhatsApp number with the India country code added when the
/// number looks like a local 10-digit mobile. Null when there's no usable number.
String? whatsappNumber(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0') && digits.length == 11) {
    digits = digits.substring(1);
  }
  if (digits.length == 10) {
    digits = '91$digits';
  }
  return digits.length >= 11 ? digits : null;
}

String reminderMessage(RentDue due, String businessName) {
  final name = firstNameOf(due.tenantName);
  final month = due.month.isEmpty ? 'this month' : due.month;
  final dueOn = due.dueDate == null
      ? ''
      : ' (due ${DateFormat('d MMM').format(due.dueDate!)})';
  final from = businessName.isEmpty ? '' : ' - $businessName';
  return 'Hi${name.isEmpty ? '' : ' $name'}, a gentle reminder that your rent of '
      '${formatInr(due.amount)} for $month is still pending$dueOn. '
      'Please pay at your earliest convenience. Thank you!$from';
}

Uri whatsappUri(String number, String message) =>
    Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(message)}');

Future<void> showRemindersSheet(
  BuildContext context, {
  required List<RentDue> dues,
  required String businessName,
  required String monthLabel,
}) {
  return _showBizSheet(
    context,
    (sheetContext) => _SheetFrame(
      title: 'Send reminders',
      subtitle: dues.length == 1
          ? '1 tenant has pending rent for $monthLabel'
          : '${dues.length} tenants have pending rent for $monthLabel',
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        itemCount: dues.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          thickness: 1,
          indent: 56,
          color: BizColors.hairline,
        ),
        itemBuilder: (_, i) =>
            _DueRow(due: dues[i], businessName: businessName),
      ),
    ),
  );
}

class _DueRow extends StatelessWidget {
  const _DueRow({required this.due, required this.businessName});

  final RentDue due;
  final String businessName;

  String get _status {
    final date = due.dueDate;
    if (date == null) return due.overdue ? 'Overdue' : 'Pending';
    if (!due.overdue) return 'Due ${DateFormat('d MMM').format(date)}';
    final days = DateTime.now().difference(date).inDays;
    return days <= 0
        ? 'Overdue'
        : 'Overdue by $days ${days == 1 ? 'day' : 'days'}';
  }

  Future<void> _remind(BuildContext context) async {
    final number = whatsappNumber(due.phone);
    final messenger = ScaffoldMessenger.of(context);
    if (number == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('No phone number saved for ${due.tenantName}')),
      );
      return;
    }
    HapticFeedback.lightImpact();
    final ok = await launchUrl(
      whatsappUri(number, reminderMessage(due, businessName)),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open WhatsApp")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = initialsOf(due.tenantName);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: BizColors.greenTint,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial.isEmpty ? '•' : initial,
              style: BizText.style(13, 700, color: BizColors.greenDeep),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  due.tenantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BizText.rowTitle,
                ),
                Text.rich(
                  TextSpan(
                    style: BizText.rowSubtitle,
                    children: [
                      TextSpan(
                        text: formatInr(due.amount),
                        style: BizText.style(13, 600, color: BizColors.ink),
                      ),
                      const TextSpan(text: '  ·  '),
                      TextSpan(
                        text: _status,
                        style: due.overdue
                            ? BizText.style(
                                13,
                                500,
                                color: const Color(0xFFC2410C),
                              )
                            : null,
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Pressable(
            scale: 0.94,
            haptic: false,
            onTap: () => _remind(context),
            semanticLabel: 'Remind ${due.tenantName} on WhatsApp',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: BizColors.mint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: BizColors.onMint,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Remind',
                    style: BizText.style(13, 700, color: BizColors.onMint),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
