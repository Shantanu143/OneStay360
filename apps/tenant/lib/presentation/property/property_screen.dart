// lib/presentation/property/property_screen.dart
import 'package:flutter/material.dart';
import 'package:models/business/property/property_model.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../data/sources.dart';
import '../../data/tenant_session.dart';
import '../common/device_actions.dart';
import '../common/format.dart';
import '../design/components/app_button.dart';
import '../design/components/app_card.dart';
import '../design/components/app_chips.dart';
import '../design/components/app_header.dart';
import '../design/components/app_states.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../explore/property_card.dart';
import '../explore/property_facts.dart';
import '../home/activity_feed.dart';
import 'join_sheet.dart';

/// A PG's page: photos, prices, amenities, rules, the owner, and the
/// "Request to join" button.
class PropertyScreen extends StatefulWidget {
  const PropertyScreen({super.key, required this.propertyId, this.preview});

  final String propertyId;

  /// What the list already knows, shown while the full copy loads.
  final Property? preview;

  @override
  State<PropertyScreen> createState() => _PropertyScreenState();
}

class _PropertyScreenState extends State<PropertyScreen> {
  Property? _property;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _property = widget.preview;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await context.read<TenantBackend>().loadProperty(
            widget.propertyId,
            businessId: widget.preview?.businessId,
          );
      if (!mounted) return;
      setState(() {
        _property = p ?? _property;
        if (p == null && _property == null) _error = 'This PG is no longer listed.';
      });
    } catch (e) {
      if (mounted && _property == null) setState(() => _error = "Couldn't load this PG. Check your connection.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _share(Property p) {
    final text = [
      p.name,
      if (p.address.isNotEmpty) p.address,
      if (minPriceOf(p) > 0) '${priceLabelOf(p)} a month',
      'Found on OneStay360',
    ].join('\n');
    DeviceActions.of(context).share(text, subject: p.name);
  }

  @override
  Widget build(BuildContext context) {
    final p = _property;
    if (p == null) {
      return Scaffold(
        backgroundColor: AppColors.page,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppRoundButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    iconSize: 18,
                    tooltip: 'Back',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : AppErrorState(message: _error ?? 'Not found', onRetry: _load),
              ),
            ],
          ),
        ),
      );
    }

    final session = context.watch<TenantSession>();
    final saved = session.isFavorite(p.id ?? '');
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.page,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            edgeOffset: top,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: PhotoCarousel(images: p.images ?? const [], height: 300 + top, heroTag: 'photo-${p.id}'),
                ),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.page,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hero)),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 140),
                      child: EntranceFade(child: _Details(property: p)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                AppRoundButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  iconSize: 18,
                  tooltip: 'Back',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                AppRoundButton(icon: Icons.ios_share_rounded, tooltip: 'Share', onTap: () => _share(p)),
                const SizedBox(width: 10),
                SaveButton(
                  saved: saved,
                  onTap: () {
                    final uid = session.uid;
                    if (uid == null || p.id == null) return;
                    context.read<TenantBackend>().setFavorite(uid, p.id!, !saved);
                  },
                ),
              ],
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _JoinBar(property: p)),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final p = property;
    final options = priceOptions(p);
    final amenities = amenitiesOf(p);
    final rules = p.rules;
    final location = [p.address, p.city].where((s) => s.trim().isNotEmpty).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, style: AppText.pushedTitle),
              const SizedBox(height: 4),
              Text(location.isEmpty ? p.city : location, style: AppText.rowSubtitle.copyWith(fontSize: 14)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (p.rating.count > 0)
                    AppStatusPill('★ ${p.rating.average.toStringAsFixed(1)} (${p.rating.count})', tone: AppTone.warning, dot: false),
                  AppStatusPill(genderLabelOf(p), tone: AppTone.info, dot: false),
                  if (p.totals.availableBeds > 0)
                    AppStatusPill('${p.totals.availableBeds} beds free', tone: AppTone.success)
                  else
                    const AppStatusPill('Full right now', tone: AppTone.neutral),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (options.isNotEmpty)
          _Section(
            title: 'Rent',
            child: Column(
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  if (i > 0) const Divider(height: 20),
                  Row(
                    children: [
                      Icon(options[i].sharing == 1 ? Icons.person_rounded : Icons.group_rounded,
                          color: AppColors.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${options[i].sharingLabel}${options[i].ac ? ' · AC' : ''}', style: AppText.bodyStrong),
                      ),
                      Text('${formatInr(options[i].price)}/mo', style: AppText.style(16, 700)),
                    ],
                  ),
                ],
                if (p.pricing.securityDeposit > 0 || p.pricing.oneTimeMaintenance > 0) ...[
                  const Divider(height: 24),
                  if (p.pricing.securityDeposit > 0)
                    _Line('Security deposit', formatInr(p.pricing.securityDeposit)),
                  if (p.pricing.oneTimeMaintenance > 0)
                    _Line('One-time maintenance', formatInr(p.pricing.oneTimeMaintenance)),
                ],
              ],
            ),
          ),
        if (p.description.trim().isNotEmpty)
          _Section(title: 'About', child: Text(p.description.trim(), style: AppText.body.copyWith(height: 1.45))),
        if (amenities.isNotEmpty)
          _Section(
            title: 'Amenities',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (key, label) in amenities)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.page, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(amenityIcon(key), size: 17, color: AppColors.green),
                        const SizedBox(width: 6),
                        Text(label, style: AppText.style(14, 600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (p.foodPlan != null && p.foodPlan!.plan.values.any((v) => v == true))
          _Section(
            title: 'Food',
            child: Text(
              [
                for (final meal in const ['breakfast', 'lunch', 'dinner'])
                  if (p.foodPlan!.plan[meal] == true) '${meal[0].toUpperCase()}${meal.substring(1)}',
              ].join(' · ') +
                  (p.foodPlan!.notes.isEmpty ? '' : '\n${p.foodPlan!.notes}'),
              style: AppText.body.copyWith(height: 1.45),
            ),
          ),
        _Section(
          title: 'House rules',
          child: Column(
            children: [
              _Rule('Smoking', rules.smokingAllowed),
              _Rule('Alcohol', rules.alcoholAllowed),
              _Rule('Visitors', rules.visitorsAllowed),
              _Line('Curfew', rules.curfew ? 'Yes' : 'No curfew'),
              _Line('Notice period', '${rules.noticePeriodDays} days'),
            ],
          ),
        ),
        _Section(
          title: 'Owner',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(p.businessName.isEmpty ? 'PG owner' : p.businessName, style: AppText.cardTitle),
              if (location.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(location, style: AppText.rowSubtitle),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  if (p.businessPhone.isNotEmpty) ...[
                    Expanded(
                      child: AppButton(
                        label: 'Call',
                        icon: Icons.call_rounded,
                        kind: AppButtonKind.tonal,
                        size: AppButtonSize.compact,
                        onPressed: () => dialPhone(context, p.businessPhone),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        label: 'WhatsApp',
                        icon: Icons.chat_rounded,
                        kind: AppButtonKind.tonal,
                        size: AppButtonSize.compact,
                        onPressed: () => openWhatsApp(context, p.businessPhone, message: 'Hi, I found ${p.name} on OneStay360. Is a bed available?'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: AppButton(
                      label: 'Map',
                      icon: Icons.map_rounded,
                      kind: AppButtonKind.tonal,
                      size: AppButtonSize.compact,
                      onPressed: () => p.googleMapsLink.isNotEmpty
                          ? openExternal(context, Uri.parse(p.googleMapsLink))
                          : openMaps(context, '${p.name}, $location'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

IconData amenityIcon(String key) => switch (key) {
      'wifi' => Icons.wifi_rounded,
      'ac' => Icons.ac_unit_rounded,
      'foodIncluded' || 'meals' => Icons.restaurant_rounded,
      'laundry' => Icons.local_laundry_service_rounded,
      'housekeeping' => Icons.cleaning_services_rounded,
      'geyser' || 'hotWater' => Icons.hot_tub_rounded,
      'powerBackup' => Icons.bolt_rounded,
      'parking' => Icons.local_parking_rounded,
      'cctv' || 'security' => Icons.videocam_rounded,
      'gym' => Icons.fitness_center_rounded,
      _ => Icons.check_circle_outline_rounded,
    };

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Text(title, style: AppText.cardTitle), const SizedBox(height: 12), child],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.body.copyWith(color: AppColors.inkSoft))),
          Text(value, style: AppText.bodyStrong),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.label, this.allowed);

  final String label;
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.body.copyWith(color: AppColors.inkSoft))),
          Icon(allowed ? Icons.check_circle_rounded : Icons.do_not_disturb_on_rounded,
              size: 18, color: allowed ? AppColors.green : AppColors.chevron),
          const SizedBox(width: 6),
          Text(allowed ? 'Allowed' : 'Not allowed', style: AppText.bodyStrong),
        ],
      ),
    );
  }
}

class _JoinBar extends StatelessWidget {
  const _JoinBar({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TenantSession>();
    final activity = context.watch<ActivityFeed>();
    final p = property;
    final livesHere = session.stay?.propertyId == p.id;
    final livesElsewhere = session.hasStay && !livesHere;
    final pending = activity.requests.where((r) => r.propertyId == p.id && r.stage.isOpen).firstOrNull;
    final inset = MediaQuery.viewPaddingOf(context).bottom;

    final (String label, VoidCallback? action, String? note) = livesHere
        ? ('You live here', null, null)
        : pending != null
            ? ('Track your request', () => openRequest(context, pending.id), 'Request sent · ${pending.stage.label}')
            : livesElsewhere
                ? ('Request to join', null, 'Move out of your current PG before joining another.')
                : ('Request to join', () => showJoinSheet(context, p), null);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 16, 12 + inset),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(priceLabelOf(p), style: AppText.style(18, 700, letterSpacing: -0.3)),
                Text(note ?? (minPriceOf(p) > 0 ? 'per month' : 'Ask the owner'),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppButton(label: label, expand: false, onPressed: action),
        ],
      ),
    );
  }
}
