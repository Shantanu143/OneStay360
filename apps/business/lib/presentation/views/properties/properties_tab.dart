// lib/presentation/views/properties/properties_tab.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:flutter/material.dart';
import 'package:models/business/property/property_model.dart';
import 'package:provider/provider.dart';

import '../../../app/actions.dart';
import '../../../app/refresh_signals.dart';
import '../../../data/providers/business_state_provider.dart';
import '../../../utils/permissions.dart';
import '../../design/components/biz_avatar.dart';
import '../../design/components/biz_chips.dart';
import '../../design/components/biz_dialogs.dart';
import '../../design/components/biz_header.dart';
import '../../design/components/biz_list_row.dart';
import '../../design/components/biz_scaffold.dart';
import '../../design/components/biz_search_field.dart';
import '../../design/components/biz_states.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../view_models/business_properties_viewmodel.dart';
import '../../common/active_occupancy.dart';
import '../home/home_format.dart';
import '../widgets/floating_nav_bar.dart';
import 'property_card.dart';

/// The Properties tab: search, status chips, a draft nudge and one card per
/// property. Lives in the shell, so it is built once and kept alive; it
/// reloads when another screen reports that a property changed.
class PropertiesTab extends StatefulWidget {
  const PropertiesTab({
    super.key,
    this.onOpenProperty,
    this.onEditProperty,
    this.onAddProperty,
    this.onProfile,
    this.imageBuilder,
    this.occupancyLoader,
  });

  /// Overrides for navigation (tests). Defaults push the real screens and
  /// reload the list when they come back.
  final void Function(BuildContext context, Property property)? onOpenProperty;
  final void Function(BuildContext context, Property property)? onEditProperty;
  final Future<void> Function(BuildContext context)? onAddProperty;
  final void Function(BuildContext context)? onProfile;
  final PropertyImageBuilder? imageBuilder;

  /// Counts the tenants living in each property. Defaults to Firestore; the
  /// counter stored on a property is not kept up to date.
  final Future<Map<String, int>> Function(String businessId)? occupancyLoader;

  @override
  State<PropertiesTab> createState() => _PropertiesTabState();
}

class _PropertiesTabState extends State<PropertiesTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final BusinessPropertiesViewModel _vm = BusinessPropertiesViewModel(
    propertyRepository: context.read<PropertyRepository>(),
    propertyScope: () => context.read<BusinessStateProvider>().propertyScope,
    occupancyLoader:
        widget.occupancyLoader ?? (id) => loadActiveOccupancy(FirebaseFirestore.instance, id),
  );
  late final RefreshSignals _signals = context.read<RefreshSignals>();
  String? _loadedFor;

  @override
  void initState() {
    super.initState();
    _entrance.forward();
    _signals.properties.addListener(_onPropertiesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBusiness());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
      _entrance.value = 1;
  }

  @override
  void dispose() {
    _signals.properties.removeListener(_onPropertiesChanged);
    _entrance.dispose();
    _vm.dispose();
    super.dispose();
  }

  String? get _businessId => context.read<BusinessStateProvider>().businessId;

  void _syncBusiness() {
    if (!mounted) return;
    final id = _businessId;
    if (id == null || id.isEmpty || id == _loadedFor) return;
    _loadedFor = id;
    _vm.loadProperties(id);
  }

  void _onPropertiesChanged() {
    if (mounted) _vm.refreshProperties(_businessId);
  }

  // ─── Navigation ─────────────────────────────────────────────────────────

  Future<void> _open(Property p) async {
    final custom = widget.onOpenProperty;
    if (custom != null) return custom(context, p);
    if (p.id == null)
      return showBizToast(
        context,
        "That property has no ID yet.",
        tone: BizTone.danger,
      );
    await openProperty(context, p.id!);
    _onPropertiesChanged();
  }

  Future<void> _edit(Property p) async {
    final custom = widget.onEditProperty;
    if (custom != null) return custom(context, p);
    if (p.id == null)
      return showBizToast(
        context,
        "That property has no ID yet.",
        tone: BizTone.danger,
      );
    await openEditProperty(context, p.id!);
    _onPropertiesChanged();
  }

  Future<void> _add() async {
    final custom = widget.onAddProperty;
    if (custom != null) return custom(context);
    await openAddProperty(context);
    _signals.propertiesChanged();
  }

  // ─── Sorting ────────────────────────────────────────────────────────────

  Future<void> _showSort() {
    const options = {
      PropertySortOption.updated: 'Recently updated',
      PropertySortOption.newest: 'Newest first',
      PropertySortOption.occupancy: 'Most occupied',
    };
    return showBizSheet<void>(
      context,
      title: 'Sort properties',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in options.entries)
            BizSheetOption(
              label: entry.value,
              selected: _vm.sortOption == entry.key,
              onTap: () {
                _vm.updateSortOption(entry.key);
                Navigator.of(sheetContext).pop();
              },
            ),
        ],
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  static const _chipFilters = [
    PropertyStatusFilter.all,
    PropertyStatusFilter.active,
    PropertyStatusFilter.vacant,
    PropertyStatusFilter.maintenance,
    PropertyStatusFilter.draft,
  ];

  static String _chipLabel(PropertyStatusFilter f) => switch (f) {
    PropertyStatusFilter.all => 'All',
    PropertyStatusFilter.active => 'Active',
    PropertyStatusFilter.vacant => 'Vacant',
    PropertyStatusFilter.maintenance => 'Maintenance',
    PropertyStatusFilter.draft => 'Draft',
  };

  static BizTone _toneFor(String status) => switch (status) {
    'draft' => BizTone.draft,
    'active' => BizTone.success,
    'vacant' => BizTone.warning,
    'maintenance' => BizTone.danger,
    _ => BizTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BusinessStateProvider>();
    final canEdit = BusinessPermissions.fromRole(state.role).canEditRooms;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBusiness());

    return ChangeNotifierProvider<BusinessPropertiesViewModel>.value(
      value: _vm,
      child: Consumer<BusinessPropertiesViewModel>(
        builder: (context, vm, _) => BizScrollPage(
          title: 'Properties',
          eyebrow: vm.hasLoaded ? vm.summaryLine : ' ',
          actions: [
            if (canEdit)
              BizRoundButton(
                icon: Icons.add_rounded,
                tooltip: 'Add property',
                onTap: _add,
              ),
            BizRoundButton(
              icon: Icons.swap_vert_rounded,
              tooltip: 'Sort',
              onTap: _showSort,
            ),
            BizAvatarButton(
              initials: initialsOf(
                state.fullName.isNotEmpty ? state.fullName : state.businessName,
              ),
              onTap: () => (widget.onProfile ?? openProfile)(context),
            ),
          ],
          bottomInset: FloatingNavBar.heightFor(context) + 28,
          onRefresh: () => vm.refreshProperties(state.businessId),
          slivers: _slivers(context, vm, canEdit),
        ),
      ),
    );
  }

  List<Widget> _slivers(
    BuildContext context,
    BusinessPropertiesViewModel vm,
    bool canEdit,
  ) {
    final filtering =
        vm.statusFilter != PropertyStatusFilter.all ||
        vm.searchQuery.trim().isNotEmpty;

    Widget pad(Widget sliver) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: sliver,
    );

    final header = pad(
      SliverToBoxAdapter(
        child: Column(
          children: [
            BizSearchField(
              hint: 'Name, address or city',
              onChanged: vm.updateSearchQuery,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    final chips = SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.zero,
        child: BizFilterChips(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          selectedIndex: _chipFilters.indexOf(vm.statusFilter),
          onSelected: (i) => vm.updateStatusFilter(_chipFilters[i]),
          chips: [
            for (final f in _chipFilters)
              BizChipData(
                _chipLabel(f),
                count: f == PropertyStatusFilter.all ? vm.countFor(f) : null,
              ),
          ],
        ),
      ),
    );

    final showBanner =
        vm.draftCount > 0 && vm.statusFilter != PropertyStatusFilter.draft;
    final banner = pad(
      SliverToBoxAdapter(
        child: showBanner
            ? Padding(
                padding: const EdgeInsets.only(top: 16),
                child: BizListRow(
                  icon: Icons.edit_outlined,
                  color: BizColors.orange,
                  title: vm.draftCount == 1
                      ? '1 property is still a draft'
                      : '${vm.draftCount} properties are still drafts',
                  subtitle: 'Finish setup so tenants can find it',
                  onTap: () =>
                      vm.updateStatusFilter(PropertyStatusFilter.draft),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );

    final lead = [header, chips, banner];

    if (!vm.hasLoaded) {
      return [
        ...lead,
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: BizSkeletonList(count: 2, cardHeight: 340),
          ),
        ),
      ];
    }

    if (vm.hasError && vm.properties.isEmpty) {
      return [
        pad(
          SliverFillRemaining(
            hasScrollBody: false,
            child: BizErrorState(
              title: "Couldn't load properties",
              message: 'Check your connection and try again.',
              onRetry: () => vm.refreshProperties(_businessId),
            ),
          ),
        ),
      ];
    }

    if (vm.properties.isEmpty) {
      return [
        pad(
          SliverFillRemaining(
            hasScrollBody: false,
            child: BizEmptyState(
              icon: Icons.apartment_outlined,
              title: 'No properties yet',
              message: canEdit
                  ? 'Add your first property to start filling beds.'
                  : 'No properties have been assigned to you yet. Ask the owner for access.',
              actionLabel: canEdit ? 'Add property' : null,
              onAction: canEdit ? _add : null,
            ),
          ),
        ),
      ];
    }

    final items = vm.filteredProperties;
    if (items.isEmpty) {
      return [
        ...lead,
        pad(
          SliverFillRemaining(
            hasScrollBody: false,
            child: BizEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No properties match',
              message: 'Try a different search or filter.',
              actionLabel: filtering ? 'Clear filters' : null,
              onAction: filtering
                  ? () {
                      vm.updateSearchQuery('');
                      vm.updateStatusFilter(PropertyStatusFilter.all);
                    }
                  : null,
            ),
          ),
        ),
      ];
    }

    return [
      ...lead,
      if (vm.hasError)
        pad(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: BizListRow(
                icon: Icons.refresh_rounded,
                color: BizColors.orange,
                title: "Couldn't refresh",
                subtitle: 'Showing what we had. Tap to retry.',
                onTap: () => vm.refreshProperties(_businessId),
              ),
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) {
            final p = items[i];
            final isDraft = p.status == 'draft';
            final card = PropertyCard(
              key: ValueKey(p.id),
              name: p.name,
              location: vm.locationLine(p),
              statusLabel: vm.statusLabel(p),
              statusTone: _toneFor(p.status),
              rentRange: vm.rentRange(p),
              beds: vm.bedsOf(p),
              rooms: vm.roomsOf(p),
              occupancyPercent: !isDraft && vm.bedsOf(p) > 0
                  ? (vm.getOccupancyRate(p) * 100).round()
                  : null,
              updatedAgo: vm.updatedAgo(p),
              imageUrls: p.images ?? const [],
              imageBuilder: widget.imageBuilder,
              primaryLabel: isDraft && canEdit ? 'Finish setup' : 'Manage',
              onOpen: () => _open(p),
              onEdit: canEdit ? () => _edit(p) : null,
              onPrimary: () => isDraft && canEdit ? _edit(p) : _open(p),
            );
            return i < 4
                ? Reveal(
                    animation: _entrance,
                    start: 0.1 + 0.12 * i,
                    end: (0.6 + 0.12 * i).clamp(0.0, 1.0),
                    child: card,
                  )
                : card;
          },
        ),
      ),
    ];
  }
}
