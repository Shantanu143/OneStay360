// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:onestay360/presentation/views/splash/splash_screen.dart';
import 'package:onestay360/presentation/views/auth/auth_wrapper.dart';
import 'package:onestay360/presentation/services/auth_service.dart';
import 'package:onestay360/presentation/services/firestore_service.dart';
import 'package:onestay360/data/repositories/property_repository.dart';
import 'package:onestay360/presentation/view_models/business/business_properties_viewmodel.dart';
import 'package:onestay360/data/services/image_service.dart';
import 'package:onestay360/data/services/id_generation_service.dart';
import 'package:onestay360/data/providers/business_state_provider.dart';
import 'package:onestay360/data/providers/tenant_state_provider.dart'; // NEW
import 'package:onestay360/presentation/view_models/tenant/explore_viewmodel.dart'; // NEW
import 'package:onestay360/presentation/view_models/tenant/pg_detail_viewmodel.dart'; // NEW

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('Firebase initialized successfully for project: onestay360-1');

    // Initialize Firebase App Check with your reCAPTCHA v3 site key
    try {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider('6LfGFa8rAAAAADg7OAND4vCCo6vBZYygMwFB-eLh'),
        androidProvider: AndroidProvider.debug, // Use debug for development
        appleProvider: AppleProvider.debug,     // Use debug for development
      );

      debugPrint('Firebase App Check initialized successfully with reCAPTCHA v3');

      // Get a debug token to verify App Check is working
      try {
        final token = await FirebaseAppCheck.instance.getToken(true);
        // In debug mode print the full debug token so it can be registered
        // on the emulator/device via adb. In release builds avoid printing
        // the full token.
        if (kDebugMode) {
          debugPrint('App Check debug token (DEV): $token');
        } else {
          debugPrint('App Check debug token: ${token != null ? "${token.substring(0, 20)}..." : "null"}');
        }
      } catch (tokenError) {
        debugPrint('Error getting App Check token: $tokenError');
      }

    } catch (appCheckError) {
      debugPrint('App Check initialization error: $appCheckError');
      debugPrint('Continuing without App Check for development');
    }

    // ✅ INITIALIZE ID GENERATION SERVICE COUNTERS
    try {
      final idService = IdGenerationService();
      await idService.initializeCounters();
      debugPrint('✅ ID Generation Service counters initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing ID Generation Service: $e');
      // Don't crash the app if counters fail to initialize
    }

  } catch (e) {
    debugPrint('Firebase initialization error: $e');
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
        ChangeNotifierProvider<TenantStateProvider>( // NEW
          create: (_) => TenantStateProvider(),
        ),

        // Repositories
        Provider<PropertyRepository>(
          create: (context) => FirebasePropertyRepository(
            firestore: FirebaseFirestore.instance,
            idService: context.read<IdGenerationService>(),
          ),
        ),

        // Business ViewModels
        Provider<BusinessPropertiesViewModel>(
          create: (context) => BusinessPropertiesViewModel(
            propertyRepository: context.read<PropertyRepository>(),
          ),
        ),

        // Tenant ViewModels - NEW
        ChangeNotifierProvider<ExploreViewModel>( // NEW
          create: (context) => ExploreViewModel(
            propertyRepository: context.read<PropertyRepository>(),
          ),
        ),
        ChangeNotifierProvider<PGDetailViewModel>( // NEW
          create: (context) => PGDetailViewModel(
            propertyRepository: context.read<PropertyRepository>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'OneStay360',
        debugShowCheckedModeBanner: false,
        theme: _buildAppTheme(),
        home: const SplashScreen(),
        routes: {
          '/authWrapper': (context) => const AuthWrapper(),
          // Removed '/addProperty' route since AddPropertyScreen now requires parameters
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