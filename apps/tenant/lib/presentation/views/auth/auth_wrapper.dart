import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home_screen.dart';
import 'login_screen.dart';

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
          return const LoginScreen(userType: 'tenant');
        }

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
                tenantId: user.uid,
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              // User document doesn't exist yet
              debugPrint('User document does not exist');
              return TenantHomeScreen(
                tenantName: user.displayName ?? user.email?.split('@').first ?? 'Tenant',
                tenantId: user.uid,
              );
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final tenantName = userData['fullName'] ?? user.displayName ?? user.email?.split('@').first ?? 'Tenant';

            return TenantHomeScreen(
              tenantName: tenantName,
              tenantId: user.uid,
            );
          },
        );
      },
    );
  }
}
