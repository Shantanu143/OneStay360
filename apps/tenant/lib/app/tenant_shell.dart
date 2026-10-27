// lib/app/tenant_shell.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../presentation/design/components/floating_nav_bar.dart';
import '../presentation/design/tokens.dart';

enum ShellTab {
  home('Home', Icons.home_rounded),
  explore('Explore', Icons.search_rounded),
  stay('My stay', Icons.bed_rounded),
  profile('Profile', Icons.person_rounded);

  const ShellTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Lets any screen switch tabs (Home's "Find a PG" opens Explore) without
/// pushing a route.
class ShellController extends ChangeNotifier {
  ShellTab _current = ShellTab.home;

  ShellTab get current => _current;

  void goTo(ShellTab tab) {
    if (tab == _current) return;
    _current = tab;
    notifyListeners();
  }
}

/// The signed-in app: the floating glass nav plus one page per tab.
///
/// Tabs are built on first visit and then kept alive, so switching is instant
/// and scroll position survives. Hidden tabs have their animations paused.
class TenantShell extends StatefulWidget {
  const TenantShell({super.key, required this.pageBuilder, this.controller});

  final Widget Function(BuildContext context, ShellTab tab) pageBuilder;

  /// Supply one to drive the shell from outside (push notifications).
  final ShellController? controller;

  @override
  State<TenantShell> createState() => _TenantShellState();
}

class _TenantShellState extends State<TenantShell> {
  late final ShellController _controller = widget.controller ?? ShellController();
  final Map<ShellTab, Widget> _pages = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_changed);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _controller.current;
    _pages.putIfAbsent(current, () => Builder(builder: (c) => widget.pageBuilder(c, current)));

    return ChangeNotifierProvider<ShellController>.value(
      value: _controller,
      child: PopScope(
        canPop: current == ShellTab.home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _controller.goTo(ShellTab.home);
        },
        child: Scaffold(
          extendBody: true,
          backgroundColor: AppColors.page,
          body: IndexedStack(
            index: current.index,
            children: [
              for (final tab in ShellTab.values)
                TickerMode(enabled: tab == current, child: _pages[tab] ?? const SizedBox.shrink()),
            ],
          ),
          bottomNavigationBar: FloatingNavBar(
            selectedIndex: current.index,
            items: [for (final tab in ShellTab.values) FloatingNavItem(icon: tab.icon, label: tab.label)],
            onSelected: (i) => _controller.goTo(ShellTab.values[i]),
          ),
        ),
      ),
    );
  }
}
