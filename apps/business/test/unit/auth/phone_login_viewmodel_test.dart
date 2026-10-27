import 'package:business/presentation/auth/auth_actions.dart';
import 'package:business/presentation/auth/phone_login_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePhoneAuth implements PhoneAuthActions {
  final sent = <String>[];
  final verified = <({String id, String code})>[];
  Object? sendFailure;
  Object? verifyFailure;
  String? verificationId = 'vid-1';
  void Function()? autoSignIn;

  @override
  Future<String?> sendCode(String phone, {required void Function() onAutoSignedIn}) async {
    sent.add(phone);
    autoSignIn = onAutoSignedIn;
    if (sendFailure != null) throw sendFailure!;
    return verificationId;
  }

  @override
  Future<void> verifyCode(String verificationId, String code) async {
    verified.add((id: verificationId, code: code));
    if (verifyFailure != null) throw verifyFailure!;
  }
}

void main() {
  late FakePhoneAuth auth;
  late DateTime now;
  late PhoneLoginViewModel vm;

  PhoneLoginViewModel make({String? initialPhone}) =>
      PhoneLoginViewModel(actions: auth, initialPhone: initialPhone, clock: () => now);

  setUp(() {
    auth = FakePhoneAuth();
    now = DateTime(2026, 10, 26, 10);
    vm = make();
  });

  tearDown(() => vm.dispose());

  group('the number', () {
    test('starts empty on the number step', () {
      expect(vm.step, PhoneStep.number);
      expect(vm.phone, '');
      expect(vm.phoneError, isNull);
    });

    test('can start with a number already filled in (an invitation)', () {
      final invited = make(initialPhone: '+919811100001');
      addTearDown(invited.dispose);

      expect(invited.phone, '+919811100001');
    });

    test('asks for a number, a good one', () async {
      await vm.sendCode();
      expect(vm.phoneError, 'Enter your mobile number.');

      vm.setPhone('12345');
      await vm.sendCode();
      expect(vm.phoneError, 'Enter a 10-digit mobile number.');
      expect(auth.sent, isEmpty);
    });

    test('clears the error as soon as the number is fixed', () async {
      await vm.sendCode();
      vm.setPhone('9811100001');

      expect(vm.phoneError, isNull);
    });
  });

  group('sending the code', () {
    test('sends to the full number and moves to the code step', () async {
      vm.setPhone('98111 00001');

      await vm.sendCode();

      expect(auth.sent, ['+919811100001']);
      expect(vm.step, PhoneStep.code);
      expect(vm.maskedPhone, '+91 98••• •0001');
      expect(vm.busy, isFalse);
    });

    test('shows why it could not send, and stays on the number step', () async {
      auth.sendFailure = const AuthFailure("That phone number doesn't look right.");
      vm.setPhone('9811100001');

      await vm.sendCode();

      expect(vm.step, PhoneStep.number);
      expect(vm.error, "That phone number doesn't look right.");
    });

    test('says something plain for an unknown failure', () async {
      auth.sendFailure = Exception('boom');
      vm.setPhone('9811100001');

      await vm.sendCode();

      expect(vm.error, "Couldn't send the code. Try again.");
    });

    test('is signed in at once when the phone reads the code itself', () async {
      auth.verificationId = null;
      vm.setPhone('9811100001');

      await vm.sendCode();

      expect(vm.signedIn, isTrue);
    });

    test('is signed in later if the phone reads the code after it was sent', () async {
      vm.setPhone('9811100001');
      await vm.sendCode();

      auth.autoSignIn!();

      expect(vm.signedIn, isTrue);
    });
  });

  group('the code', () {
    setUp(() async {
      vm.setPhone('9811100001');
      await vm.sendCode();
    });

    test('must be six digits', () async {
      vm.setCode('123');
      await vm.verify();

      expect(vm.codeError, 'Enter the 6-digit code.');
      expect(auth.verified, isEmpty);
    });

    test('ignores anything but digits and keeps six at most', () {
      vm.setCode('12a3 456789');

      expect(vm.code, '123456');
    });

    test('is checked with the id from sending', () async {
      vm.setCode('654321');

      await vm.verify();

      expect(auth.verified.single, (id: 'vid-1', code: '654321'));
      expect(vm.signedIn, isTrue);
    });

    test('says when it is wrong and lets them try again', () async {
      auth.verifyFailure = const AuthFailure('That code is not right. Check it and try again.');
      vm.setCode('000000');

      await vm.verify();

      expect(vm.codeError, 'That code is not right. Check it and try again.');
      expect(vm.signedIn, isFalse);
      expect(vm.busy, isFalse);

      auth.verifyFailure = null;
      vm.setCode('654321');
      await vm.verify();
      expect(vm.signedIn, isTrue);
    });

    test('a fresh digit clears the old complaint', () async {
      auth.verifyFailure = const AuthFailure('That code is not right. Check it and try again.');
      vm.setCode('000000');
      await vm.verify();

      vm.setCode('00000');

      expect(vm.codeError, isNull);
    });

    test('can go back to change the number', () {
      vm.changeNumber();

      expect(vm.step, PhoneStep.number);
      expect(vm.code, '');
      expect(vm.phone, '9811100001', reason: 'what they typed is still there to fix');
    });
  });

  group('asking for a new code', () {
    setUp(() async {
      vm.setPhone('9811100001');
      await vm.sendCode();
    });

    test('has to wait thirty seconds', () {
      expect(vm.canResend, isFalse);
      expect(vm.secondsUntilResend, 30);

      now = now.add(const Duration(seconds: 12));
      expect(vm.secondsUntilResend, 18);

      now = now.add(const Duration(seconds: 18));
      expect(vm.secondsUntilResend, 0);
      expect(vm.canResend, isTrue);
    });

    test('sends again to the same number and starts the wait over', () async {
      now = now.add(const Duration(seconds: 31));

      await vm.resend();

      expect(auth.sent, ['+919811100001', '+919811100001']);
      expect(vm.secondsUntilResend, 30);
    });

    test('is refused while the wait is on', () async {
      await vm.resend();

      expect(auth.sent, hasLength(1));
    });

    test('forgets a half typed code', () async {
      vm.setCode('123');
      now = now.add(const Duration(seconds: 31));

      await vm.resend();

      expect(vm.code, '');
    });
  });

  test('being disposed in the middle of sending does not throw', () async {
    final other = make();
    other.setPhone('9811100001');
    final pending = other.sendCode();

    other.dispose();

    await expectLater(pending, completes);
  });
}
