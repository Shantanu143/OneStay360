import 'package:business/presentation/auth/auth_actions.dart';
import 'package:business/presentation/auth/phone_login_screen.dart';
import 'package:business/presentation/auth/phone_login_viewmodel.dart';
import 'package:business/presentation/design/components/biz_button.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePhoneAuth implements PhoneAuthActions {
  final sent = <String>[];
  final verified = <String>[];
  Object? sendFailure;
  Object? verifyFailure;
  void Function()? autoSignIn;

  @override
  Future<String?> sendCode(String phone, {required void Function() onAutoSignedIn}) async {
    sent.add(phone);
    autoSignIn = onAutoSignedIn;
    if (sendFailure != null) throw sendFailure!;
    return 'vid';
  }

  @override
  Future<void> verifyCode(String verificationId, String code) async {
    verified.add(code);
    if (verifyFailure != null) throw verifyFailure!;
  }
}

void main() {
  late FakePhoneAuth auth;
  Object? popped = 'unset';
  var now = DateTime(2026, 10, 26, 10);

  setUp(() {
    auth = FakePhoneAuth();
    popped = 'unset';
    now = DateTime(2026, 10, 26, 10);
  });

  Future<void> open(
    WidgetTester tester, {
    String? initialPhone,
    bool returnToCaller = false,
    bool lockPhone = false,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: BizTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => PhoneLoginScreen(
                        actions: auth,
                        clock: () => now,
                        initialPhone: initialPhone,
                        returnToCaller: returnToCaller,
                        lockPhone: lockPhone,
                      ),
                    ),
                  );
                },
                child: const Text('launch'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('launch'));
    await tester.pumpAndSettle();
  }

  Future<void> sendTo(WidgetTester tester, String number) async {
    await tester.enterText(find.byKey(const Key('phone-number')), number);
    await tester.tap(find.widgetWithText(BizButton, 'Send code'));
    await tester.pumpAndSettle();
  }

  group('the number', () {
    testWidgets('asks for a mobile number', (tester) async {
      await open(tester);

      expect(find.text('Sign in with phone'), findsOneWidget);
      expect(find.byKey(const Key('phone-number')), findsOneWidget);
    });

    testWidgets('says what is wrong with a number', (tester) async {
      await open(tester);

      await sendTo(tester, '12345');

      expect(find.text('Enter a 10-digit mobile number.'), findsOneWidget);
      expect(auth.sent, isEmpty);
    });

    testWidgets('sends the code and asks for it', (tester) async {
      await open(tester);

      await sendTo(tester, '98111 00001');

      expect(auth.sent, ['+919811100001']);
      expect(find.text('Enter the code'), findsOneWidget);
      expect(find.textContaining('+91 98••• •0001'), findsOneWidget);
    });

    testWidgets('says why a code could not be sent', (tester) async {
      auth.sendFailure = const AuthFailure('Too many codes were requested. Try again later.');
      await open(tester);

      await sendTo(tester, '9811100001');

      expect(find.text('Too many codes were requested. Try again later.'), findsOneWidget);
      expect(find.byKey(const Key('phone-number')), findsOneWidget);
    });
  });

  group('the code', () {
    Future<void> toCodeStep(WidgetTester tester, {bool returnToCaller = false}) async {
      await open(tester, returnToCaller: returnToCaller);
      await sendTo(tester, '9811100001');
    }

    testWidgets('is checked as soon as the sixth digit is typed', (tester) async {
      await toCodeStep(tester);

      await tester.enterText(find.byKey(const Key('phone-code')), '123456');
      await tester.pumpAndSettle();

      expect(auth.verified, ['123456']);
    });

    testWidgets('is not checked before it is complete', (tester) async {
      await toCodeStep(tester);

      await tester.enterText(find.byKey(const Key('phone-code')), '123');
      await tester.pump();

      expect(auth.verified, isEmpty);
    });

    testWidgets('says when it is wrong and stays open', (tester) async {
      auth.verifyFailure = const AuthFailure('That code is not right. Check it and try again.');
      await toCodeStep(tester);

      await tester.enterText(find.byKey(const Key('phone-code')), '000000');
      await tester.pumpAndSettle();

      expect(find.text('That code is not right. Check it and try again.'), findsOneWidget);
      expect(find.byKey(const Key('phone-code')), findsOneWidget);
      expect(popped, 'unset');
    });

    testWidgets('can be checked with the button too', (tester) async {
      await toCodeStep(tester);

      await tester.tap(find.widgetWithText(BizButton, 'Verify'));
      await tester.pump();

      expect(find.text('Enter the 6-digit code.'), findsOneWidget);
    });

    testWidgets('the number can be changed', (tester) async {
      await toCodeStep(tester);

      await tester.tap(find.byKey(const Key('phone-change')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('phone-number')), findsOneWidget);
    });

    testWidgets('a good code goes back to where we were when asked to', (tester) async {
      await toCodeStep(tester, returnToCaller: true);

      await tester.enterText(find.byKey(const Key('phone-code')), '654321');
      await tester.pumpAndSettle();

      expect(popped, true);
      expect(find.text('launch'), findsOneWidget);
    });

    testWidgets('a good code otherwise uncovers the auth gate', (tester) async {
      await toCodeStep(tester);

      await tester.enterText(find.byKey(const Key('phone-code')), '654321');
      await tester.pumpAndSettle();

      expect(find.text('launch'), findsOneWidget, reason: 'back at the first route');
      expect(popped, isNull, reason: 'popUntil does not carry a result');
    });

    testWidgets('a phone that reads the code itself is signed in without typing', (tester) async {
      await toCodeStep(tester, returnToCaller: true);

      auth.autoSignIn!();
      await tester.pumpAndSettle();

      expect(popped, true);
    });
  });

  group('asking again', () {
    testWidgets('counts down, then offers a new code', (tester) async {
      await open(tester);
      await sendTo(tester, '9811100001');

      expect(find.text('Resend in 0:30'), findsOneWidget);
      expect(tester.widget<TextButton>(find.byKey(const Key('phone-resend'))).onPressed, isNull);

      now = now.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Resend code'), findsOneWidget);
      await tester.tap(find.byKey(const Key('phone-resend')));
      await tester.pumpAndSettle();

      expect(auth.sent, ['+919811100001', '+919811100001']);
      expect(find.text('Resend in 0:30'), findsOneWidget);
    });
  });

  group('from an invitation', () {
    testWidgets('the number is the one invited and cannot be changed', (tester) async {
      await open(tester, initialPhone: '+919811100001', returnToCaller: true, lockPhone: true);

      expect(find.text('Your invitation'), findsOneWidget);
      expect(find.textContaining('Your owner invited this number'), findsOneWidget);
      final field = tester.widget<TextField>(find.descendant(of: find.byKey(const Key('phone-number')), matching: find.byType(TextField)).first);
      expect(field.readOnly, isTrue);

      await tester.tap(find.widgetWithText(BizButton, 'Send code'));
      await tester.pumpAndSettle();

      expect(auth.sent, ['+919811100001']);
      expect(find.byKey(const Key('phone-change')), findsNothing, reason: 'no other number to switch to');
    });
  });
}
