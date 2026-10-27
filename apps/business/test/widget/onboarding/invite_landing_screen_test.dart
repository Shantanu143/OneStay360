import 'dart:async';

import 'package:business/presentation/design/components/biz_button.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/onboarding/invite_gateway.dart';
import 'package:business/presentation/onboarding/invite_landing_screen.dart';
import 'package:business/presentation/onboarding/invite_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGateway implements InviteGateway {
  Invitation? invitation = Invitation(
    id: 'inv1',
    businessName: 'Sunrise Stays',
    inviterName: 'Rajesh Sharma',
    role: 'manager',
    phone: '+919811100001',
    status: 'pending',
    propertyIds: const ['P1', 'P2'],
    propertyNames: const ['Sunrise Boys PG', 'Lotus Ladies Hostel'],
    expiresAt: DateTime(2026, 10, 31, 10),
  );
  Object? fetchFailure;
  Object? acceptFailure;
  Completer<void>? gate;
  final accepted = <String>[];

  @override
  Future<Invitation?> fetch(String inviteId) async {
    await gate?.future;
    if (fetchFailure != null) throw fetchFailure!;
    return invitation;
  }

  @override
  Future<AcceptedInvite> accept(String inviteId) async {
    accepted.add(inviteId);
    if (acceptFailure != null) throw acceptFailure!;
    return const AcceptedInvite(businessId: 'B1', role: 'manager', propertyIds: ['P1', 'P2']);
  }
}

void main() {
  final now = DateTime(2026, 10, 26, 10);
  late FakeGateway gateway;
  String? verified;
  late List<String> events;
  var phoneResult = true;

  setUp(() {
    gateway = FakeGateway();
    verified = null;
    events = [];
    phoneResult = true;
  });

  Future<void> pump(WidgetTester tester, {bool settle = true}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: BizTheme.light(),
        home: InviteLandingScreen(
          inviteId: 'inv1',
          gateway: gateway,
          clock: () => now,
          verifiedPhone: () => verified,
          openPhone: (context, invite) async {
            events.add('phone:${invite.phone}');
            if (phoneResult) verified = invite.phone;
            return phoneResult;
          },
          onAccepted: (context, invite, accepted) => events.add('accepted:${accepted.businessId}:${invite.roleLabel}'),
        ),
      ),
    );
    if (settle) {
      await tester.pump();
      await tester.pumpAndSettle();
    }
  }

  testWidgets('shows who invited you, to what, and for how long', (tester) async {
    await pump(tester);

    expect(find.text("You're invited to join"), findsOneWidget);
    expect(find.text('Sunrise Stays'), findsOneWidget);
    expect(find.text('Rajesh Sharma invited you as manager.'), findsOneWidget);
    expect(find.text('Expires in 5 days'), findsOneWidget);
    expect(find.text('Sunrise Boys PG'), findsOneWidget);
    expect(find.text('Lotus Ladies Hostel'), findsOneWidget);
  });

  testWidgets('an older invitation without names still reads well', (tester) async {
    gateway.invitation = const Invitation(
      id: 'old', role: 'staff', phone: '+919811100001', status: 'pending', propertyIds: ['P1'], propertyNames: []);
    await pump(tester);

    expect(find.text('a business'), findsOneWidget);
    expect(find.text('The owner invited you as staff.'), findsOneWidget);
    expect(find.text('1 property'), findsOneWidget);
  });

  testWidgets('says which number it is for without spelling it out', (tester) async {
    await pump(tester);

    expect(find.textContaining('This invitation is for +91 98••• •0001'), findsOneWidget);
    expect(find.text('Verify number and accept'), findsOneWidget);
  });

  testWidgets('shows placeholders while it loads', (tester) async {
    gateway.gate = Completer<void>();
    await pump(tester, settle: false);
    await tester.pump();

    expect(find.text('Sunrise Stays'), findsNothing);

    gateway.gate!.complete();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Sunrise Stays'), findsOneWidget);
  });

  group('accepting', () {
    testWidgets('verifies the invited number first, then joins', (tester) async {
      await pump(tester);

      await tester.tap(find.widgetWithText(BizButton, 'Verify number and accept'));
      await tester.pumpAndSettle();

      expect(events, ['phone:+919811100001', 'accepted:B1:Manager']);
      expect(gateway.accepted, ['inv1']);
    });

    testWidgets('goes straight through when that number is already verified', (tester) async {
      verified = '+91 98111 00001';
      await pump(tester);

      expect(find.text("You're signed in with the invited number."), findsOneWidget);
      await tester.tap(find.widgetWithText(BizButton, 'Accept invitation'));
      await tester.pumpAndSettle();

      expect(events, ['accepted:B1:Manager']);
    });

    testWidgets('backing out of the phone check leaves it as it was', (tester) async {
      phoneResult = false;
      await pump(tester);

      await tester.tap(find.widgetWithText(BizButton, 'Verify number and accept'));
      await tester.pumpAndSettle();

      expect(events, ['phone:+919811100001']);
      expect(gateway.accepted, isEmpty);
      expect(find.byType(BizButton), findsOneWidget);
    });

    testWidgets('shows why it was refused', (tester) async {
      verified = '+919811100001';
      gateway.acceptFailure = const InviteException('This invitation was sent to a different phone number.');
      await pump(tester);

      await tester.tap(find.widgetWithText(BizButton, 'Accept invitation'));
      await tester.pumpAndSettle();

      expect(find.text('This invitation was sent to a different phone number.'), findsOneWidget);
      expect(events, isEmpty);
    });
  });

  group('when it cannot be used', () {
    testWidgets('one that does not exist', (tester) async {
      gateway.invitation = null;
      await pump(tester);

      expect(find.text("This invitation can't be used"), findsOneWidget);
      expect(find.text('We could not find this invitation. Ask the owner to send it again.'), findsOneWidget);
      expect(find.byType(BizButton), findsNothing);
    });

    testWidgets('one that was used', (tester) async {
      gateway.invitation = const Invitation(
        id: 'i', role: 'staff', phone: '+919811100001', status: 'accepted', propertyIds: [], propertyNames: []);
      await pump(tester);

      expect(find.text('This invitation has already been used.'), findsOneWidget);
    });

    testWidgets('one that expired', (tester) async {
      gateway.invitation = Invitation(
        id: 'i', role: 'staff', phone: '+919811100001', status: 'pending', propertyIds: const [], propertyNames: const [],
        expiresAt: DateTime(2026, 10, 20));
      await pump(tester);

      expect(find.text('This invitation has expired. Ask the owner for a new one.'), findsOneWidget);
    });

    testWidgets('one that could not be loaded can be tried again', (tester) async {
      gateway.fetchFailure = Exception('offline');
      await pump(tester);
      expect(find.text("Couldn't load this invitation. Check your connection and try again."), findsOneWidget);

      gateway.fetchFailure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Sunrise Stays'), findsOneWidget);
    });
  });
}
