import 'package:business/presentation/auth/auth_actions.dart';
import 'package:business/presentation/auth/login_screen.dart';
import 'package:business/presentation/design/components/biz_button.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuth implements AuthActions {
  final calls = <String>[];
  Object? failure;
  bool googleCancelled = false;

  Future<void> _run(String call) async {
    calls.add(call);
    if (failure != null) throw failure!;
  }

  @override
  Future<void> signInWithEmail(String email, String password) => _run('signIn:$email:$password');

  @override
  Future<void> signUpWithEmail(String email, String password) => _run('signUp:$email:$password');

  @override
  Future<bool> signInWithGoogle() async {
    await _run('google');
    return !googleCancelled;
  }

  @override
  Future<void> sendPasswordReset(String email) => _run('reset:$email');
}

void main() {
  late FakeAuth auth;
  late List<String> opened;

  setUp(() {
    auth = FakeAuth();
    opened = [];
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: BizTheme.light(),
        home: LoginScreen(
          auth: auth,
          onOpenPhone: () => opened.add('phone'),
          onOpenUrl: (_, uri) => opened.add('url:$uri'),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> fill(WidgetTester tester, {String email = 'owner@example.test', String password = 'secret1'}) async {
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), password);
    await tester.pump();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.widgetWithText(BizButton, label));
    await tester.tap(find.widgetWithText(BizButton, label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('the page', () {
    testWidgets('welcomes the owner back with the ways to sign in', (tester) async {
      await pump(tester);

      expect(find.bySemanticsLabel('OneStay360'), findsOneWidget);
      expect(find.text('BUSINESS'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Continue with phone'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('has no back arrow: this is where signed-out people start', (tester) async {
      await pump(tester);

      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
    });

    testWidgets('the footer is fully on screen', (tester) async {
      await pump(tester);

      expect(find.textContaining('By continuing you agree to our'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('By continuing you agree to our'));
      expect(tester.takeException(), isNull);
    });
  });

  group('signing in', () {
    testWidgets('signs in with what was typed', (tester) async {
      await pump(tester);
      await fill(tester, email: ' Owner@Example.test ');

      await tapButton(tester, 'Sign in');

      expect(auth.calls, ['signIn:owner@example.test:secret1']);
    });

    testWidgets('says what is missing', (tester) async {
      await pump(tester);

      await tapButton(tester, 'Sign in');

      expect(find.text('Enter your email.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('says why a sign in failed', (tester) async {
      auth.failure = const AuthFailure('Wrong email or password.');
      await pump(tester);
      await fill(tester);

      await tapButton(tester, 'Sign in');

      expect(find.text('Wrong email or password.'), findsOneWidget);
      expect(tester.widget<BizButton>(find.widgetWithText(BizButton, 'Sign in')).onPressed, isNotNull);
    });

    testWidgets('the password can be shown and hidden', (tester) async {
      await pump(tester);
      TextField field() => tester.widget<TextField>(find.descendant(of: find.byKey(const Key('login-password')), matching: find.byType(TextField)).first);
      expect(field().obscureText, isTrue);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();

      expect(field().obscureText, isFalse);
      expect(find.byTooltip('Hide password'), findsOneWidget);
    });

    testWidgets('while signing in the buttons are off', (tester) async {
      await pump(tester);
      await fill(tester);

      await tapButton(tester, 'Sign in');

      expect(tester.widget<BizButton>(find.widgetWithText(BizButton, 'Continue with phone')).onPressed, isNull);
      expect(tester.widget<BizButton>(find.widgetWithText(BizButton, 'Continue with Google')).onPressed, isNull);
    });
  });

  group('creating an account', () {
    Future<void> toSignUp(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('login-toggle')));
      await tester.tap(find.byKey(const Key('login-toggle')));
      await tester.pump();
    }

    testWidgets('switches to sign up with a confirm field and no forgot link', (tester) async {
      await pump(tester);

      await toSignUp(tester);

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.byKey(const Key('login-confirm')), findsOneWidget);
      expect(find.text('Forgot password?'), findsNothing);
      expect(find.widgetWithText(BizButton, 'Create account'), findsOneWidget);
    });

    testWidgets('wants both passwords to match', (tester) async {
      await pump(tester);
      await toSignUp(tester);
      await fill(tester);
      await tester.enterText(find.byKey(const Key('login-confirm')), 'different');

      await tapButton(tester, 'Create account');

      expect(find.text("The passwords don't match."), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('creates the account', (tester) async {
      await pump(tester);
      await toSignUp(tester);
      await fill(tester);
      await tester.enterText(find.byKey(const Key('login-confirm')), 'secret1');

      await tapButton(tester, 'Create account');

      expect(auth.calls, ['signUp:owner@example.test:secret1']);
    });

    testWidgets('can go back to signing in', (tester) async {
      await pump(tester);
      await toSignUp(tester);

      await tester.ensureVisible(find.byKey(const Key('login-toggle')));
      await tester.tap(find.byKey(const Key('login-toggle')));
      await tester.pump();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byKey(const Key('login-confirm')), findsNothing);
    });
  });

  group('forgotten password', () {
    testWidgets('sends a reset link to the email typed', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('login-email')), 'owner@example.test');

      await tester.tap(find.byKey(const Key('login-forgot')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(auth.calls, ['reset:owner@example.test']);
      expect(find.textContaining('If an account exists for owner@example.test'), findsOneWidget);
    });

    testWidgets('asks for the email first', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const Key('login-forgot')));
      await tester.pump();

      expect(find.text('Enter your email above, then tap "Forgot password?".'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });
  });

  group('other ways in', () {
    testWidgets('Google signs in', (tester) async {
      await pump(tester);

      await tapButton(tester, 'Continue with Google');

      expect(auth.calls, ['google']);
    });

    testWidgets('backing out of Google leaves the page as it was', (tester) async {
      auth.googleCancelled = true;
      await pump(tester);

      await tapButton(tester, 'Continue with Google');

      expect(tester.widget<BizButton>(find.widgetWithText(BizButton, 'Continue with Google')).onPressed, isNotNull);
      expect(find.byType(BizButton), findsWidgets);
    });

    testWidgets('phone opens the phone screen', (tester) async {
      await pump(tester);

      await tapButton(tester, 'Continue with phone');

      expect(opened, ['phone']);
    });

    testWidgets('the terms and privacy links open', (tester) async {
      await pump(tester);

      await tester.ensureVisible(find.textContaining('By continuing you agree to our'));
      await tester.tapOnText(find.textRange.ofSubstring('Terms of Service'));
      await tester.tapOnText(find.textRange.ofSubstring('Privacy Policy'));

      expect(opened, ['url:$termsUrl', 'url:$privacyUrl']);
    });
  });
}
