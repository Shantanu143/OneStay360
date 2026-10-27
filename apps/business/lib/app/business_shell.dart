// lib/app/business_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/providers/business_state_provider.dart';
import '../presentation/design/tokens.dart';
import '../presentation/views/widgets/floating_nav_bar.dart';
import '../utils/permissions.dart';
import 'deep_links.dart';

/// The main tabs. Managers and staff don't get [team] or [reports].
enum ShellTab {
  home('Home', Icons.home_outlined),
  properties('Properties', Icons.apartment_outlined),
  tenants('Tenants', Icons.people_outline),
  team('Team', Icons.group_outlined),
  reports('Reports', Icons.stacked_line_chart_outlined);

  const ShellTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Lets any tab ask the shell to switch tabs (e.g. Home's "6 beds vacant" row
/// opens Properties) without pushing a new route.
class ShellController extends ChangeNotifier {
  ShellTab _current = ShellTab.home;

  ShellTab get current => _current;

  void goTo(ShellTab tab) {
    if (tab == _current) return;
    _current = tab;
    notifyListeners();
  }
}

/// The signed-in app: the floating nav plus one persistent page per tab.
///
/// Tabs are built the first time they're visited and then kept alive, so
/// switching is instant and nothing refetches or loses scroll/form state. A
/// tab hidden by the nav has its animations paused.
class BusinessShell extends StatefulWidget {
  const BusinessShell({
    super.key,
    required this.pageBuilder,
    this.onQuickAdd,
    this.onHomeFab,
    this.onPropertiesFab,
    this.onTenantsFab,
    this.onTeamFab,
    this.onReportsFab,
  });

  /// Builds the page for [ShellTab]. Called once per tab.
  final Widget Function(BuildContext context, ShellTab tab) pageBuilder;

  /// General quick-add handler used across all tabs unless overridden.
  final Future<void> Function(BuildContext context, ShellController shell)? onQuickAdd;

  /// What the "+" does on specific tabs. The shell's [ShellController] is
  /// passed in because these run above the provider that exposes it to the tabs.
  final Future<void> Function(BuildContext context, ShellController shell)? onHomeFab;
  final Future<void> Function(BuildContext context, ShellController shell)? onPropertiesFab;
  final Future<void> Function(BuildContext context, ShellController shell)? onTenantsFab;
  final Future<void> Function(BuildContext context, ShellController shell)? onTeamFab;
  final Future<void> Function(BuildContext context, ShellController shell)? onReportsFab;

  @override
  State<BusinessShell> createState() => _BusinessShellState();
}

class _BusinessShellState extends State<BusinessShell> {
  final ShellController _controller = ShellController();
  final Map<ShellTab, Widget> _pages = {};
  DeepLinkCoordinator? _coordinator;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _coordinator?.sessionReady();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coordinator ??= context.read<DeepLinkCoordinator>();
  }

  void _onTabChanged() => setState(() {});

  @override
  void dispose() {
    _controller
      ..removeListener(_onTabChanged)
      ..dispose();
    _coordinator?.sessionEnded();
    super.dispose();
  }

  List<ShellTab> _tabsFor(String role) => role == 'owner'
      ? ShellTab.values
      : const [ShellTab.home, ShellTab.properties, ShellTab.tenants];

  Future<void> Function()? _fabFor(ShellTab tab, String role) {
    final perms = BusinessPermissions.fromRole(role);
    switch (tab) {
      case ShellTab.home:
        final onTap = widget.onHomeFab ?? widget.onQuickAdd;
        return onTap == null ? null : () => onTap(context, _controller);
      case ShellTab.properties:
        if (widget.onPropertiesFab != null) {
          if (!perms.canEditRooms) {
            final fallback = widget.onQuickAdd;
            return fallback == null ? null : () => fallback(context, _controller);
          }
          final onTap = widget.onPropertiesFab!;
          return () => onTap(context, _controller);
        }
        final onTap = widget.onQuickAdd ?? widget.onHomeFab;
        return onTap == null ? null : () => onTap(context, _controller);
      case ShellTab.tenants:
        final onTap = widget.onTenantsFab ?? widget.onQuickAdd;
        return onTap == null ? null : () => onTap(context, _controller);
      case ShellTab.team:
        final onTap = widget.onTeamFab ?? widget.onQuickAdd;
        return onTap == null ? null : () => onTap(context, _controller);
      case ShellTab.reports:
        final onTap = widget.onReportsFab ?? widget.onQuickAdd;
        return onTap == null ? null : () => onTap(context, _controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.select<BusinessStateProvider, String>((p) => p.role);
    final tabs = _tabsFor(role);

    // A demotion while on Reports sends the user home.
    var current = _controller.current;
    if (!tabs.contains(current)) current = ShellTab.home;
    final index = tabs.indexOf(current);

    // Built lazily and cached. The Builder puts the page *below* the
    // ShellController provider so tabs can `context.read<ShellController>()`.
    _pages.putIfAbsent(
      current,
      () => Builder(builder: (pageContext) => widget.pageBuilder(pageContext, current)),
    );

    return ChangeNotifierProvider<ShellController>.value(
      value: _controller,
      child: PopScope(
        canPop: current == ShellTab.home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _controller.goTo(ShellTab.home);
        },
        child: Scaffold(
          extendBody: true,
          backgroundColor: BizColors.page,
          body: IndexedStack(
            index: index,
            children: [
              for (final tab in tabs)
                TickerMode(
                  enabled: tab == current,
                  child: _pages[tab] ?? const SizedBox.shrink(),
                ),
            ],
          ),
          bottomNavigationBar: FloatingNavBar(
            selectedIndex: index,
            items: [
              for (final tab in tabs)
                FloatingNavItem(icon: tab.icon, label: tab.label),
            ],
            onSelected: (i) => _controller.goTo(tabs[i]),
            onQuickAdd: _fabFor(current, role),
          ),
        ),
      ),
    );
  }
}
