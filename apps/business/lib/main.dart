import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_services/services/auth_service.dart';
import 'package:firebase_services/services/firestore_service.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:firebase_services/services/image_service.dart';
import 'package:firebase_services/services/id_generation_service.dart';
import 'package:firebase_services/services/emulator_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app/actions.dart';
import 'app/app_routes.dart';
import 'app/auth_gate.dart';
import 'app/business_shell.dart';
import 'app/deep_links.dart';
import 'app/session_actions.dart';
import 'services/device_token_service.dart';
import 'services/team_invitation_service.dart';
import 'data/providers/business_state_provider.dart';
import 'data/providers/business_notifications_provider.dart';
import 'presentation/design/theme.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/views/properties/properties_tab.dart';
import 'app/refresh_signals.dart';
import 'presentation/views/tenants/add_tenant_wizard.dart';
import 'presentation/team/team_screen.dart';
import 'presentation/reports/reports_tab.dart';
import 'presentation/views/home_screen.dart';
import 'presentation/maintenance/firestore_maintenance_source.dart';
import 'presentation/maintenance/maintenance_source.dart';

// Background message handler - must be top-level or static
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📬 Background message received: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up background message handler before Firebase initialization
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Opt-in local backend: --dart-define=USE_EMULATOR=true
    await connectToFirebaseEmulatorIfEnabled();
    if (kUseFirebaseEmulator) {
      // Keep local runs out of production crash and analytics reports.
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
    }

    // Pass uncaught Flutter framework errors to Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    // Pass uncaught asynchronous errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    debugPrint('Firebase initialized successfully for project: onestay360-1');

    // Initialize Firebase App Check
    try {
      if (kDebugMode) {
        // Debug providers for local/dev testing
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
        debugPrint('✅ App Check initialized with DEBUG providers (business app)');

        // Force token fetch and print full token (DEBUG ONLY)
        try {
          final token = await FirebaseAppCheck.instance.getToken(true);
          if (token != null) {
            // Print full token in debug — remove this in production.
            debugPrint('🔐 App Check DEBUG token (business): $token');
            debugPrint('⚠️ Save this token to Firebase Console → App Check → Debug tokens for the business app.');
          } else {
            debugPrint('⚠️ App Check DEBUG token returned null (business).');
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching App Check debug token (business): $e');
        }
      } else {
        // Production providers
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.deviceCheck,
          webProvider: ReCaptchaV3Provider('6LfGFa8rAAAAADg7OAND4vCCo6vBZYygMwFB-eLh'),
        );
        debugPrint('✅ App Check initialized (Production providers) for business app');
      }
    } catch (e) {
      debugPrint('⚠️ App Check initialization error (business): $e');
    }

    // NOTE: Counter initialization removed to avoid Firestore permission deadlock.
    // Counters are accessed ONLY during CreateBusinessService.createBusiness()
    // which has proper authorization.
  } catch (e) {
    debugPrint('Firebase initialization error (business): $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MyAppShell();
  }
}

class _MyAppShell extends StatefulWidget {
  const _MyAppShell();

  @override
  State<_MyAppShell> createState() => _MyAppShellState();
}

class _MyAppShellState extends State<_MyAppShell> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  final BusinessStateProvider _business = BusinessStateProvider();

  late final DeepLinkCoordinator _links = DeepLinkCoordinator(
    navigatorKey: _navKey,
    routeFor: (link) => AppRoutes.forLink(link, businessId: () => _business.businessId),
  );

  late final DeviceTokenService _push = DeviceTokenService(
    gateway: FirebasePushGateway(),
    authChanges: FirebaseAuth.instance.authStateChanges(),
    firestore: FirebaseFirestore.instance,
    onLink: _links.handle,
  );

  final RefreshSignals _signals = RefreshSignals();

  late final SessionActions _session = SessionActions(
    deactivatePushToken: _push.deactivateCurrentToken,
    signOut: () => AuthService().signOut(),
  );

  StreamSubscription<Uri?>? _linkSub;

  @override
  void initState() {
    super.initState();
    _push.start();
    _setupAppLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) => _links.navigatorReady());
  }

  Future<void> _setupAppLinks() async {
    try {
      final appLinks = AppLinks();

      // The link that cold-started the app, then links while it runs. The
      // coordinator decides when it is safe to open them.
      _handleUri(await appLinks.getInitialLink());
      _linkSub = appLinks.uriLinkStream.listen(_handleUri, onError: (Object err) {
        debugPrint('Deep link error: $err');
      });
    } catch (e) {
      debugPrint('App links setup failed: $e');
    }
  }

  void _handleUri(Uri? uri) {
    if (uri == null) return;
    final link = AppLink.fromUri(uri);
    if (link != null) _links.handle(link);
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _push.dispose();
    _business.dispose();
    _signals.dispose();
    super.dispose();
  }

  Widget _pageFor(BuildContext context, ShellTab tab) {
    switch (tab) {
      case ShellTab.home:
        return const HomeTab();
      case ShellTab.properties:
        return const PropertiesTab();
      case ShellTab.tenants:
        return const AddTenantWizard();
      case ShellTab.team:
        return const TeamScreen(showBack: false);
      case ShellTab.reports:
        return const ReportsTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core services
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<IdGenerationService>(create: (_) => IdGenerationService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<ImageService>(create: (_) => ImageService()),
        Provider<TeamInvitationService>(create: (_) => TeamInvitationService()),
        Provider<DeepLinkCoordinator>.value(value: _links),
        Provider<SessionActions>.value(value: _session),
        Provider<RefreshSignals>.value(value: _signals),
        Provider<MaintenanceSource>(create: (_) => FirestoreMaintenanceSource()),

        // State
        ChangeNotifierProvider<BusinessStateProvider>.value(value: _business),
        ChangeNotifierProxyProvider<BusinessStateProvider, BusinessNotificationsProvider>(
          create: (_) => BusinessNotificationsProvider(),
          update: (_, businessState, notificationsProvider) {
            final provider = notificationsProvider ?? BusinessNotificationsProvider();
            provider.updateBusiness(businessState.businessId);
            return provider;
          },
        ),

        // Repositories
        Provider<PropertyRepository>(
          create: (context) => FirebasePropertyRepository(
            firestore: FirebaseFirestore.instance,
            idService: context.read<IdGenerationService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'OneStay360 - Business',
        debugShowCheckedModeBanner: false,
        theme: BizTheme.light(),
        navigatorKey: _navKey,
        navigatorObservers: [
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
        ],
        home: AuthGate(
          signedOutBuilder: (_) => const LoginScreen(),
          readyBuilder: (_) => BusinessShell(
            pageBuilder: _pageFor,
            onQuickAdd: (context, shell) async {
              await showQuickAdd(context, shell);
              _signals.propertiesChanged();
            },
            onHomeFab: showQuickAdd,
          ),
        ),
        onGenerateRoute: AppRoutes.onGenerateRoute,
        builder: (context, child) {
          return GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child,
          );
        },
      ),
    );
  }
}
