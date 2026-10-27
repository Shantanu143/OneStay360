// lib/presentation/views/home_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/actions.dart';
import '../../app/business_shell.dart';
import '../../app/refresh_signals.dart';
import '../../data/providers/business_notifications_provider.dart';
import '../../data/providers/business_state_provider.dart';
import '../design/components/biz_dialogs.dart';
import '../design/tokens.dart';
import '../view_models/business_dashboard_viewmodel.dart';
import 'home/home_dashboard_view.dart';
import 'home/home_format.dart';
import 'home/home_sheets.dart';
import 'home/needs_attention_card.dart';
import 'home/recent_activity_card.dart';

/// The Home tab. Lives inside the [BusinessShell], so it is built once and
/// kept alive; returning to it refreshes the numbers only if they're stale.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  /// How old the numbers may get before returning to the tab refreshes them.
  static const staleAfter = Duration(minutes: 1);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  /// Drives the staggered entrance of the home sections.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  late final BusinessDashboardViewModel _vm = BusinessDashboardViewModel(
    propertyRepository: context.read<PropertyRepository>(),
    propertyScope: () => context.read<BusinessStateProvider>().propertyScope,
  );
  late final ShellController _shell = context.read<ShellController>();
  late final RefreshSignals _signals = context.read<RefreshSignals>();
  String? _loadedFor;

  @override
  void initState() {
    super.initState();
    _entrance.forward();
    _shell.addListener(_onShellChanged);
    _signals.anyChanged.addListener(_onDataChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBusiness());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the OS "reduce motion" setting.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _entrance.value = 1;
    }
  }

  @override
  void dispose() {
    _shell.removeListener(_onShellChanged);
    _signals.anyChanged.removeListener(_onDataChanged);
    _entrance.dispose();
    _vm.dispose();
    super.dispose();
  }

  /// Loads the numbers for the current business (and again if it changes).
  void _syncBusiness() {
    if (!mounted) return;
    final id = context.read<BusinessStateProvider>().businessId;
    if (id == null || id.isEmpty || id == _loadedFor) return;
    _loadedFor = id;
    _vm.loadDashboardMetrics(id);
  }

  void _onDataChanged() {
    if (mounted)
      _vm.refreshMetrics(context.read<BusinessStateProvider>().businessId);
  }

  void _onShellChanged() {
    if (_shell.current != ShellTab.home || !mounted) return;
    final id = context.read<BusinessStateProvider>().businessId;
    _vm.refreshIfStale(id, maxAge: HomeTab.staleAfter);
  }

  Future<void> _sendReminders() async {
    final now = DateTime.now();
    if (_vm.rentDues.isEmpty) {
      showBizToast(
        context,
        _vm.hasCollections
            ? 'Everyone has paid for ${monthName(now)}. Nothing to remind.'
            : 'No rent invoices have been generated for ${monthName(now)} yet.',
      );
      return;
    }
    HapticFeedback.lightImpact();
    await showRemindersSheet(
      context,
      dues: _vm.rentDues,
      businessName: context.read<BusinessStateProvider>().businessName,
      monthLabel: monthName(now),
    );
  }

  List<AttentionItem> _attentionItems(
    BusinessDashboardViewModel vm,
    BusinessStateProvider state,
  ) {
    String plural(int n, String one, String many) => n == 1 ? one : many;

    final requests = state.pendingRequestsCount;
    final payments = vm.pendingPaymentsCount;
    final leases = vm.leasesEndingThisWeek;
    final vacant = vm.vacantBeds;

    return [
      if (requests > 0)
        AttentionItem(
          icon: Icons.how_to_reg_outlined,
          color: BizColors.orange,
          title:
              '$requests new enrollment ${plural(requests, 'request', 'requests')}',
          subtitle: 'Review and approve move-ins',
          onTap: () => openLatestPendingRequest(context, state.businessId),
        ),
      if (payments > 0)
        AttentionItem(
          icon: Icons.task_outlined,
          color: BizColors.orange,
          title:
              '$payments ${plural(payments, 'payment', 'payments')} to confirm',
          subtitle:
              '${formatInr(vm.pendingConfirmationAmount)} awaiting your approval',
          onTap: () => openPendingPayments(context),
        ),
      if (leases > 0)
        AttentionItem(
          icon: Icons.calendar_today_outlined,
          color: BizColors.blue,
          title:
              '$leases ${plural(leases, 'lease ends', 'leases end')} this week',
          subtitle: 'Renew or plan move-outs',
          onTap: () => _shell.goTo(ShellTab.tenants),
        ),
      if (vacant > 0)
        AttentionItem(
          icon: Icons.bed_outlined,
          color: BizColors.green,
          title: '$vacant ${plural(vacant, 'bed', 'beds')} vacant',
          subtitle: 'List them to fill faster',
          onTap: () => _shell.goTo(ShellTab.properties),
        ),
    ];
  }

  HomeDashboardData _dataFor(
    BusinessDashboardViewModel vm,
    BusinessStateProvider state,
    int unread,
  ) {
    final now = DateTime.now();
    final displayName = state.fullName.trim().isNotEmpty
        ? state.fullName
        : (FirebaseAuth.instance.currentUser?.displayName ?? '');
    final nameForInitials = displayName.trim().isNotEmpty
        ? displayName
        : state.businessName;

    return HomeDashboardData(
      loading: !vm.hasLoaded,
      error: vm.hasError && vm.hasLoaded ? vm.error : null,
      businessName: state.businessName.isNotEmpty
          ? state.businessName
          : 'Your business',
      firstName: firstNameOf(displayName),
      initials: initialsOf(nameForInitials),
      unreadCount: unread,
      collectionsTitle: '${monthName(now)} collections',
      daysLeft: daysLeftLabel(now),
      target: vm.collectionsTarget,
      collected: vm.collectionsCollected,
      pending: vm.collectionsPending,
      overdueCount: vm.overdueCount,
      collectionProgress: vm.collectionProgress,
      occupancy: vm.occupancyFraction,
      occupiedBeds: vm.occupiedBeds,
      totalBeds: vm.totalCapacity,
      properties: vm.totalProperties,
      tenants: vm.activeTenants,
      vacantBeds: vm.vacantBeds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BusinessStateProvider>();
    final unread = context.watch<BusinessNotificationsProvider>().unreadCount;
    final isOwner = state.role == 'owner';

    // A business that appears after first build (e.g. just created) loads too.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBusiness());

    return ChangeNotifierProvider<BusinessDashboardViewModel>.value(
      value: _vm,
      child: Consumer<BusinessDashboardViewModel>(
        builder: (context, vm, _) => HomeDashboardView(
          entrance: _entrance,
          data: _dataFor(vm, state, unread),
          attentionItems: _attentionItems(vm, state),
          onRefresh: () => vm.refreshMetrics(state.businessId),
          onRetry: () => vm.refreshMetrics(state.businessId),
          onBusinessTap: () => openProfile(context),
          onBellTap: () => openNotifications(context),
          onAvatarTap: () => openProfile(context),
          onSendReminders: _sendReminders,
          onAnalytics: isOwner ? () => _shell.goTo(ShellTab.reports) : null,
          footer: isOwner
              ? RecentActivitySection(businessId: state.businessId)
              : null,
        ),
      ),
    );
  }
}
