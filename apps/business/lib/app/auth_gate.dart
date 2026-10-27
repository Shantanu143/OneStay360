// lib/app/auth_gate.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_services/services/auth_service.dart';
import 'package:firebase_services/services/ensure_user_document_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/providers/business_state_provider.dart';
import '../presentation/onboarding/create_business_screen.dart';
import 'session_views.dart';

/// The single owner of "who is signed in and what do they see".
///
/// Everything below it is derived from two inputs: the Firebase auth stream
/// and [BusinessStateProvider.status]. Login screens just sign in; nothing
/// navigates by hand, so a sign-in, a restart with a saved session, an invite
/// acceptance and a sign-out all land in the right place.
///
/// ```
/// auth unknown ........ loading
/// signed out .......... signedOutBuilder (login)
/// signed in:
///   preparing/loading . loading
///   ready ............. readyBuilder (the app shell)
///   no business ....... NoBusinessView (create business / sign out)
///   failed ............ SessionErrorView (retry / sign out)
/// ```
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.signedOutBuilder,
    required this.readyBuilder,
    this.loadingBuilder,
    this.noBusinessBuilder,
    this.authChanges,
    this.ensureUserDocument,
    this.signOut,
  });

  final WidgetBuilder signedOutBuilder;
  final WidgetBuilder readyBuilder;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? noBusinessBuilder;

  /// Defaults to `FirebaseAuth.authStateChanges()`.
  final Stream<User?>? authChanges;

  /// Makes sure `/users/{uid}` exists before the business is read.
  final Future<void> Function(User user)? ensureUserDocument;

  /// Defaults to signing out of Firebase and Google.
  final Future<void> Function()? signOut;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authChanges =
      widget.authChanges ?? FirebaseAuth.instance.authStateChanges();

  String? _bootedUid;
  Object? _bootstrapError;

  /// Set during a direct account switch until the previous user's state has
  /// been wiped, so their business never flashes up for the new user.
  bool _wipePending = false;

  /// Pushed screens were closed for the current access-off state.
  bool _closedForAccessOff = false;

  Future<void> _bootstrap(User user) async {
    setState(() => _bootstrapError = null);
    final provider = context.read<BusinessStateProvider>();
    try {
      final ensure = widget.ensureUserDocument ??
          (u) => EnsureUserDocumentService().ensureUserDocumentExists(u);
      await ensure(user);
      if (!mounted) return;
      await provider.loadUserData();
    } catch (e) {
      debugPrint('❌ [AuthGate] preparing the account failed: $e');
      if (mounted) setState(() => _bootstrapError = e);
    }
  }

  void _startSessionFor(User user) {
    if (_bootedUid == user.uid) return;
    final previous = _bootedUid;
    _bootedUid = user.uid;
    _wipePending = previous != null;
    // Post-frame: this is called from build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (previous != null) context.read<BusinessStateProvider>().reset();
      _wipePending = false;
      _bootstrap(user);
    });
  }

  void _endSession() {
    if (_bootedUid == null) return;
    _bootedUid = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrapError = null;
      context.read<BusinessStateProvider>().reset();
    });
  }

  Future<void> _signOut() async {
    await (widget.signOut ?? () => AuthService().signOut())();
  }

  Widget _loading(BuildContext context) =>
      (widget.loadingBuilder ?? (_) => const BrandSplash())(context);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loading(context);
        }

        final user = snapshot.data;
        if (user == null) {
          _endSession();
          return widget.signedOutBuilder(context);
        }

        _startSessionFor(user);
        return _forSession(context, user);
      },
    );
  }

  Widget _forSession(BuildContext context, User user) {
    final provider = context.watch<BusinessStateProvider>();

    if (_bootstrapError != null) {
      return SessionErrorView(
        message: "We couldn't prepare your account. Check your connection and try again.",
        onRetry: () => _bootstrap(user),
        onSignOut: _signOut,
      );
    }

    if (_wipePending) return _loading(context);

    // Once a business is loaded, background refreshes (and failed ones) must
    // not tear the app down: the user keeps working with what they have.
    if (provider.hasActiveMembership &&
        (provider.status == SessionStatus.loading ||
            provider.status == SessionStatus.error)) {
      return widget.readyBuilder(context);
    }

    if (provider.status != SessionStatus.accessOff) _closedForAccessOff = false;

    switch (provider.status) {
      case SessionStatus.ready:
        return widget.readyBuilder(context);
      case SessionStatus.noBusiness:
        return (widget.noBusinessBuilder ?? _defaultNoBusiness)(context);
      case SessionStatus.accessOff:
        // Whatever was open (a property page...) shows data they can no longer
        // use; close it so the explanation is what they see.
        if (!_closedForAccessOff) {
          _closedForAccessOff = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
          });
        }
        return AccessOffView(
          businessName: provider.businessName,
          onCheckAgain: () => _bootstrap(user),
          onSignOut: _signOut,
        );
      case SessionStatus.error:
        return SessionErrorView(
          message: provider.loadError ??
              "We couldn't load your business. Try again in a moment.",
          onRetry: () => _bootstrap(user),
          onSignOut: _signOut,
        );
      case SessionStatus.idle:
      case SessionStatus.loading:
        return _loading(context);
    }
  }

  Widget _defaultNoBusiness(BuildContext context) {
    return NoBusinessView(
      onSignOut: _signOut,
      onCreateBusiness: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateBusinessScreen()),
        );
      },
    );
  }
}
