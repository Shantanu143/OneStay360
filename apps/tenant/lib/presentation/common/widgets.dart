// lib/presentation/common/widgets.dart
//
// Small pieces several tenant screens share.
import 'package:flutter/material.dart';

import '../design/components/app_button.dart';
import '../design/components/app_dialogs.dart';
import '../design/components/app_list_row.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import 'device_actions.dart';
import 'format.dart';

/// "Recent activity ........ See all".
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(title, style: AppText.sectionTitle)),
          if (action != null && onAction != null)
            Pressable(
              onTap: onAction,
              scale: 0.95,
              semanticLabel: action,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(action!, style: AppText.link),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tweens a number from 0 (then from its last value) so figures count up
/// when they arrive.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.style,
    this.format = formatInr,
    this.duration = const Duration(milliseconds: 1100),
  });

  final double value;
  final TextStyle style;
  final String Function(num) format;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? value : 0, end: value),
      duration: reduce ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), maxLines: 1, softWrap: false, style: style),
    );
  }
}

/// A horizontal track of steps with the done ones filled in: the path from
/// "Requested" to "Moved in".
class StepTrack extends StatelessWidget {
  const StepTrack({super.key, required this.steps, required this.current, this.onDark = false, this.failed = false});

  final List<String> steps;

  /// Index of the step in progress; everything before it is done.
  final int current;
  final bool onDark;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final done = onDark ? AppColors.mint : AppColors.green;
    final idle = onDark ? AppColors.dotEmptyOnDark : AppColors.track;
    final labelIdle = onDark ? AppColors.onCardMuted : AppColors.inkSoft;
    final labelOn = onDark ? Colors.white : AppColors.ink;
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              _Dot(state: i < current ? 2 : (i == current ? 1 : 0), on: failed && i == current ? AppColors.badge : done, idle: idle),
              if (i < steps.length - 1)
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: i < current ? 1 : 0),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(colors: [done, done, idle, idle], stops: [0, t, t, 1]),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < steps.length; i++)
              Expanded(
                child: Text(
                  steps[i],
                  textAlign: i == 0 ? TextAlign.left : (i == steps.length - 1 ? TextAlign.right : TextAlign.center),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.style(11.5, i <= current ? 600 : 500, color: i <= current ? labelOn : labelIdle),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.state, required this.on, required this.idle});

  /// 0 upcoming, 1 current, 2 done.
  final int state;
  final Color on;
  final Color idle;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: state == 2 ? on : Colors.transparent,
        border: Border.all(color: state == 0 ? idle : on, width: 2.4),
      ),
      child: state == 2
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : state == 1
              ? Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: on, shape: BoxShape.circle)))
              : null,
    );
  }
}

/// The ways to reach the owner: call, WhatsApp, or directions.
Future<void> showContactOwnerSheet(
  BuildContext context, {
  required String propertyName,
  required String phone,
  String? address,
}) {
  return showAppSheet<void>(
    context,
    title: 'Contact your owner',
    subtitle: propertyName,
    scrollable: false,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (phone.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              "Your owner hasn't added a phone number yet.",
              style: AppText.body.copyWith(color: AppColors.inkSoft),
            ),
          )
        else ...[
          AppListRow(
            icon: Icons.call_rounded,
            color: AppColors.green,
            title: 'Call',
            subtitle: phone,
            onTap: () {
              Navigator.of(ctx).pop();
              dialPhone(context, phone);
            },
          ),
          const SizedBox(height: 8),
          AppListRow(
            icon: Icons.chat_rounded,
            color: const Color(0xFF25D366),
            title: 'WhatsApp',
            subtitle: 'Send a message',
            onTap: () {
              Navigator.of(ctx).pop();
              openWhatsApp(context, phone, message: 'Hi, this is your tenant at $propertyName.');
            },
          ),
        ],
        if (address != null && address.isNotEmpty) ...[
          const SizedBox(height: 8),
          AppListRow(
            icon: Icons.map_rounded,
            color: AppColors.blue,
            title: 'Directions',
            subtitle: address,
            onTap: () {
              Navigator.of(ctx).pop();
              openMaps(context, address);
            },
          ),
        ],
        const SizedBox(height: 12),
        AppButton(
          label: 'Close',
          kind: AppButtonKind.tonal,
          size: AppButtonSize.medium,
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ],
    ),
  );
}

/// A label and a value stacked, for detail grids ("Room" / "101").
class FactTile extends StatelessWidget {
  const FactTile({super.key, required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.page, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.green),
            const SizedBox(height: 8),
          ],
          Text(label, style: AppText.caption),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.statValue.copyWith(fontSize: 16)),
        ],
      ),
    );
  }
}

/// Grid of two-per-row [FactTile]s.
class FactGrid extends StatelessWidget {
  const FactGrid({super.key, required this.facts});

  final List<FactTile> facts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < facts.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: facts[i]),
              const SizedBox(width: 10),
              Expanded(child: i + 1 < facts.length ? facts[i + 1] : const SizedBox.shrink()),
            ],
          ),
        ],
      ],
    );
  }
}
