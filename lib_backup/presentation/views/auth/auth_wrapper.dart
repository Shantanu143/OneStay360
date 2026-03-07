import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onestay360/presentation/views/auth/role_selection_screen.dart';
import 'package:onestay360/presentation/views/auth/profile_setup_screen.dart';
import 'package:onestay360/presentation/views/tenant/home_screen.dart';
import 'package:onestay360/presentation/views/business/home_screen.dart';

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

        // Handle errors in the auth stream
        if (snapshot.hasError) {
          debugPrint('Auth stream error: ${snapshot.error}');
          return _buildErrorScreen(context, 'Authentication error. Please restart the app.');
        }

        final user = snapshot.data;

        if (user == null) {
          // User not logged in - show role selection
          debugPrint('No user found, showing role selection');
          return const RoleSelectionScreen();
        }

        // User is logged in - check profile completion
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 10), onTimeout: () {
            throw TimeoutException('Firestore request timed out');
          }),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Handle Firestore errors
            if (userSnapshot.hasError) {
              debugPrint('Firestore error: ${userSnapshot.error}');
              return _handleFirestoreError(context, user);
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              // User document doesn't exist - treat as incomplete profile
              debugPrint('User document does not exist, showing role selection');
              return const RoleSelectionScreen();
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final isProfileComplete = userData['profileComplete'] ?? false;
            final userType = userData['userType'] ?? 'tenant';

            debugPrint('User profile complete: $isProfileComplete, type: $userType');

            // Always route tenant to Home; show banner there if incomplete
            if (userType == 'tenant') {
              final fallbackName = userData['fullName'] ??
                  (user.displayName?.isNotEmpty == true
                      ? user.displayName
                      : (user.email != null ? user.email!.split('@').first : 'Tenant'));
              return TenantHomeScreen(
                tenantName: fallbackName ?? 'Tenant',
                tenantId: userData['tenantId'],
              );
            }

            // Business: keep existing behavior
            if (isProfileComplete) {
              final businessId = userData['businessId'] ?? '';
              return BusinessHomeScreen(businessId: businessId);
            } else {
              return ProfileSetupScreen(userType: userType);
            }
          },
        );
      },
    );
  }

  Widget _buildErrorScreen(BuildContext context, String message) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 20),
              const Text(
                'Oops! Something went wrong',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const AuthWrapper()),
                  );
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _handleFirestoreError(BuildContext context, User user) {
    debugPrint('Proceeding with default user type due to Firestore error');
    return ProfileSetupScreen(userType: 'tenant');
  }
}