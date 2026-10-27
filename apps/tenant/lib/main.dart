import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_services/services/emulator_config.dart';
import 'package:firebase_services/services/firestore_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/tenant_app.dart';
import 'data/firestore_sources.dart';
import 'firebase_options.dart';
import 'services/device_token_service.dart';

/// Background message handler (must be top-level).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// First sign-in: creates `users/{uid}` and the tenant id (TEN…), keeping the
/// phone number so an owner's invitation to that number can be matched.
Future<void> bootstrapTenant(User user) => FirestoreService().initializeUser(user, 'tenant');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Opt-in local backend: --dart-define=USE_EMULATOR=true
    await connectToFirebaseEmulatorIfEnabled();
    if (kUseFirebaseEmulator) {
      // Keep local runs out of production crash and analytics reports.
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
    }

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    try {
      if (kDebugMode) {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
        final token = await FirebaseAppCheck.instance.getToken(true);
        debugPrint('🔐 App Check DEBUG token (tenant): $token');
        debugPrint('⚠️ Register it in Firebase Console → App Check → Debug tokens for the tenant app.');
      } else {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.deviceCheck,
          webProvider: ReCaptchaV3Provider('6LfGFa8rAAAAADg7OAND4vCCo6vBZYygMwFB-eLh'),
        );
      }
    } catch (e) {
      debugPrint('⚠️ App Check (tenant): $e');
    }

    await DeviceTokenService().initialize();
  } catch (e) {
    debugPrint('Firebase init error (tenant): $e');
  }

  runApp(TenantApp(
    backend: FirestoreTenantBackend(),
    bootstrap: bootstrapTenant,
    push: DeviceTokenService(),
  ));
}
