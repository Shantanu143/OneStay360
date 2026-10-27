// lib/app/tenant_app.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/sources.dart';
import '../data/tenant_session.dart';
import '../presentation/auth/auth_actions.dart';
import '../presentation/auth/login_screen.dart';
import '../presentation/common/device_actions.dart';
import '../presentation/design/theme.dart';
import '../presentation/explore/explore_tab.dart';
import '../presentation/home/activity_feed.dart';
import '../presentation/home/home_tab.dart';
import '../presentation/notifications/notification_target.dart';
import '../presentation/profile/profile_tab.dart';
import '../presentation/stay/my_stay_tab.dart';
import '../presentation/stay/stay_feed.dart';
import '../services/device_token_service.dart';
import 'account_actions.dart';
import 'auth_gate.dart';
import 'routes.dart';
import 'tenant_shell.dart';

/// The whole app: providers, theme, and the auth gate.
class TenantApp extends StatefulWidget {
  const TenantApp({
    super.key,
    required this.backend,
    required this.bootstrap,
    this.account = const FirebaseAccountActions(),
    this.device = const DeviceActions(),
    this.authChanges,
    this.push,
    this.analytics = true,
    this.signIn,
  });

  final TenantBackend backend;
  final Future<void> Function(User user) bootstrap;
  final AccountActions account;
  final DeviceActions device;
  final Stream<User?>? authChanges;
  final DeviceTokenService? push;
  final bool analytics;

  /// Sign-in methods for the login screen; Firebase when null.
  final AuthActions? signIn;

  @override
  State<TenantApp> createState() => _TenantAppState();
}

class _TenantAppState extends State<TenantApp> {
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _shell = ShellController();
  late final TenantSession _session = TenantSession(source: widget.backend);

  @override
  void initState() {
    super.initState();
    final push = widget.push;
    if (push != null) {
      push.onOpened = (data) => _route(pushTarget(data));
      push.onForeground = (title, body, data) {
        final context = _navigator.currentContext;
        if (context == null) return;
        _messenger.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(body.isEmpty ? title : '$title\n$body'),
            action: pushTarget(data) is NoTarget
                ? null
                : SnackBarAction(label: 'View', textColor: Colors.white, onPressed: () => _route(pushTarget(data))),
          ));
      };
    }
  }

  void _route(NotificationTarget target) {
    final context = _navigator.currentContext;
    if (context == null || _session.phase != SessionPhase.ready) return;
    openTarget(context, target, shell: _shell);
  }

  @override
  void dispose() {
    _session.dispose();
    _shell.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TenantBackend>.value(value: widget.backend),
        Provider<AccountActions>.value(value: widget.account),
        Provider<DeviceActions>.value(value: widget.device),
        ChangeNotifierProvider<TenantSession>.value(value: _session),
        ChangeNotifierProvider<StayFeed>(create: (_) => StayFeed(session: _session, source: widget.backend)),
        ChangeNotifierProvider<ActivityFeed>(create: (_) => ActivityFeed(session: _session, backend: widget.backend)),
        ChangeNotifierProvider<ShellController>.value(value: _shell),
      ],
      child: MaterialApp(
        title: 'OneStay360',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        navigatorKey: _navigator,
        scaffoldMessengerKey: _messenger,
        navigatorObservers: [if (widget.analytics) FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)],
        builder: (context, child) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        ),
        home: AuthGate(
          authChanges: widget.authChanges,
          bootstrap: (user) async {
            await widget.bootstrap(user);
            widget.push?.registerCurrentToken();
          },
          signOut: widget.account.signOut,
          signedOutBuilder: (_) => LoginScreen(auth: widget.signIn),
          readyBuilder: (context) => _Ready(push: widget.push, shell: _shell),
        ),
      ),
    );
  }
}

class _Ready extends StatefulWidget {
  const _Ready({required this.push, required this.shell});

  final DeviceTokenService? push;
  final ShellController shell;

  @override
  State<_Ready> createState() => _ReadyState();
}

class _ReadyState extends State<_Ready> {
  @override
  void initState() {
    super.initState();
    // A new session starts on Home, whoever used the app before.
    widget.shell.goTo(ShellTab.home);
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.push?.flushPending());
  }

  @override
  Widget build(BuildContext context) {
    return TenantShell(
      controller: widget.shell,
      pageBuilder: (context, tab) => switch (tab) {
        ShellTab.home => const HomeTab(),
        ShellTab.explore => const ExploreTab(),
        ShellTab.stay => const MyStayTab(),
        ShellTab.profile => const ProfileTab(),
      },
    );
  }
}
