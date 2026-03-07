import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../home_screen.dart';
import 'login_screen.dart';
import '../../../services/device_token_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  /// Register device token for push notifications when user is authenticated
  Future<void> _registerDeviceTokenForUser() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await DeviceTokenService().registerDeviceToken(token);
      }
    } catch (e) {
      debugPrint('Error registering device token after auth: $e');
    }
  }

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
          return const LoginScreen(userType: 'tenant');
        }

        // User is logged in - register device token for push notifications
        _registerDeviceTokenForUser();

        // User is logged in - show tenant home
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

            // Handle errors and show home anyway
            if (userSnapshot.hasError) {
              debugPrint('Firestore error: ${userSnapshot.error}');
              return TenantHomeScreen(
                tenantName: user.displayName ?? user.email?.split('@').first ?? 'Tenant',
                tenantId: null, // No tenant yet
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              // User document doesn't exist yet
              debugPrint('User document does not exist');
              return TenantHomeScreen(
                tenantName: user.displayName ?? user.email?.split('@').first ?? 'Tenant',
                tenantId: null, // No tenant yet
              );
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final tenantName = userData['fullName'] ?? user.displayName ?? user.email?.split('@').first ?? 'Tenant';
            // Use the actual tenantId from the user document (like TEN0000003), not the user.uid
            final actualTenantId = userData['tenantId']?.toString();

            return TenantHomeScreen(
              tenantName: tenantName,
              tenantId: actualTenantId, // This is the Firestore tenant document ID
            );
          },
        );
      },
    );
  }
}
