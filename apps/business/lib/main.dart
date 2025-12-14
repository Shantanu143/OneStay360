import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_services/services/auth_service.dart';
import 'package:firebase_services/services/firestore_service.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:firebase_services/services/image_service.dart';
import 'package:firebase_services/services/id_generation_service.dart';
import '../presentation/views/splash/splash_screen.dart';
import '../presentation/views/auth/auth_wrapper.dart';
import '../data/providers/business_state_provider.dart';
import '../presentation/view_models/payment_methods_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

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

    // Initialize ID counters (as before)
    try {
      final idService = IdGenerationService();
      await idService.initializeCounters();
      debugPrint('✅ ID Generation Service counters initialized successfully (business)');
    } catch (e) {
      debugPrint('ℹ️ Counter initialization deferred (business): $e');
    }
  } catch (e) {
    debugPrint('Firebase initialization error (business): $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core Services
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<IdGenerationService>(create: (_) => IdGenerationService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<ImageService>(create: (_) => ImageService()),

        // State Providers
        ChangeNotifierProvider<BusinessStateProvider>(
          create: (_) => BusinessStateProvider(),
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
        home: const SplashScreen(),
        routes: {
          '/authWrapper': (context) => const AuthWrapper(),
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
