import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/app/account_actions.dart';
import 'package:tenant/app/tenant_app.dart';
import 'package:tenant/presentation/auth/auth_actions.dart';
import 'package:tenant/presentation/common/device_actions.dart';

import 'fakes.dart';

/// Records what the app asked the phone to do.
class FakeDevice extends DeviceActions {
  FakeDevice() : super();

  final opened = <Uri>[];
  final shared = <String>[];
  final copied = <String>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }

  @override
  Future<void> share(String text, {String? subject}) async => shared.add(text);

  @override
  Future<void> copy(String text) async => copied.add(text);
}

class FakeAccount implements AccountActions {
  int signOuts = 0;
  int deletes = 0;

  @override
  Future<void> signOut() async => signOuts++;

  @override
  Future<void> deleteAccount() async => deletes++;
}

/// The real app, signed in as `u1`, on [backend]. Seed the backend first.
class Harness {
  Harness(this.backend);

  final FakeBackend backend;
  final device = FakeDevice();
  final account = FakeAccount();
  final auth = StreamController<User?>.broadcast();
  final signIn = FakeSignIn();

  Future<void> pump(WidgetTester tester, {bool signedIn = true}) async {
    await tester.pumpWidget(TenantApp(
      backend: backend,
      bootstrap: (_) async {},
      account: account,
      device: device,
      authChanges: auth.stream,
      analytics: false,
      signIn: signIn,
    ));
    auth.add(signedIn ? MockUser(uid: 'u1', email: 'asha@example.test') : null);
    await settle(tester);
  }

  /// Pumps ~2s of frames so streams deliver and entrances finish. (Not
  /// pumpAndSettle: loading skeletons pulse forever.)
  static Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

/// A taller phone so whole pages fit.
void useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 1100 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

class FakeSignIn implements AuthActions {
  final calls = <String>[];

  @override
  Future<void> signInWithEmail(String email, String password) async => calls.add('signIn:$email');

  @override
  Future<void> signUpWithEmail(String email, String password) async => calls.add('signUp:$email');

  @override
  Future<bool> signInWithGoogle() async {
    calls.add('google');
    return true;
  }

  @override
  Future<void> sendPasswordReset(String email) async => calls.add('reset:$email');
}
