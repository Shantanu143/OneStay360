import 'package:business/presentation/design/components/biz_button.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/onboarding/invite_models.dart';
import 'package:business/presentation/onboarding/invite_welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const invitation = Invitation(
    id: 'inv1',
    businessName: 'Sunrise Stays',
    role: 'staff',
    phone: '+919811100001',
    status: 'pending',
    propertyIds: ['P1'],
    propertyNames: ['Sunrise Boys PG'],
  );
  const accepted = AcceptedInvite(businessId: 'B1', role: 'staff', propertyIds: ['P1']);

  Future<void> pump(WidgetTester tester, {Invitation invite = invitation, Future<void> Function(BuildContext)? onContinue}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: BizTheme.light(),
        home: InviteWelcomeScreen(invitation: invite, accepted: accepted, onContinue: onContinue),
      ),
    );
    await tester.pump();
  }

  testWidgets('says what was joined and as what', (tester) async {
    await pump(tester);

    expect(find.text('Welcome aboard'), findsOneWidget);
    expect(find.text('You joined Sunrise Stays'), findsOneWidget);
    expect(find.text("You're in"), findsOneWidget);
    expect(find.text('Joined as staff.'), findsOneWidget);
    expect(find.text('Sunrise Boys PG'), findsOneWidget);
  });

  testWidgets('lists what a teammate can do, and nothing they cannot', (tester) async {
    await pump(tester);

    expect(find.text('What you can do'), findsOneWidget);
    expect(find.text('Add and update them'), findsOneWidget);
    expect(find.textContaining('Billing'), findsNothing);
    expect(find.textContaining('Reports'), findsNothing);
  });

  testWidgets('falls back to a count when the names are missing', (tester) async {
    await pump(
      tester,
      invite: const Invitation(id: 'i', role: 'staff', phone: '+919811100001', status: 'pending', propertyIds: ['P1'], propertyNames: []),
    );

    expect(find.text('You joined a business'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('has no way back: the invitation is used up', (tester) async {
    await pump(tester);

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
  });

  testWidgets('"Open the app" carries on, once even if tapped twice', (tester) async {
    var continued = 0;
    await pump(tester, onContinue: (_) async {
      continued++;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    await tester.tap(find.widgetWithText(BizButton, 'Open the app'));
    await tester.pump();
    await tester.tap(find.byType(BizButton), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));

    expect(continued, 1);
  });
}
