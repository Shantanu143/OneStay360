import 'dart:async';

import 'package:business/presentation/design/components/biz_button.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/team/team_actions.dart';
import 'package:business/presentation/team/team_models.dart';
import 'package:business/presentation/team/team_screen.dart';
import 'package:business/presentation/team/team_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/team_fakes.dart';

class FakeActions implements TeamActions {
  final calls = <String>[];

  @override
  Future<void> copy(BuildContext context, String text, {String? message}) async => calls.add('copy:$text');

  @override
  Future<void> openUrl(BuildContext context, Uri uri) async => calls.add('open:$uri');

  @override
  Future<void> call(BuildContext context, String phone) async => calls.add('call:$phone');
}

void main() {
  final now = DateTime(2026, 10, 26, 10);
  late FakeTeamSource source;
  late FakeActions actions;

  TeamInvite invite(String id, DateTime expires, {String phone = '+919811100001', String role = 'staff', String? email}) =>
      TeamInvite(
        id: id,
        phone: phone,
        email: email,
        role: role,
        propertyIds: const ['P1'],
        createdAt: DateTime(2026, 10, 24),
        expiresAt: expires,
      );

  setUp(() {
    source = FakeTeamSource(
      members: [
        member('o1', 'Rajesh Sharma', role: 'owner', phone: '+919000000001', email: 'owner@example.test'),
        member('m1', 'Priya Nair', role: 'manager', phone: '+919000000002'),
        member('s1', 'Amit Verma', role: 'staff', phone: '+919000000003'),
        member('d1', 'Zoya Khan', role: 'staff', status: 'disabled'),
      ],
      access: {
        'm1': {'P1', 'P2'},
        's1': {'P1'},
      },
    );
    actions = FakeActions();
  });

  tearDown(() => source.dispose());

  Future<void> pumpScreen(WidgetTester tester, {bool canManage = true, bool settle = true}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: BizTheme.light(),
        home: TeamScreen(
          source: source,
          actions: actions,
          clock: () => now,
          businessId: 'B1',
          canManage: canManage,
        ),
      ),
    );
    if (settle) {
      await tester.pump();
      await tester.pumpAndSettle();
    }
  }

  group('the list', () {
    testWidgets('shows who is on the team, what they are and what they can open', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Team'), findsOneWidget);
      expect(find.text('4 members'), findsOneWidget);
      expect(find.text('Rajesh Sharma'), findsOneWidget);
      expect(find.text('Owner · All properties'), findsOneWidget);
      expect(find.text('Priya Nair'), findsOneWidget);
      expect(find.text('Manager · 2 properties'), findsOneWidget);
      expect(find.text('Staff · 1 property'), findsOneWidget);
    });

    testWidgets('marks someone whose access is off', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Access off'), findsOneWidget);
      expect(find.text('Staff · No properties'), findsOneWidget);
    });

    testWidgets('puts the owner first and those without access last', (tester) async {
      await pumpScreen(tester);

      final y = {
        for (final n in ['Rajesh Sharma', 'Amit Verma', 'Priya Nair', 'Zoya Khan']) n: tester.getTopLeft(find.text(n)).dy,
      };
      expect(y['Rajesh Sharma']!, lessThan(y['Amit Verma']!));
      expect(y['Amit Verma']!, lessThan(y['Priya Nair']!));
      expect(y['Priya Nair']!, lessThan(y['Zoya Khan']!));
    });

    testWidgets('shows placeholders while it loads', (tester) async {
      source.membersGate = Completer<void>();
      await pumpScreen(tester, settle: false);
      await tester.pump();

      expect(find.text('Rajesh Sharma'), findsNothing);
      expect(find.text('Invite someone'), findsOneWidget);

      source.membersGate!.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Rajesh Sharma'), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      source.membersFailure = Exception('denied');
      await pumpScreen(tester);
      expect(find.text("Couldn't load your team."), findsOneWidget);

      source.membersFailure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Rajesh Sharma'), findsOneWidget);
    });

    testWidgets('a team of one suggests inviting someone', (tester) async {
      source.members = [member('o1', 'Rajesh Sharma', role: 'owner')];
      await pumpScreen(tester);

      expect(find.text('1 member'), findsOneWidget);
      expect(find.text('Invite a manager or staff to share the day-to-day work.'), findsOneWidget);
    });

    testWidgets('anyone but the owner is told it is not theirs to manage', (tester) async {
      await pumpScreen(tester, canManage: false);

      expect(find.text('Only the owner manages the team'), findsOneWidget);
      expect(find.text('Invite someone'), findsNothing);
      expect(source.calls, isEmpty, reason: 'nothing is read for someone who cannot use it');
    });
  });

  group('pending invitations', () {
    setUp(() {
      source.invites = [
        invite('late', DateTime(2026, 10, 31), phone: '+919811100002', role: 'manager', email: 'new@example.test'),
        invite('soon', DateTime(2026, 10, 27, 9)),
        invite('gone', DateTime(2026, 10, 20), phone: '+919811100003'),
      ];
    });

    testWidgets('lists the open ones soonest first, and not the expired', (tester) async {
      await pumpScreen(tester);

      expect(find.text('PENDING INVITATIONS'), findsOneWidget);
      expect(find.text('+919811100001'), findsOneWidget);
      expect(find.text('Staff · Expires tomorrow'), findsOneWidget);
      expect(find.text('+919811100002 · new@example.test'), findsOneWidget);
      expect(find.text('Manager · Expires in 5 days'), findsOneWidget);
      expect(find.text('+919811100003'), findsNothing);
      expect(
        tester.getTopLeft(find.text('+919811100001')).dy,
        lessThan(tester.getTopLeft(find.text('+919811100002 · new@example.test')).dy),
      );
    });

    testWidgets('one can be shared again: copy the link or send it on WhatsApp', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('+919811100001'));
      await tester.pumpAndSettle();
      expect(find.text('Invitation link'), findsOneWidget);
      expect(find.text('https://app.onestay360.brandedpatil.in/invite?inviteId=soon'), findsOneWidget);

      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['copy:https://app.onestay360.brandedpatil.in/invite?inviteId=soon']);

      await tester.tap(find.text('Share on WhatsApp'));
      await tester.pumpAndSettle();
      expect(actions.calls.last, startsWith('open:https://wa.me/919811100001?text='));
      expect(actions.calls.last, contains('inviteId%3Dsoon'));
    });
  });

  group('inviting', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text('Invite someone'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks for what is missing when sent empty', (tester) async {
      await pumpScreen(tester);
      await openSheet(tester);

      await tester.tap(find.text('Send invitation'));
      await tester.pumpAndSettle();

      expect(find.text('Enter their mobile number.'), findsOneWidget);
      expect(find.text('Pick at least one property.'), findsOneWidget);
      expect(source.invited, isEmpty);
    });

    testWidgets('says what is wrong with a number', (tester) async {
      await pumpScreen(tester);
      await openSheet(tester);

      await tester.enterText(find.byKey(const Key('invite-phone')), '12345');
      await tester.tap(find.byKey(const Key('property-P1')));
      await tester.tap(find.text('Send invitation'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a 10-digit mobile number.'), findsOneWidget);
      expect(source.invited, isEmpty);
    });

    testWidgets('sends the invitation and then offers the link', (tester) async {
      await pumpScreen(tester);
      await openSheet(tester);

      await tester.enterText(find.byKey(const Key('invite-phone')), '98111 00009');
      await tester.enterText(find.byKey(const Key('invite-email')), 'New.Hire@Example.test');
      await tester.tap(find.text('Staff'));
      await tester.tap(find.byKey(const Key('property-P1')));
      await tester.tap(find.byKey(const Key('property-P2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send invitation'));
      await tester.pumpAndSettle();

      final sent = source.invited.single;
      expect(sent.phone, '+919811100009');
      expect(sent.email, 'new.hire@example.test');
      expect(sent.role, 'staff');
      expect(sent.propertyIds, ['P1', 'P2']);

      expect(find.text('Invitation sent'), findsOneWidget);
      expect(
        find.text("We'll text the link to +919811100009 and email it to new.hire@example.test. You can also send it yourself."),
        findsOneWidget,
        reason: 'it promises an attempt, not a delivery',
      );
      expect(find.text('https://app.example.test/invite?inviteId=inv1'), findsOneWidget);

      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['copy:https://app.example.test/invite?inviteId=inv1']);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Invitation sent'), findsNothing);
      expect(find.text('PENDING INVITATIONS'), findsOneWidget, reason: 'the new invitation is on the list');
    });

    testWidgets('"Select all" ticks every property', (tester) async {
      await pumpScreen(tester);
      await openSheet(tester);

      await tester.tap(find.byKey(const Key('invite-select-all')));
      await tester.pumpAndSettle();
      expect(find.text('Clear all'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('invite-phone')), '9811100009');
      await tester.tap(find.text('Send invitation'));
      await tester.pumpAndSettle();

      expect(source.invited.single.propertyIds, ['P1', 'P2']);
    });

    testWidgets('a refusal stays on the form and says why', (tester) async {
      source.inviteFailure = const TeamException('Only the owner can invite team members.');
      await pumpScreen(tester);
      await openSheet(tester);

      await tester.enterText(find.byKey(const Key('invite-phone')), '9811100009');
      await tester.tap(find.byKey(const Key('property-P1')));
      await tester.tap(find.text('Send invitation'));
      await tester.pumpAndSettle();

      expect(find.text('Only the owner can invite team members.'), findsOneWidget);
      expect(find.text('Invitation sent'), findsNothing);
      expect(find.text('Send invitation'), findsOneWidget);
    });

    testWidgets('with no properties there is nobody to give access to', (tester) async {
      final empty = FakeTeamSource(members: source.members, properties: const []);
      addTearDown(empty.dispose);
      source = empty;
      await pumpScreen(tester);

      await tester.tap(find.text('Invite someone'));
      await tester.pumpAndSettle();

      expect(find.text('Add a property first, then invite your team.'), findsOneWidget);
      expect(find.text('Send invitation'), findsNothing);
    });
  });

  group('a member', () {
    Future<void> openMember(WidgetTester tester, String name) async {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    testWidgets('shows contact, role and the properties they can open', (tester) async {
      await pumpScreen(tester);
      await openMember(tester, 'Priya Nair');

      expect(find.text('+919000000002'), findsOneWidget);
      expect(find.text('Not provided'), findsOneWidget, reason: 'no email on file');
      expect(find.text('Save access'), findsOneWidget);
      final p1 = tester.widget<Semantics>(find.descendant(of: find.byKey(const Key('property-P1')), matching: find.byType(Semantics)).first);
      expect(p1.properties.checked, isTrue);
    });

    testWidgets('can be called or have the number copied', (tester) async {
      await pumpScreen(tester);
      await openMember(tester, 'Priya Nair');

      await tester.tap(find.byTooltip('Call'));
      await tester.tap(find.byTooltip('Copy phone number'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['call:+919000000002', 'copy:+919000000002']);
    });

    testWidgets('saving is only possible after a change', (tester) async {
      await pumpScreen(tester);
      await openMember(tester, 'Priya Nair');
      VoidCallback? onSave() => tester.widget<BizButton>(find.widgetWithText(BizButton, 'Save access')).onPressed;

      expect(onSave(), isNull);

      await tester.tap(find.byKey(const Key('property-P2')));
      await tester.pumpAndSettle();

      expect(onSave(), isNotNull);
    });

    testWidgets('a changed role and properties are saved, then the list reloads', (tester) async {
      await pumpScreen(tester);
      await openMember(tester, 'Amit Verma');
      expect(find.text('Staff · 1 property'), findsNothing, reason: 'the list is behind the detail page');

      await tester.tap(find.text('Manager'));
      await tester.tap(find.byKey(const Key('property-P2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save access'));
      await tester.pumpAndSettle();

      expect(source.updates.single.uid, 's1');
      expect(source.updates.single.role, 'manager');
      expect(source.updates.single.propertyIds, ['P1', 'P2']);
      expect(find.text('Team'), findsOneWidget, reason: 'back on the list');
      expect(find.text('Staff · 2 properties'), findsOneWidget, reason: 'the count is read again');
    });

    testWidgets('a refusal stays open and says why', (tester) async {
      source.updateFailure = const TeamException('Their access is off. Turn it on first.');
      await pumpScreen(tester);
      await openMember(tester, 'Amit Verma');

      await tester.tap(find.byKey(const Key('property-P2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save access'));
      await tester.pumpAndSettle();

      expect(find.text('Their access is off. Turn it on first.'), findsOneWidget);
      expect(find.text('Save access'), findsOneWidget);
    });

    testWidgets('the owner\'s access cannot be changed or turned off', (tester) async {
      await pumpScreen(tester);
      await openMember(tester, 'Rajesh Sharma');

      expect(find.text('The owner can always open every property. This cannot be changed.'), findsOneWidget);
      expect(find.text('Save access'), findsNothing);
      expect(find.text('Turn off access'), findsNothing);
    });

    testWidgets('access can be turned off after a warning, and the list shows it', (tester) async {
      await pumpScreen(tester);
      await openMember(tester, 'Priya Nair');

      await tester.ensureVisible(find.text('Turn off access'));
      await tester.tap(find.text('Turn off access'));
      await tester.pumpAndSettle();
      expect(find.text('Turn off access?'), findsOneWidget);
      expect(find.textContaining("won't be able to open the app"), findsOneWidget);

      await tester.tap(find.text('Turn off'));
      await tester.pumpAndSettle();

      expect(source.calls, contains('setMemberActive:m1:false'));
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('Access off'), findsNWidgets(2));
    });

    testWidgets('cancelling the warning changes nothing', (tester) async {
      await pumpScreen(tester);
      await openMember(tester, 'Priya Nair');

      await tester.ensureVisible(find.text('Turn off access'));
      await tester.tap(find.text('Turn off access'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(source.calls.where((c) => c.startsWith('setMemberActive')), isEmpty);
    });

    testWidgets('someone whose access is off can be turned back on', (tester) async {
      await pumpScreen(tester);
      await openMember(tester, 'Zoya Khan');

      expect(find.textContaining("Their access is off"), findsOneWidget);
      expect(find.text('Save access'), findsNothing);

      await tester.ensureVisible(find.text('Turn access back on'));
      await tester.tap(find.text('Turn access back on'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();

      expect(source.calls, contains('setMemberActive:d1:true'));
      expect(find.text('Access off'), findsNothing);
    });

    testWidgets('when their access cannot be read, saving is not offered', (tester) async {
      await pumpScreen(tester);
      source.accessFailure = Exception('denied');
      await openMember(tester, 'Priya Nair');

      expect(find.text("Couldn't load their access."), findsOneWidget);
      expect(find.text('Save access'), findsNothing);
    });
  });
}
