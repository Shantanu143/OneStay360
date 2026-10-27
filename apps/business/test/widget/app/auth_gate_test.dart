import 'dart:async';

import 'package:business/app/auth_gate.dart';
import 'package:business/data/providers/business_state_provider.dart';
import 'package:business/models/business_membership_model.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/services/business_membership_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeMembership implements BusinessMembershipService {
  Object? failure;
  BusinessMembership? membership = BusinessMembership(
    id: 'u1',
    businessId: 'BUS1',
    uid: 'u1',
    role: 'owner',
    status: 'active',
    name: 'Rajesh',
    email: 'r@x.in',
    phone: '',
  );

  @override
  Future<BusinessMembership?> getActiveMembership(
    String uid,
    String businessId,
  ) async {
    if (failure != null) throw failure!;
    return membership;
  }

  @override
  Future<bool> isActiveMember(String uid, String businessId) async =>
      membership != null;

  /// Lets a test change someone's membership while they are signed in.
  final changes = StreamController<BusinessMembership?>.broadcast();

  @override
  Stream<BusinessMembership?> streamActiveMembership(
    String uid,
    String businessId,
  ) => changes.stream;
}

void main() {
  late StreamController<User?> auth;
  late FakeFirebaseFirestore firestore;
  late _FakeMembership membership;
  late BusinessStateProvider provider;
  late MockUser user;
  late int ensureCalls;
  late int signOuts;

  setUp(() async {
    auth = StreamController<User?>.broadcast();
    firestore = FakeFirebaseFirestore();
    membership = _FakeMembership();
    user = MockUser(uid: 'u1', email: 'r@x.in');
    provider = BusinessStateProvider(
      membershipService: membership,
      auth: MockFirebaseAuth(signedIn: true, mockUser: user),
      firestore: firestore,
      membershipRetryDelay: Duration.zero,
    );
    ensureCalls = 0;
    signOuts = 0;
    await firestore.collection('users').doc('u1').set({
      'fullName': 'Rajesh Sharma',
      'businessName': 'Apex Living',
      'businessId': 'BUS1',
    });
  });

  tearDown(() => auth.close());

  Widget app({Widget Function(BuildContext)? noBusiness}) {
    return ChangeNotifierProvider<BusinessStateProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: BizTheme.light(),
        home: AuthGate(
          authChanges: auth.stream,
          ensureUserDocument: (_) async => ensureCalls++,
          signOut: () async => signOuts++,
          loadingBuilder: (_) => const Scaffold(body: Text('loading')),
          signedOutBuilder: (_) => const Scaffold(body: Text('login')),
          readyBuilder: (_) => const Scaffold(body: Text('shell')),
          noBusinessBuilder: noBusiness,
        ),
      ),
    );
  }

  Future<void> signIn(WidgetTester tester) async {
    auth.add(user);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('shows loading until the auth state is known', (tester) async {
    await tester.pumpWidget(app());

    expect(find.text('loading'), findsOneWidget);
  });

  testWidgets('shows login when signed out', (tester) async {
    await tester.pumpWidget(app());
    auth.add(null);
    await tester.pump();

    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('signs in straight to the shell for a valid membership', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await signIn(tester);

    expect(find.text('shell'), findsOneWidget);
    expect(provider.businessId, 'BUS1');
    expect(ensureCalls, 1);
  });

  testWidgets('shows the no-business screen only when there is no business', (
    tester,
  ) async {
    membership.membership = null;
    await tester.pumpWidget(app());
    await signIn(tester);

    expect(find.text('No active business'), findsOneWidget);
    expect(find.text('Create business'), findsOneWidget);
    expect(find.text('shell'), findsNothing);
  });

  testWidgets('someone whose access was turned off is told so, not offered a new business', (tester) async {
    membership.membership = null;
    await firestore.doc('businesses/BUS1/members/u1').set({'role': 'manager', 'status': 'disabled'});
    await tester.pumpWidget(app());
    await signIn(tester);

    expect(find.text('Your access is off'), findsOneWidget);
    expect(find.textContaining('Apex Living'), findsOneWidget);
    expect(find.text('Create business'), findsNothing);
    expect(find.text('shell'), findsNothing);
  });

  testWidgets('being turned off while working closes whatever was open and says why', (tester) async {
    await tester.pumpWidget(app());
    await signIn(tester);
    expect(find.text('shell'), findsOneWidget);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('a property page'))));
    await tester.pumpAndSettle();
    expect(find.text('a property page'), findsOneWidget);

    membership.changes.add(null);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('a property page'), findsNothing);
    expect(find.text('Your access is off'), findsOneWidget);
  });

  testWidgets('"Check again" lets them in once the owner turns access back on', (tester) async {
    membership.membership = null;
    await firestore.doc('businesses/BUS1/members/u1').set({'role': 'manager', 'status': 'disabled'});
    await tester.pumpWidget(app());
    await signIn(tester);

    membership.membership = BusinessMembership(
      id: 'u1', businessId: 'BUS1', uid: 'u1', role: 'manager', status: 'active', name: 'P', email: '', phone: '');
    await firestore.doc('businesses/BUS1/members/u1').update({'status': 'active'});
    await tester.tap(find.text('Check again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('shell'), findsOneWidget);
  });

  testWidgets('the access-off screen can sign out', (tester) async {
    membership.membership = null;
    await firestore.doc('businesses/BUS1/members/u1').set({'role': 'manager', 'status': 'disabled'});
    await tester.pumpWidget(app());
    await signIn(tester);

    await tester.tap(find.text('Sign out'));
    await tester.pump();

    expect(signOuts, 1);
  });

  testWidgets('a load failure shows an error with retry, not "no business"', (
    tester,
  ) async {
    membership.failure = FirebaseException(
      plugin: 'firestore',
      code: 'unavailable',
    );
    await tester.pumpWidget(app());
    await signIn(tester);

    expect(find.text('No active business'), findsNothing);
    expect(find.text("Couldn't load your business"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    membership.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('shell'), findsOneWidget);
  });

  testWidgets('a failure while preparing the account also offers retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider<BusinessStateProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: BizTheme.light(),
          home: AuthGate(
            authChanges: auth.stream,
            ensureUserDocument: (_) async {
              attempts++;
              if (attempts == 1) throw Exception('boom');
            },
            signOut: () async {},
            loadingBuilder: (_) => const Scaffold(body: Text('loading')),
            signedOutBuilder: (_) => const Scaffold(body: Text('login')),
            readyBuilder: (_) => const Scaffold(body: Text('shell')),
          ),
        ),
      ),
    );
    await signIn(tester);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('shell'), findsOneWidget);
    expect(attempts, 2);
  });

  testWidgets('the error screen can sign the user out', (tester) async {
    membership.failure = Exception('down');
    await tester.pumpWidget(app());
    await signIn(tester);

    await tester.tap(find.text('Sign out'));
    await tester.pump();

    expect(signOuts, 1);
  });

  testWidgets('prepares the account once per sign-in, not once per rebuild', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await signIn(tester);

    provider.updatePendingRequestsCount(3);
    await tester.pump();
    provider.updatePendingRequestsCount(4);
    await tester.pump();

    expect(ensureCalls, 1);
  });

  testWidgets('signing out returns to login and wipes the session', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await signIn(tester);
    expect(find.text('shell'), findsOneWidget);

    auth.add(null);
    await tester.pump();
    await tester.pump();

    expect(find.text('login'), findsOneWidget);
    expect(provider.businessId, isNull);
    expect(provider.fullName, isEmpty);
    expect(provider.status, SessionStatus.idle);
  });

  testWidgets('a refresh in the background does not tear down the shell', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await signIn(tester);
    expect(find.text('shell'), findsOneWidget);

    final refresh = provider.loadUserData(); // status -> loading
    await tester.pump();
    expect(
      find.text('shell'),
      findsOneWidget,
      reason: 'no splash flash mid-refresh',
    );
    await refresh;
    await tester.pump();
    expect(find.text('shell'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the user in the app', (tester) async {
    await tester.pumpWidget(app());
    await signIn(tester);

    membership.failure = Exception('offline');
    await provider.loadUserData();
    await tester.pump();

    expect(provider.status, SessionStatus.error);
    expect(find.text('shell'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a second user never sees the first user\'s business', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await signIn(tester);
    expect(provider.businessId, 'BUS1');

    auth.add(null);
    await tester.pump();
    await tester.pump();

    // Next user has no business.
    membership.membership = null;
    await signIn(tester);

    expect(find.text('No active business'), findsOneWidget);
    expect(provider.businessId, isNull);
    expect(ensureCalls, 2);
  });
}
