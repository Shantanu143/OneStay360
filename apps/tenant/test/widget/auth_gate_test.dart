import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tenant/app/auth_gate.dart';
import 'package:tenant/data/tenant_session.dart';

import '../support/fakes.dart';

void main() {
  late StreamController<User?> auth;
  late FakeBackend backend;
  late TenantSession session;
  late List<String> booted;
  Object? bootError;
  var signOuts = 0;

  setUp(() {
    auth = StreamController<User?>.broadcast();
    backend = FakeBackend();
    session = TenantSession(source: backend);
    booted = [];
    bootError = null;
    signOuts = 0;
  });

  tearDown(() => auth.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: session,
        child: MaterialApp(
          home: AuthGate(
            authChanges: auth.stream,
            bootstrap: (user) async {
              booted.add(user.uid);
              if (bootError != null) throw bootError!;
            },
            signOut: () async => signOuts++,
            signedOutBuilder: (_) => const Text('LOGIN'),
            readyBuilder: (_) => const Text('SHELL'),
            loadingBuilder: (_) => const Text('SPLASH'),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the splash until auth is known, then login', (tester) async {
    await pump(tester);
    expect(find.text('SPLASH'), findsOneWidget);

    auth.add(null);
    await tester.pump();
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('a signed-in tenant is prepared, loaded, then sees the app', (tester) async {
    await pump(tester);
    auth.add(MockUser(uid: 'u1'));
    await tester.pump();
    await tester.pump();

    expect(booted, ['u1']);
    expect(session.uid, 'u1');
    expect(find.text('SPLASH'), findsOneWidget, reason: 'account not loaded yet');

    backend.account.set(testAccount(tenantId: null));
    await tester.pump();
    await tester.pump();
    expect(find.text('SHELL'), findsOneWidget);
  });

  testWidgets('a failed preparation can be retried or signed out of', (tester) async {
    bootError = Exception('offline');
    await pump(tester);
    auth.add(MockUser(uid: 'u1'));
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't load your account"), findsOneWidget);

    bootError = null;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(booted, ['u1', 'u1']);

    backend.account.set(testAccount(tenantId: null));
    await tester.pump();
    await tester.pump();
    expect(find.text('SHELL'), findsOneWidget);
  });

  testWidgets('sign out from the error view', (tester) async {
    bootError = Exception('offline');
    await pump(tester);
    auth.add(MockUser(uid: 'u1'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Sign out'));
    await tester.pump();
    expect(signOuts, 1);
  });

  testWidgets('signing out clears the session', (tester) async {
    await pump(tester);
    auth.add(MockUser(uid: 'u1'));
    await tester.pump();
    await tester.pump();
    backend.account.set(testAccount(tenantId: null));
    await tester.pump();

    auth.add(null);
    await tester.pump();
    await tester.pump();

    expect(find.text('LOGIN'), findsOneWidget);
    expect(session.uid, isNull);
  });
}
