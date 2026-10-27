// lib/presentation/reports/reports_tab.dart
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/actions.dart';
import '../../app/business_shell.dart';
import '../../app/refresh_signals.dart';
import '../../data/providers/business_state_provider.dart';
import '../design/components/biz_avatar.dart';
import '../design/components/biz_banner.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_section_label.dart';
import '../design/components/biz_states.dart';
import '../views/home/home_format.dart';
import '../views/widgets/floating_nav_bar.dart';
import 'firestore_reports_source.dart';
import 'reports_models.dart';
import 'reports_source.dart';
import 'reports_viewmodel.dart';
import 'reports_widgets.dart';

/// The Reports tab: rent collected against billed, month by month, per
/// property and by how tenants pay. Owners only (the shell hides it from
/// managers and staff).
///
/// Lives in the shell, so it is built once and kept alive. It reloads when it
/// is shown again after the numbers got old, or after something changed
/// elsewhere (a payment, a tenant, a property).
class ReportsTab extends StatefulWidget {
  const ReportsTab({
    super.key,
    this.source,
    this.clock,
    this.onProfile,
    this.onOpenProperty,
  });

  /// How long the numbers stay fresh while switching between tabs.
  static const staleAfter = Duration(minutes: 2);

  /// Test hooks. Defaults read Firestore and push the real screens.
  final ReportsSource? source;
  final DateTime Function()? clock;
  final void Function(BuildContext context)? onProfile;
  final void Function(BuildContext context, String propertyId)? onOpenProperty;

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  late final ReportsViewModel _vm = ReportsViewModel(
    source: widget.source ?? _defaultSource(),
    clock: widget.clock,
  );
  RefreshSignals? _signals;
  ShellController? _shell;
  String? _loadedFor;

  ReportsSource _defaultSource() {
    final properties = context.read<PropertyRepository>();
    return FirestoreReportsSource(
      loadProperties: (businessId) async => [
        for (final p in await properties.getPropertiesByBusiness(businessId)) ReportProperty.fromProperty(p),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    // Both are absent when the tab is built on its own (tests).
    _signals = _maybe<RefreshSignals>();
    _shell = _maybe<ShellController>();
    _signals?.anyChanged.addListener(_onDataChanged);
    _shell?.addListener(_onShellChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBusiness());
  }

  T? _maybe<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void dispose() {
    _signals?.anyChanged.removeListener(_onDataChanged);
    _shell?.removeListener(_onShellChanged);
    _vm.dispose();
    super.dispose();
  }

  String? get _businessId {
    final id = _maybe<BusinessStateProvider>()?.businessId;
    return id == null || id.isEmpty ? null : id;
  }

  void _syncBusiness() {
    if (!mounted) return;
    final id = _businessId;
    if (id == null || id == _loadedFor) return;
    _loadedFor = id;
    _vm.load(id);
  }

  /// Something changed elsewhere: reload now if this tab is showing, else the
  /// next time it is.
  void _onDataChanged() {
    if (!mounted) return;
    _vm.markStale();
    if (_shell == null || _shell!.current == ShellTab.reports) _vm.refreshIfStale(ReportsTab.staleAfter);
  }

  void _onShellChanged() {
    if (_shell?.current != ShellTab.reports || !mounted) return;
    _vm.refreshIfStale(ReportsTab.staleAfter);
  }

  @override
  Widget build(BuildContext context) {
    final state = _maybe<BusinessStateProvider>();
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final r = _vm.result;
        final name = state?.fullName.isNotEmpty == true ? state!.fullName : state?.businessName ?? '';
        return BizScrollPage(
          title: 'Reports',
          eyebrow: _vm.hasLoaded && r.totalBeds > 0 ? '${r.occupiedBeds} of ${r.totalBeds} beds filled' : ' ',
          actions: [
            BizAvatarButton(
              initials: initialsOf(name),
              onTap: () => (widget.onProfile ?? (c) => openProfile(c))(context),
            ),
          ],
          bottomInset: FloatingNavBar.heightFor(context) + 28,
          onRefresh: _vm.refresh,
          slivers: _slivers(context, r),
        );
      },
    );
  }

  List<Widget> _slivers(BuildContext context, ReportResult r) {
    Widget pad(Widget child, {double top = 0}) => SliverPadding(
          padding: EdgeInsets.fromLTRB(16, top, 16, 0),
          sliver: SliverToBoxAdapter(child: child),
        );

    if (_vm.error != null) {
      return [
        pad(
          BizErrorState(message: _vm.error!, onRetry: _vm.refresh),
          top: 24,
        ),
      ];
    }
    if (!_vm.hasLoaded) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 52,
            child: _RangeChips(selected: _vm.range, onSelected: _vm.selectRange),
          ),
        ),
        pad(const BizSkeletonList(count: 2, cardHeight: 200), top: 16),
      ];
    }
    if (r.properties.isEmpty && !r.hasInvoices) {
      return [
        pad(
          const BizEmptyState(
            icon: Icons.stacked_line_chart_rounded,
            title: 'No reports yet',
            message: 'Add a property and its tenants to see rent collection and occupancy here.',
          ),
          top: 24,
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: SizedBox(
          height: 52,
          child: _RangeChips(selected: _vm.range, onSelected: _vm.selectRange),
        ),
      ),
      if (_vm.refreshFailed)
        pad(const BizBanner(message: "Couldn't refresh. Showing the numbers from earlier.", tone: BizTone.warning), top: 12),
      pad(ReportsHero(rangeLabel: _vm.range.label, summary: r.summary), top: 16),
      if (r.hasInvoices && r.months.length > 1) pad(MonthlyCollections(key: ValueKey(_vm.range), months: r.months), top: 16),
      if (r.properties.isNotEmpty) ...[
        pad(const BizSectionLabel('By property'), top: 22),
        for (final p in r.properties)
          pad(
            PropertyReportCard(
              report: p,
              onTap: p.id.isEmpty ? null : () => (widget.onOpenProperty ?? (c, id) => openProperty(c, id))(context, p.id),
            ),
            top: 10,
          ),
      ],
      if (r.modes.isNotEmpty) ...[
        pad(const BizSectionLabel('How tenants paid'), top: 22),
        pad(PayModesCard(modes: r.modes)),
      ],
      if (r.overdue.isNotEmpty) ...[
        pad(const BizSectionLabel('Owing the most'), top: 22),
        pad(OverdueCard(tenants: r.overdue)),
      ],
    ];
  }
}

class _RangeChips extends StatelessWidget {
  const _RangeChips({required this.selected, required this.onSelected});

  final ReportRange selected;
  final ValueChanged<ReportRange> onSelected;

  @override
  Widget build(BuildContext context) {
    return BizFilterChips(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      selectedIndex: ReportRange.values.indexOf(selected),
      onSelected: (i) => onSelected(ReportRange.values[i]),
      chips: [for (final r in ReportRange.values) BizChipData(r.label)],
    );
  }
}
