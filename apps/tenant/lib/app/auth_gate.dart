// lib/app/auth_gate.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/tenant_session.dart';
import 'session_views.dart';

/// The single owner of "who is signed in and what do they see".
///
/// ```
/// auth unknown ....... loading
/// signed out ......... signedOutBuilder (login)
/// signed in:
///   preparing ........ loading (bootstrap creates users/{uid} + tenant id)
///   loading session .. loading
///   ready ............ readyBuilder (the tab shell)
///   failed ........... SessionErrorView (retry / sign out)
/// ```
///
/// Login screens only sign in; nothing navigates by hand.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.signedOutBuilder,
    required this.readyBuilder,
    required this.bootstrap,
    required this.signOut,
    this.loadingBuilder,
    this.authChanges,
  });

  final WidgetBuilder signedOutBuilder;
  final WidgetBuilder readyBuilder;
  final WidgetBuilder? loadingBuilder;

  /// Makes sure the account documents exist (first sign in).
  final Future<void> Function(User user) bootstrap;
  final Future<void> Function() signOut;

  /// Defaults to `FirebaseAuth.authStateChanges()`.
  final Stream<User?>? authChanges;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authChanges = widget.authChanges ?? FirebaseAuth.instance.authStateChanges();

  String? _bootedUid;
  bool _preparing = false;
  Object? _bootError;

  Future<void> _prepare(User user) async {
    setState(() {
      _preparing = true;
      _bootError = null;
    });
    try {
      await widget.bootstrap(user);
      if (!mounted) return;
      context.read<TenantSession>().start(user.uid);
    } catch (e) {
      debugPrint('❌ [AuthGate] preparing the account failed: $e');
      if (mounted) setState(() => _bootError = e);
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  void _startFor(User user) {
    if (_bootedUid == user.uid) return;
    final switched = _bootedUid != null;
    _bootedUid = user.uid;
    _preparing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (switched) context.read<TenantSession>().reset();
      _prepare(user);
    });
  }

  void _end() {
    if (_bootedUid == null) return;
    _bootedUid = null;
    _bootError = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TenantSession>().reset();
    });
  }

  Widget _loading(BuildContext context) => (widget.loadingBuilder ?? (_) => const BrandSplash())(context);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _loading(context);
        final user = snapshot.data;
        if (user == null) {
          _end();
          return widget.signedOutBuilder(context);
        }
        _startFor(user);
        return _forUser(context, user);
      },
    );
  }

  Widget _forUser(BuildContext context, User user) {
    if (_bootError != null) {
      return SessionErrorView(
        message: "We couldn't prepare your account. Check your connection and try again.",
        onRetry: () => _prepare(user),
        onSignOut: widget.signOut,
      );
    }
    final session = context.watch<TenantSession>();
    if (_preparing || session.uid != user.uid || session.phase != SessionPhase.ready) {
      return _loading(context);
    }
    return widget.readyBuilder(context);
  }
}
