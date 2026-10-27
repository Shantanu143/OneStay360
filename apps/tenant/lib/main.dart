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

import '../presentation/views/splash/splash_screen.dart';
import '../presentation/views/auth/auth_wrapper.dart';
import '../data/providers/tenant_state_provider.dart';
import '../presentation/view_models/explore_viewmodel.dart';
import '../presentation/theme/theme_provider.dart';
import 'services/device_token_service.dart';

/// Background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(
    '📬 Background message received (Tenant): ${message.notification?.title}',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized');

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

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // ----------------------------
    // APP CHECK INITIALIZATION
    // ----------------------------
    try {
      if (kDebugMode) {
        // Debug provider for local/dev testing (tenant app)
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
        debugPrint('✅ App Check initialized with DEBUG providers (tenant app)');

        // Force token fetch and print full token (DEBUG ONLY)
        try {
          final token = await FirebaseAppCheck.instance.getToken(true);
          if (token != null) {
            debugPrint('🔐 App Check DEBUG token (tenant): $token');
            debugPrint(
              '⚠️ Save this token to Firebase Console → App Check → Debug tokens for the tenant app.',
            );
          } else {
            debugPrint('⚠️ App Check DEBUG token returned null (tenant).');
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching App Check debug token (tenant): $e');
        }
      } else {
        // Production providers
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.deviceCheck,
          webProvider: ReCaptchaV3Provider(
            '6LfGFa8rAAAAADg7OAND4vCCo6vBZYygMwFB-eLh',
          ),
        );
        debugPrint(
          '✅ App Check initialized (Production providers) for tenant app',
        );
      }
    } catch (appCheckErr) {
      debugPrint('App Check error (tenant): $appCheckErr');
    }

    // ----------------------------
    // DEVICE TOKEN SERVICE INITIALIZATION
    // ----------------------------
    try {
      await DeviceTokenService().initialize();
      debugPrint('✅ Device Token Service initialized (tenant app)');
    } catch (e) {
      debugPrint('⚠️ Device Token Service error (tenant): $e');
    }

    // NOTE: Counter initialization removed to avoid Firestore permission deadlock.
    // Counters are accessed ONLY during business creation operations
    // which have proper authorization.
  } catch (e) {
    debugPrint('Firebase init error: $e');
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

  @override
  void initState() {
    super.initState();
    // Wire the navigator key so DeviceTokenService can push routes
    // from push notification handlers (e.g. bill_sent → BillReviewScreen).
    DeviceTokenService.navigatorKey = _navKey;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // CORE SERVICES
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<IdGenerationService>(create: (_) => IdGenerationService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<ImageService>(create: (_) => ImageService()),

        // STATE PROVIDER
        ChangeNotifierProvider<TenantStateProvider>(
          create: (_) => TenantStateProvider(),
        ),

        // REPOSITORIES
        Provider<PropertyRepository>(
          create: (context) => FirebasePropertyRepository(
            firestore: FirebaseFirestore.instance,
            idService: context.read<IdGenerationService>(),
          ),
        ),

        // VIEW MODELS
        ChangeNotifierProvider<ExploreViewModel>(
          create: (context) => ExploreViewModel(
            propertyRepository: context.read<PropertyRepository>(),
          ),
        ),

        // THEME PROVIDER
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'OneStay360 - Tenant',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.currentThemeData,
            navigatorKey: _navKey,
            navigatorObservers: [
              FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
            ],
            home: const SplashScreen(),
            routes: {'/authWrapper': (_) => const AuthWrapper()},
            builder: (context, child) {
              return GestureDetector(
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: child,
              );
            },
          );
        },
      ),
    );
  }
}
