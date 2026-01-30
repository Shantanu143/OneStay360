import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:firebase_services/services/ensure_user_document_service.dart';
import '../home_screen.dart';
import 'login_screen.dart';
import '../../../data/providers/business_state_provider.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          // User not logged in - show login screen
          return const LoginScreen(userType: 'business');
        }

        // User is logged in - ensure document exists and load business state
        return FutureBuilder<void>(
          future: _initializeUserSession(context, user),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              debugPrint('Error initializing user session: ${snapshot.error}');
              // Still show home screen even if there's an error
            }

            final businessState = context.read<BusinessStateProvider>();
            final businessId = businessState.businessId ?? user.uid;
            
            return BusinessHomeScreen(businessId: businessId);
          },
        );
      },
    );
  }

  /// Initialize user session: ensure document exists and load business state
  Future<void> _initializeUserSession(BuildContext context, User user) async {
    try {
      print('📝 [AuthWrapper] Step 1: Ensuring user document exists for ${user.uid}');
      // Ensure user document exists
      await EnsureUserDocumentService().ensureUserDocumentExists(user);
      print('✅ [AuthWrapper] Step 1: User document ensured');

      // Load business state
      print('📝 [AuthWrapper] Step 2: Loading business state for ${user.uid}');
      final businessState = context.read<BusinessStateProvider>();
      await businessState.loadUserData();
      print('✅ [AuthWrapper] Step 2: Business state loaded. businessId=${businessState.businessId}');
    } catch (e) {
      print('❌ [AuthWrapper] Error initializing user session: $e');
      rethrow;
    }
  }
}

