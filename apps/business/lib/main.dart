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
import 'services/device_token_service.dart';
import 'services/team_invitation_service.dart';
import '../presentation/views/splash/splash_screen.dart';
import '../presentation/views/auth/auth_wrapper.dart';
import '../data/providers/business_state_provider.dart';
import '../data/providers/business_notifications_provider.dart';
import '../presentation/view_models/payment_methods_viewmodel.dart';
import '../presentation/views/invite_landing_screen.dart';
import '../presentation/views/invite_welcome_screen.dart';
import '../presentation/views/enrollment_requests_screen.dart';

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
  AppLinks? _appLinks;
  StreamSubscription<Uri?>? _linkSub;
  String? _lastInviteId;

  @override
  void initState() {
    super.initState();
    // Set navigator key for device token service
    DeviceTokenService.navigatorKey = _navKey;
    _setupAppLinks();
    _initializeDeviceTokenService();
  }

  Future<void> _initializeDeviceTokenService() async {
    try {
      // Give auth a moment to initialize
      await Future.delayed(const Duration(milliseconds: 500));
      await DeviceTokenService().initialize();
    } catch (e) {
      debugPrint('Failed to initialize device token service: $e');
    }
  }

  Future<void> _setupAppLinks() async {
    try {
      _appLinks = AppLinks();

      // Handle the initial link when the app is cold-started from an invite.
      final initialUri = await _appLinks!.getInitialLink();
      _handleUri(initialUri);

      // Listen for links while the app is in foreground/background.
      _linkSub = _appLinks!.uriLinkStream.listen(_handleUri, onError: (err) {
        debugPrint('Deep link error: $err');
      });
    } catch (e) {
      debugPrint('App links setup failed: $e');
    }
  }

  void _handleUri(Uri? uri) {
    if (uri == null) return;
    final hostMatch = uri.host == 'app.onestay360.brandedpatil.in';
    final pathMatch = uri.path.startsWith('/invite');
    final inviteId = uri.queryParameters['inviteId'];

    if (!hostMatch || !pathMatch || inviteId == null || inviteId.isEmpty) return;

    if (_lastInviteId == inviteId) return; // prevent duplicate routing
    _lastInviteId = inviteId;

    // Push invite and clear back stack so splash/auth doesn’t override.
    _navKey.currentState?.pushNamedAndRemoveUntil(
      '/invite',
      (route) => false,
      arguments: {'inviteId': inviteId},
    );
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core Services
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<IdGenerationService>(create: (_) => IdGenerationService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<ImageService>(create: (_) => ImageService()),
        Provider<TeamInvitationService>(create: (_) => TeamInvitationService()),

        // State Providers
        ChangeNotifierProvider<BusinessStateProvider>(
          create: (_) => BusinessStateProvider(),
        ),
        ChangeNotifierProxyProvider<BusinessStateProvider, BusinessNotificationsProvider>(
          create: (_) => BusinessNotificationsProvider(),
          update: (_, businessState, notificationsProvider) {
            final provider = notificationsProvider ?? BusinessNotificationsProvider();
            provider.updateBusiness(businessState.businessId);
            return provider;
          },
        ),
        ChangeNotifierProvider<PaymentMethodsViewModel>(
          create: (_) => PaymentMethodsViewModel(),
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
        theme: _buildAppTheme(),
        navigatorKey: _navKey,
        navigatorObservers: [
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
        ],
        home: const SplashScreen(),
        routes: {
          '/authWrapper': (context) => const AuthWrapper(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/enrollment-requests') {
            final args = settings.arguments as Map<String, dynamic>?;
            final requestId = args?['requestId'] as String?;
            final propertyId = args?['propertyId'] as String?;
            return MaterialPageRoute(
              builder: (_) => EnrollmentRequestsScreen(
                initialRequestId: requestId,
                initialPropertyId: propertyId,
              ),
            );
          }
          if (settings.name == '/invite') {
            final args = settings.arguments as Map<String, dynamic>?;
            final inviteId = args?['inviteId'] as String?;
            if (inviteId != null) {
              return MaterialPageRoute(builder: (_) => InviteLandingScreen(inviteId: inviteId));
            }
          }
          if (settings.name == '/welcomeInvite') {
            final args = settings.arguments as Map<String, dynamic>?;
            final businessId = args?['businessId'] as String?;
            final role = args?['role'] as String?;
            final propertyIds = (args?['propertyIds'] as List?)?.cast<String>() ?? <String>[];
            if (businessId != null && role != null) {
              return MaterialPageRoute(
                builder: (_) => InviteWelcomeScreen(
                  businessId: businessId,
                  role: role,
                  propertyIds: propertyIds,
                ),
              );
            }
          }
          return null;
        },
        builder: (context, child) {
          return GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: child,
          );
        },
      ),
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.light,
        primary: Colors.teal.shade600,
        secondary: Colors.orange.shade600,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.teal.shade600,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.withAlpha((0.1 * 255).round()),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(fontSize: 16),
      ),
    );
  }
}
