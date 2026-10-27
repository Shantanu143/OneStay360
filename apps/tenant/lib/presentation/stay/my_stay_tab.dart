// lib/presentation/stay/my_stay_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/tenant_shell.dart';
import '../../data/models.dart';
import '../common/device_actions.dart';
import '../common/format.dart';
import '../common/widgets.dart';
import '../design/components/app_button.dart';
import '../design/components/app_card.dart';
import '../design/components/app_chips.dart';
import '../design/components/app_list_row.dart';
import '../design/components/app_scaffold.dart';
import '../design/components/app_states.dart';
import '../design/components/floating_nav_bar.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../home/activity_feed.dart';
import '../home/home_cards.dart';
import '../property/property_screen.dart' show amenityIcon;
import 'stay_feed.dart';

const _amenityLabels = {
  'wifi': 'Wi-Fi',
  'ac': 'AC',
  'foodIncluded': 'Meals',
  'meals': 'Meals',
  'laundry': 'Laundry',
  'housekeeping': 'Housekeeping',
  'geyser': 'Hot water',
  'hotWater': 'Hot water',
  'powerBackup': 'Power backup',
  'parking': 'Parking',
  'cctv': 'CCTV',
  'security': 'Security',
  'gym': 'Gym',
};

/// Everything about where the tenant lives: room, rent, the owner, requests.
class MyStayTab extends StatelessWidget {
  const MyStayTab({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<StayFeed>();
    final activity = context.watch<ActivityFeed>();
    final stay = feed.stay;
    final now = (clock ?? DateTime.now)();
    final bottom = FloatingNavBar.heightFor(context) + 12;

    if (stay == null) {
      final request = activity.activeRequest;
      return AppScrollPage(
        title: 'My stay',
        bottomInset: bottom,
        slivers: [
          if (request != null)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: EntranceFade(child: JourneyCard(request: request))),
            )
          else
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: AppEmptyState(
                  icon: Icons.bed_outlined,
                  title: 'No stay yet',
                  message: 'When you join a PG, your room, rent and requests show up here.',
                  actionLabel: 'Find a PG',
                  onAction: () => context.read<ShellController>().goTo(ShellTab.explore),
                ),
              ),
            ),
        ],
      );
    }

    final property = feed.property;
    final room = feed.room;
    final next = feed.nextBillingDate;
    var i = 0;
    Widget reveal(Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: EntranceFade(delay: Duration(milliseconds: 60 * i++), child: child),
        );

    return AppScrollPage(
      eyebrow: stay.roomLabel,
      title: stay.propertyName.isEmpty ? 'My stay' : stay.propertyName,
      bottomInset: bottom,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              reveal(StayHeroCard(feed: feed, now: now)),
              reveal(AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Your room', style: AppText.cardTitle),
                    const SizedBox(height: 12),
                    FactGrid(facts: [
                      FactTile(label: 'Room', value: stay.roomNumber.isEmpty ? '—' : stay.roomNumber, icon: Icons.meeting_room_rounded),
                      FactTile(label: 'Bed', value: stay.bedNumber.isEmpty ? '—' : stay.bedNumber, icon: Icons.bed_rounded),
                      FactTile(
                        label: 'Sharing',
                        value: [room?.sharingLabel, if (room?.hasAC == true) 'AC'].whereType<String>().join(' · ').ifEmpty('—'),
                        icon: Icons.group_rounded,
                      ),
                      FactTile(label: 'Monthly rent', value: formatInr(stay.monthlyRent), icon: Icons.currency_rupee_rounded),
                      FactTile(
                        label: 'Rent is due',
                        value: stay.billingDay == null ? '—' : 'On the ${ordinalDay(stay.billingDay!)}',
                        icon: Icons.event_repeat_rounded,
                      ),
                      FactTile(
                        label: 'Since',
                        value: stay.checkInDate == null ? '—' : formatDay(stay.checkInDate!),
                        icon: Icons.login_rounded,
                      ),
                    ]),
                    if (next != null) ...[
                      const SizedBox(height: 12),
                      Text('Next rent: ${formatDay(next)}', style: AppText.caption),
                    ],
                  ],
                ),
              )),
              reveal(AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    AppListRow(
                      flat: true,
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFF8E5CF7),
                      title: 'Payment history',
                      subtitle: feed.pendingPayments.isEmpty
                          ? '${feed.payments.length} ${feed.payments.length == 1 ? 'payment' : 'payments'}'
                          : '${feed.pendingPayments.length} being confirmed',
                      onTap: () => openPaymentHistory(context),
                    ),
                    const Divider(indent: 64),
                    AppListRow(
                      flat: true,
                      icon: Icons.handyman_rounded,
                      color: AppColors.orange,
                      title: 'Maintenance requests',
                      subtitle: activity.activeMaintenance.isEmpty
                          ? 'Report anything that needs fixing'
                          : '${activity.activeMaintenance.length} open',
                      trailing: activity.activeMaintenance.isEmpty
                          ? null
                          : AppStatusPill('${activity.activeMaintenance.length}', tone: AppTone.warning, dot: false),
                      onTap: () => openMaintenance(context),
                    ),
                  ],
                ),
              )),
              reveal(AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Your owner', style: AppText.cardTitle),
                    if ((property?.ownerName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(property!.ownerName, style: AppText.rowSubtitle),
                    ],
                    if ((property?.location ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(property!.location, style: AppText.rowSubtitle),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Call',
                            icon: Icons.call_rounded,
                            kind: AppButtonKind.tonal,
                            size: AppButtonSize.compact,
                            onPressed: (property?.phone ?? '').isEmpty ? null : () => dialPhone(context, property!.phone),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: 'WhatsApp',
                            icon: Icons.chat_rounded,
                            kind: AppButtonKind.tonal,
                            size: AppButtonSize.compact,
                            onPressed: (property?.phone ?? '').isEmpty
                                ? null
                                : () => openWhatsApp(context, property!.phone,
                                    message: 'Hi, this is your tenant in ${stay.roomLabel} at ${stay.propertyName}.'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: 'Map',
                            icon: Icons.map_rounded,
                            kind: AppButtonKind.tonal,
                            size: AppButtonSize.compact,
                            onPressed: () => openMaps(context, '${stay.propertyName}, ${property?.location ?? ''}'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
              if ((property?.amenities ?? const []).isNotEmpty)
                reveal(AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Amenities', style: AppText.cardTitle),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final key in property!.amenities)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: AppColors.page, borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(amenityIcon(key), size: 17, color: AppColors.green),
                                  const SizedBox(width: 6),
                                  Text(_amenityLabels[key] ?? key, style: AppText.style(14, 600)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                )),
              reveal(AppButton(
                label: 'View PG page',
                kind: AppButtonKind.ghost,
                size: AppButtonSize.medium,
                onPressed: () => openProperty(context, stay.propertyId),
              )),
            ]),
          ),
        ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

/// Short for a payment's state.
(String, AppTone) paymentStatus(RentPayment p) => switch (p.state) {
      PaymentState.paid => ('Paid', AppTone.success),
      PaymentState.pending => ('Being confirmed', AppTone.warning),
      PaymentState.rejected => ('Sent back', AppTone.danger),
    };
