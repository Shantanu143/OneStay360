import 'package:business/presentation/auth/auth_actions.dart';
import 'package:business/presentation/auth/login_viewmodel.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  late LoginViewModel vm;

  setUp(() {
    auth = FakeAuth();
    vm = LoginViewModel(auth: auth);
  });

  tearDown(() => vm.dispose());

  group('signing in', () {
    test('starts on sign in with nothing wrong', () {
      expect(vm.isSignUp, isFalse);
      expect(vm.emailError, isNull);
      expect(vm.passwordError, isNull);
      expect(vm.message, isNull);
    });

    test('asks for an email and a password, only after a try', () async {
      await vm.submit();

      expect(vm.emailError, 'Enter your email.');
      expect(vm.passwordError, 'Enter your password.');
      expect(auth.calls, isEmpty);
    });

    test('says when the email is not an email', () async {
      vm.setEmail('not-an-email');
      vm.setPassword('secret1');

      await vm.submit();

      expect(vm.emailError, 'Enter a valid email address.');
      expect(auth.calls, isEmpty);
    });

    test('signs in with a tidied email', () async {
      vm.setEmail('  Owner@Example.test ');
      vm.setPassword('secret1');

      await vm.submit();

      expect(auth.calls, ['signIn:owner@example.test:secret1']);
      expect(vm.message, isNull);
    });

    test('stays busy after success, since the app takes over from here', () async {
      vm.setEmail('a@b.co');
      vm.setPassword('secret1');

      await vm.submit();

      expect(vm.busy, isTrue);
    });

    test('shows why it failed and lets them try again', () async {
      auth.failure = const AuthFailure('Wrong email or password.');
      vm.setEmail('a@b.co');
      vm.setPassword('secret1');

      await vm.submit();

      expect(vm.message!.text, 'Wrong email or password.');
      expect(vm.message!.isError, isTrue);
      expect(vm.busy, isFalse);
    });

    test('says something plain for a failure it does not know', () async {
      auth.failure = Exception('boom');
      vm.setEmail('a@b.co');
      vm.setPassword('secret1');

      await vm.submit();

      expect(vm.message!.text, "Couldn't sign you in. Try again.");
    });

    test('clears an error as soon as it is fixed', () async {
      await vm.submit();
      expect(vm.emailError, isNotNull);

      vm.setEmail('a@b.co');

      expect(vm.emailError, isNull);
    });

    test('does nothing while it is already busy', () async {
      vm.setEmail('a@b.co');
      vm.setPassword('secret1');
      await vm.submit();

      await vm.submit();

      expect(auth.calls, hasLength(1));
    });
  });

  group('creating an account', () {
    setUp(() => vm.toggleMode());

    test('switches mode and clears old messages', () async {
      expect(vm.isSignUp, isTrue);
      vm.toggleMode();
      expect(vm.isSignUp, isFalse);
    });

    test('wants a password of at least six characters', () async {
      vm.setEmail('a@b.co');
      vm.setPassword('12345');
      vm.setConfirm('12345');

      await vm.submit();

      expect(vm.passwordError, 'Use at least 6 characters.');
      expect(auth.calls, isEmpty);
    });

    test('wants the same password twice', () async {
      vm.setEmail('a@b.co');
      vm.setPassword('secret1');
      vm.setConfirm('secret2');

      await vm.submit();

      expect(vm.confirmError, "The passwords don't match.");
      expect(auth.calls, isEmpty);
    });

    test('creates the account', () async {
      vm.setEmail('New@Example.test');
      vm.setPassword('secret1');
      vm.setConfirm('secret1');

      await vm.submit();

      expect(auth.calls, ['signUp:new@example.test:secret1']);
    });

    test('a short password is fine when signing in (it may be an old one)', () async {
      vm.toggleMode();
      vm.setEmail('a@b.co');
      vm.setPassword('123');

      await vm.submit();

      expect(auth.calls, ['signIn:a@b.co:123']);
    });
  });

  group('Google', () {
    test('signs in', () async {
      await vm.google();

      expect(auth.calls, ['google']);
      expect(vm.busy, isTrue, reason: 'the app takes over');
    });

    test('says nothing when they back out', () async {
      auth.googleCancelled = true;

      await vm.google();

      expect(vm.busy, isFalse);
      expect(vm.message, isNull);
    });

    test('shows why it failed', () async {
      auth.failure = const AuthFailure('No internet connection. Check it and try again.');

      await vm.google();

      expect(vm.message!.text, 'No internet connection. Check it and try again.');
      expect(vm.busy, isFalse);
    });
  });

  group('forgotten password', () {
    test('needs an email to send to', () async {
      await vm.forgotPassword();

      expect(vm.emailError, 'Enter your email above, then tap "Forgot password?".');
      expect(auth.calls, isEmpty);
    });

    test('sends a reset link and says so without promising an account exists', () async {
      vm.setEmail('Owner@Example.test');

      await vm.forgotPassword();

      expect(auth.calls, ['reset:owner@example.test']);
      expect(vm.message!.isError, isFalse);
      expect(vm.message!.text, contains('owner@example.test'));
      expect(vm.message!.text, contains('If an account exists'));
      expect(vm.busy, isFalse);
    });

    test('shows why it failed', () async {
      auth.failure = const AuthFailure('Too many attempts. Try again in a few minutes.');
      vm.setEmail('a@b.co');

      await vm.forgotPassword();

      expect(vm.message!.text, 'Too many attempts. Try again in a few minutes.');
      expect(vm.message!.isError, isTrue);
    });
  });

  group('error wording', () {
    test('does not say whether the email or the password was wrong', () {
      for (final code in ['user-not-found', 'wrong-password', 'invalid-credential']) {
        expect(explainAuthError(FirebaseAuthException(code: code)).message, 'Wrong email or password.');
      }
    });

    test('has plain words for the usual problems', () {
      expect(explainAuthError(FirebaseAuthException(code: 'network-request-failed')).message, contains('internet'));
      expect(explainAuthError(FirebaseAuthException(code: 'too-many-requests')).message, contains('Too many attempts'));
      expect(explainAuthError(FirebaseAuthException(code: 'email-already-in-use')).message, contains('already exists'));
      expect(explainAuthError(FirebaseAuthException(code: 'something-new')).message, "Couldn't sign you in. Try again.");
    });
  });
}
