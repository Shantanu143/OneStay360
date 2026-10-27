import 'package:business/app/session_actions.dart';
import 'package:business/data/providers/business_state_provider.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/profile/profile_actions.dart';
import 'package:business/presentation/profile/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/session_fixtures.dart';

class FakeProfileActions implements ProfileActions {
  final calls = <String>[];
  Object? resetFailure;

  @override
  Future<void> signOut(BuildContext context) async => calls.add('signOut');

  @override
  Future<void> deleteAccount(BuildContext context) async => calls.add('deleteAccount');

  @override
  Future<void> openPrivacyPolicy(BuildContext context) async => calls.add('privacy');

  @override
  Future<void> sendPasswordReset(String email) async {
    if (resetFailure != null) throw resetFailure!;
    calls.add('reset:$email');
  }

  @override
  Future<void> renameBusiness(BuildContext context, String businessId, String name) async =>
      calls.add('rename:$businessId:$name');

  @override
  Future<void> addEmail(BuildContext context) async => calls.add('addEmail');

  @override
  Future<void> addPhone(BuildContext context) async => calls.add('addPhone');

  @override
  Future<void> refreshEmail(BuildContext context) async => calls.add('refreshEmail');

  @override
  Future<void> refreshPhone(BuildContext context) async => calls.add('refreshPhone');

  @override
  void openPaymentMethods(BuildContext context, String businessId) => calls.add('payments:$businessId');

  @override
  void openTeam(BuildContext context) => calls.add('team');

  @override
  void openBilling(BuildContext context, String businessId) => calls.add('billing:$businessId');

  @override
  void openKyc(BuildContext context, String businessId) => calls.add('kyc:$businessId');

  @override
  void openMyDetails(BuildContext context, ProfileAccount account) => calls.add('myDetails');
}

void main() {
  late FakeProfileActions actions;

  setUp(() => actions = FakeProfileActions());

  Future<void> open(
    WidgetTester tester, {
    String role = 'owner',
    ProfileAccount? account,
    bool profileComplete = false,
  }) async {
    tester.view.physicalSize = const Size(400, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fs = FakeFirebaseFirestore();
    final provider = await readyProvider(role: role, firestore: fs);
    if (profileComplete) {
      await fs.collection('users').doc('u1').set({'profileCompleted': true}, SetOptions(merge: true));
      await provider.loadUserData();
    }
    var signedOut = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BusinessStateProvider>.value(value: provider),
          Provider<SessionActions>.value(
            value: SessionActions(deactivatePushToken: () async {}, signOut: () async => signedOut++),
          ),
        ],
        child: MaterialApp(
          theme: BizTheme.light(),
          home: ProfileScreen(
            actions: actions,
            account: account ??
                const ProfileAccount(
                  uid: 'u1',
                  email: 'owner@onestay360.test',
                  phone: '+919000000001',
                  hasPassword: true,
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('what each role sees', () {
    testWidgets('an owner sees the whole profile', (tester) async {
      await open(tester);

      expect(find.text('Apex Living'), findsWidgets);
      expect(find.text('Owner'), findsOneWidget);
      for (final row in [
        'KYC & documents',
        'Payment methods',
        'Team & access',
        'Billing & subscription',
        'Change password',
        'Privacy policy',
        'Sign out',
        'Delete account',
      ]) {
        await tester.scrollUntilVisible(find.text(row), 200, scrollable: find.byType(Scrollable).first);
        expect(find.text(row), findsOneWidget, reason: row);
      }
    });

    testWidgets('a manager has no owner-only rows', (tester) async {
      await open(tester, role: 'manager');

      expect(find.text('Manager'), findsOneWidget);
      expect(find.text('KYC & documents'), findsNothing);
      expect(find.text('Payment methods'), findsNothing);
      expect(find.text('Team & access'), findsNothing);
      expect(find.text('Billing & subscription'), findsNothing);
      await tester.scrollUntilVisible(find.text('Sign out'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('a staff member is the same', (tester) async {
      await open(tester, role: 'staff');

      expect(find.text('Staff'), findsOneWidget);
      expect(find.text('Payment methods'), findsNothing);
    });

    testWidgets('an incomplete profile is pointed out', (tester) async {
      await open(tester);

      expect(find.textContaining('Complete your profile'), findsOneWidget);
    });

    testWidgets('a complete profile has no nag', (tester) async {
      await open(tester, profileComplete: true);

      expect(find.textContaining('Complete your profile'), findsNothing);
    });
  });

  group('account', () {
    testWidgets('shows email and phone with a way to refresh them', (tester) async {
      await open(tester);

      expect(find.text('owner@onestay360.test'), findsOneWidget);
      expect(find.text('+919000000001'), findsOneWidget);

      await tester.tap(find.byTooltip('Refresh email'));
      await tester.tap(find.byTooltip('Refresh phone'));
      expect(actions.calls, ['refreshEmail', 'refreshPhone']);
    });

    testWidgets('offers to add what is missing', (tester) async {
      await open(tester, account: const ProfileAccount(uid: 'u1', hasPassword: false));

      expect(find.text('Not added'), findsNWidgets(2));
      await tester.tap(find.text('Add email'));
      await tester.tap(find.text('Add phone'));
      expect(actions.calls, ['addEmail', 'addPhone']);
    });

    testWidgets('"Edit my details" opens the member profile', (tester) async {
      await open(tester);

      await tester.tap(find.text('Edit my details'));
      expect(actions.calls, ['myDetails']);
    });
  });

  group('business', () {
    testWidgets('the owner can rename it', (tester) async {
      await open(tester);

      await tester.tap(find.byTooltip('Rename business'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('business-name')), '  Sunrise Stays ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['rename:BUS1:Sunrise Stays']);
    });

    testWidgets('an empty name is refused', (tester) async {
      await open(tester);

      await tester.tap(find.byTooltip('Rename business'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('business-name')), ' ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a name for your business.'), findsOneWidget);
      expect(actions.calls, isEmpty);
    });

    testWidgets('only the owner sees the rename button', (tester) async {
      await open(tester, role: 'manager');

      expect(find.byTooltip('Rename business'), findsNothing);
    });
  });

  group('manage', () {
    Future<void> tapRow(WidgetTester tester, String label) async {
      await tester.scrollUntilVisible(find.text(label), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('each owner row opens its screen', (tester) async {
      await open(tester);

      await tapRow(tester, 'KYC & documents');
      await tapRow(tester, 'Payment methods');
      await tapRow(tester, 'Team & access');
      await tapRow(tester, 'Billing & subscription');

      expect(actions.calls, ['kyc:BUS1', 'payments:BUS1', 'team', 'billing:BUS1']);
    });
  });

  group('security', () {
    Future<void> tapRow(WidgetTester tester, String label) async {
      await tester.scrollUntilVisible(find.text(label), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('change password sends a reset link to the account email', (tester) async {
      await open(tester);

      await tapRow(tester, 'Change password');

      expect(actions.calls, ['reset:owner@onestay360.test']);
      expect(find.textContaining('Reset link sent to owner@onestay360.test'), findsOneWidget);
    });

    testWidgets('a failed reset says so', (tester) async {
      actions.resetFailure = Exception('network');
      await open(tester);

      await tapRow(tester, 'Change password');

      expect(find.text("Couldn't send the reset link. Try again."), findsOneWidget);
    });

    testWidgets('no password row for someone who signs in another way', (tester) async {
      await open(
        tester,
        account: const ProfileAccount(uid: 'u1', email: 'a@b.test', hasPassword: false),
      );

      expect(find.text('Change password'), findsNothing);
    });

    testWidgets('sign out asks first', (tester) async {
      await open(tester);

      await tapRow(tester, 'Sign out');
      expect(find.text('Sign out?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(actions.calls, isEmpty);

      await tapRow(tester, 'Sign out');
      await tester.tap(find.text('Sign out').last);
      await tester.pumpAndSettle();
      expect(actions.calls, ['signOut']);
    });

    testWidgets('delete account asks first and is explicit about it', (tester) async {
      await open(tester);

      await tapRow(tester, 'Delete account');
      expect(find.textContaining("can't be undone"), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['deleteAccount']);
    });

    testWidgets('the privacy policy opens', (tester) async {
      await open(tester);

      await tapRow(tester, 'Privacy policy');

      expect(actions.calls, ['privacy']);
    });
  });
}
