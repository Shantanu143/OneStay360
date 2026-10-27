// lib/presentation/property_detail/tabs/overview_tab.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:models/business/property/property_model.dart';

import '../../design/components/biz_banner.dart';
import '../../design/components/biz_chips.dart';
import '../../design/components/biz_header.dart';
import '../../design/tokens.dart';
import '../../views/home/home_format.dart';
import '../../views/properties/property_card.dart' show PropertyImageBuilder;
import '../property_detail_actions.dart';
import '../property_detail_models.dart';
import '../property_detail_viewmodel.dart';
import '../../design/components/biz_info.dart';
import 'detail_common.dart';

/// Occupancy, subscription notice, and everything about the property itself.
class OverviewTab extends StatelessWidget {
  const OverviewTab({
    super.key,
    required this.vm,
    required this.actions,
    required this.onActivate,
    required this.onOpenPayments,
    this.imageBuilder,
  });

  final PropertyDetailViewModel vm;
  final PropertyDetailActions actions;
  final VoidCallback onActivate;
  final VoidCallback onOpenPayments;
  final PropertyImageBuilder? imageBuilder;

  @override
  Widget build(BuildContext context) {
    final p = vm.property!;
    return detailSliver([
      if ((p.images ?? const []).isNotEmpty) ...[
        _Photos(urls: p.images!, imageBuilder: imageBuilder),
        gap(),
      ],
      _OccupancyHero(stats: vm.stats),
      ..._notice(p),
      gap(),
      _AboutCard(property: p, actions: actions),
      gap(),
      _PricingCard(property: p),
      gap(),
      _AmenitiesCard(property: p),
      gap(),
      _RulesCard(property: p),
      gap(),
      _ContactCard(property: p, actions: actions),
    ]);
  }

  List<Widget> _notice(Property p) {
    final billing = vm.billingStatus;
    final String? message;
    final BizTone tone;
    final VoidCallback? onTap;
    if (billing.canActivate) {
      message = 'Activate this property to start adding tenants.';
      tone = BizTone.warning;
      onTap = onActivate;
    } else if (p.billingStatus == 'suspended') {
      message = 'Service suspended — pay now to restore this property.';
      tone = BizTone.danger;
      onTap = onOpenPayments;
    } else if (p.billingStatus == 'past_due') {
      message = 'Overdue — pay now to keep this property running.';
      tone = BizTone.warning;
      onTap = onOpenPayments;
    } else if (billing.canPay) {
      message = "Payment due — settle this month's invoice.";
      tone = BizTone.warning;
      onTap = onOpenPayments;
    } else {
      return const [];
    }
    return [gap(), BizBanner(message: message, tone: tone, onTap: onTap)];
  }
}

class _Photos extends StatefulWidget {
  const _Photos({required this.urls, this.imageBuilder});

  final List<String> urls;
  final PropertyImageBuilder? imageBuilder;

  @override
  State<_Photos> createState() => _PhotosState();
}

class _PhotosState extends State<_Photos> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final build = widget.imageBuilder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(BizRadius.hero),
      child: SizedBox(
        height: 188,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => build != null
                  ? build(context, widget.urls[i])
                  : CachedNetworkImage(
                      imageUrl: widget.urls[i],
                      fit: BoxFit.cover,
                      memCacheWidth: 900,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (_, __) => const ColoredBox(color: BizColors.photo),
                      errorWidget: (_, __, ___) => const ColoredBox(color: BizColors.photo),
                    ),
            ),
            if (widget.urls.length > 1)
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: BizColors.ink.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${_page + 1}/${widget.urls.length}',
                    style: BizText.style(13, 700, color: Colors.white, height: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OccupancyHero extends StatelessWidget {
  const _OccupancyHero({required this.stats});

  final PropertyStats stats;

  @override
  Widget build(BuildContext context) {
    final hasBeds = stats.totalBeds > 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BizColors.card,
        borderRadius: BorderRadius.circular(BizRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Occupancy', style: BizText.cardLabel),
          const SizedBox(height: 6),
          Text(formatPercent(stats.occupancy), style: BizText.heroAmount),
          const SizedBox(height: 4),
          Text(
            hasBeds
                ? '${stats.occupiedBeds} of ${stats.totalBeds} beds filled'
                : 'No beds set up yet',
            style: BizText.heroCaption,
          ),
          const SizedBox(height: 14),
          BizProgressBar(fraction: stats.occupancy, onDark: true),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(flex: 3, child: _HeroTile(label: 'Rooms', value: '${stats.totalRooms}')),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: _HeroTile(label: 'Free beds', value: '${stats.vacantBeds}')),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _HeroTile(
                  label: 'Monthly rent',
                  value: formatInr(stats.expectedMonthlyRent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: BizColors.cardTile,
        borderRadius: BorderRadius.circular(BizRadius.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, softWrap: false, style: BizText.tileLabel),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: BizText.tileValue),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.property, required this.actions});

  final Property property;
  final PropertyDetailActions actions;

  @override
  Widget build(BuildContext context) {
    final p = property;
    final place = [p.city, p.pincode].where((s) => s.trim().isNotEmpty).join(' ');
    final maps = p.googleMapsLink.trim();
    return BizInfoCard(
      title: 'About',
      children: [
        if (p.description.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text(p.description.trim(), style: BizText.body.copyWith(height: 1.4)),
          ),
        if (p.address.trim().isNotEmpty) BizInfoRow('Address', p.address.trim()),
        if (place.isNotEmpty) BizInfoRow('City', place),
        if (p.landmarks.trim().isNotEmpty) BizInfoRow('Landmarks', p.landmarks.trim()),
        BizInfoRow('Floors', '${p.numberOfFloors}'),
        if (maps.isNotEmpty) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () {
                final uri = Uri.tryParse(maps);
                if (uri != null) actions.openUrl(context, uri);
              },
              child: Text('Open in Maps', style: BizText.link),
            ),
          ),
        ],
      ],
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final pr = property.pricing;
    final rows = <Widget>[];
    if (pr.sharing.isNotEmpty) {
      for (final e in pr.sharing) {
        final parts = [
          if (e.nonAc != null) 'Non-AC ${formatInr(e.nonAc!)}',
          if (e.ac != null) 'AC ${formatInr(e.ac!)}',
        ];
        if (parts.isNotEmpty) rows.add(BizInfoRow('${e.sharing}-sharing', parts.join(' · ')));
      }
    } else {
      if (pr.single > 0) rows.add(BizInfoRow('Single', formatInr(pr.single)));
      if (pr.double > 0) rows.add(BizInfoRow('Double', formatInr(pr.double)));
      if (pr.triple > 0) rows.add(BizInfoRow('Triple', formatInr(pr.triple)));
    }
    if (pr.securityDeposit > 0) rows.add(BizInfoRow('Deposit', formatInr(pr.securityDeposit)));
    if (pr.oneTimeMaintenance > 0) {
      rows.add(BizInfoRow('Maintenance', '${formatInr(pr.oneTimeMaintenance)} one-time'));
    }
    return BizInfoCard(
      title: 'Rent per bed',
      children: rows.isEmpty
          ? [Text('No rent set yet.', style: BizText.rowSubtitle)]
          : rows,
    );
  }
}

class _AmenitiesCard extends StatelessWidget {
  const _AmenitiesCard({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final a = property.amenities;
    final items = <(String, IconData)>[
      if (a.wifi) ('WiFi', Icons.wifi_rounded),
      if (a.ac) ('AC', Icons.ac_unit_rounded),
      if (a.laundry) ('Laundry', Icons.local_laundry_service_outlined),
      if (a.foodIncluded) ('Food included', Icons.restaurant_outlined),
      if (a.parking) ('Parking', Icons.local_parking_rounded),
      if (a.geyser) ('Geyser', Icons.hot_tub_outlined),
      if (a.powerBackup) ('Power backup', Icons.bolt_rounded),
      if (a.cctv) ('CCTV', Icons.videocam_outlined),
      if (a.housekeeping) ('Housekeeping', Icons.cleaning_services_outlined),
    ];
    return BizInfoCard(
      title: 'Amenities',
      children: [
        const SizedBox(height: 4),
        if (items.isEmpty)
          Text('No amenities listed.', style: BizText.rowSubtitle)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final i in items) BizTag(i.$1, icon: i.$2)],
          ),
      ],
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final r = property.rules;
    String yn(bool v) => v ? 'Yes' : 'No';
    return BizInfoCard(
      title: 'House rules',
      children: [
        if (r.genderAllowed.trim().isNotEmpty) BizInfoRow('Residents', r.genderAllowed),
        BizInfoRow('Notice period', '${r.noticePeriodDays} days'),
        BizInfoRow('Curfew', yn(r.curfew)),
        BizInfoRow('Visitors', yn(r.visitorsAllowed)),
        BizInfoRow('Smoking', yn(r.smokingAllowed)),
        BizInfoRow('Alcohol', yn(r.alcoholAllowed)),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.property, required this.actions});

  final Property property;
  final PropertyDetailActions actions;

  @override
  Widget build(BuildContext context) {
    final p = property;
    final phone = p.businessPhone.trim();
    return BizInfoCard(
      title: 'Managed by',
      children: [
        if (p.businessName.trim().isNotEmpty) BizInfoRow('Business', p.businessName.trim()),
        if (phone.isNotEmpty)
          BizInfoRow(
            'Phone',
            phone,
            trailing: BizRoundButton(
              icon: Icons.call_rounded,
              iconSize: 18,
              size: 36,
              tooltip: 'Call ${p.businessName.trim().isEmpty ? 'owner' : p.businessName.trim()}',
              onTap: () => actions.call(context, phone),
            ),
          ),
        if (p.businessName.trim().isEmpty && phone.isEmpty)
          Text('No contact details yet.', style: BizText.rowSubtitle),
      ],
    );
  }
}
