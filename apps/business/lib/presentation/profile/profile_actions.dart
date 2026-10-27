// lib/presentation/profile/profile_actions.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/session_actions.dart';
import '../../data/providers/business_state_provider.dart';
import '../common/device_actions.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_dialogs.dart';
import 'my_details_screen.dart';
import '../payment_methods/payment_methods_screen.dart';
import '../team/team_screen.dart';
import 'billing_overview_screen.dart';
import 'contact_verification.dart';
import 'kyc_screen.dart';

/// Who is signed in, as the profile shows them.
class ProfileAccount {
  const ProfileAccount({
    required this.uid,
    this.email,
    this.phone,
    this.hasPassword = false,
  });

  final String uid;
  final String? email;
  final String? phone;

  /// Signs in with an email and password (so a reset link makes sense).
  final bool hasPassword;

  bool get hasEmail => email != null && email!.isNotEmpty;
  bool get hasPhone => phone != null && phone!.isNotEmpty;

  factory ProfileAccount.fromUser(User user) => ProfileAccount(
    uid: user.uid,
    email: user.email,
    phone: user.phoneNumber,
    hasPassword: user.providerData.any((p) => p.providerId == 'password'),
  );
}

/// What the profile does outside itself. Faked in tests.
abstract class ProfileActions {
  Future<void> signOut(BuildContext context);
  Future<void> deleteAccount(BuildContext context);
  Future<void> openPrivacyPolicy(BuildContext context);
  Future<void> sendPasswordReset(String email);
  Future<void> renameBusiness(
    BuildContext context,
    String businessId,
    String name,
  );
  Future<void> addEmail(BuildContext context);
  Future<void> addPhone(BuildContext context);
  Future<void> refreshEmail(BuildContext context);
  Future<void> refreshPhone(BuildContext context);
  void openPaymentMethods(BuildContext context, String businessId);
  void openTeam(BuildContext context);
  void openBilling(BuildContext context, String businessId);
  void openKyc(BuildContext context, String businessId);
  void openMyDetails(BuildContext context, ProfileAccount account);
}

class DeviceProfileActions implements ProfileActions {
  DeviceProfileActions({this.onContactChanged});

  /// Called after the email or phone was reloaded, so the screen redraws.
  final VoidCallback? onContactChanged;

  ContactVerifier _verifier(BuildContext context) => ContactVerifier(
    isOwner: context.read<BusinessStateProvider>().role == 'owner',
    onChanged: onContactChanged,
  );

  @override
  Future<void> signOut(BuildContext context) =>
      context.read<SessionActions>().signOutAndReturnToRoot(context);

  @override
  Future<void> deleteAccount(BuildContext context) async {
    final session = context.read<SessionActions>();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await FirebaseFunctions.instance
          .httpsCallable('deleteUserAccount')
          .call<Object?>();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await session.finishAccountDeletion(context);
    } catch (e) {
      debugPrint('❌ [Profile] delete account: $e');
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showBizToast(
        context,
        "Couldn't delete your account. Try again.",
        tone: BizTone.danger,
      );
    }
  }

  @override
  Future<void> openPrivacyPolicy(BuildContext context) => openExternal(
    context,
    Uri.parse('https://onestay360.brandedpatil.in/privacy'),
  );

  @override
  Future<void> sendPasswordReset(String email) =>
      FirebaseAuth.instance.sendPasswordResetEmail(email: email);

  @override
  Future<void> renameBusiness(
    BuildContext context,
    String businessId,
    String name,
  ) async {
    final state = context.read<BusinessStateProvider>();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final fs = FirebaseFirestore.instance;
    await fs.collection('businesses').doc(businessId).update({'name': name});
    // The owner's own user document keeps a copy of the name.
    if (uid != null) {
      await fs.collection('users').doc(uid).set({
        'businessName': name,
      }, SetOptions(merge: true));
    }
    await state.loadUserData();
  }

  @override
  Future<void> addEmail(BuildContext context) =>
      _verifier(context).addEmail(context);

  @override
  Future<void> addPhone(BuildContext context) =>
      _verifier(context).addPhone(context);

  @override
  Future<void> refreshEmail(BuildContext context) =>
      _verifier(context).refreshEmail(context);

  @override
  Future<void> refreshPhone(BuildContext context) =>
      _verifier(context).refreshPhone(context);

  @override
  void openPaymentMethods(BuildContext context, String businessId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentMethodsScreen(businessId: businessId),
      ),
    );
  }

  @override
  void openTeam(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TeamScreen()));
  }

  @override
  void openBilling(BuildContext context, String businessId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BillingOverviewScreen(businessId: businessId),
      ),
    );
  }

  @override
  void openKyc(BuildContext context, String businessId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => KycScreen(businessId: businessId)),
    );
  }

  @override
  Future<void> openMyDetails(BuildContext context, ProfileAccount account) async {
    final state = context.read<BusinessStateProvider>();
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MyDetailsScreen(
          businessId: state.businessId ?? '',
          uid: account.uid,
          role: state.role,
          name: state.fullName,
          email: account.email ?? '',
          phone: account.phone ?? '',
        ),
      ),
    );
  }
}
