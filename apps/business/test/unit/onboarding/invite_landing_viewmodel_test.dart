import 'package:business/presentation/onboarding/invite_gateway.dart';
import 'package:business/presentation/onboarding/invite_landing_viewmodel.dart';
import 'package:business/presentation/onboarding/invite_models.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGateway implements InviteGateway {
  Invitation? invitation = const Invitation(
    id: 'inv1',
    businessName: 'Sunrise Stays',
    role: 'manager',
    phone: '+919811100001',
    status: 'pending',
    propertyIds: ['P1'],
    propertyNames: ['Sunrise Boys PG'],
  );
  Object? fetchFailure;
  Object? acceptFailure;
  final accepted = <String>[];

  @override
  Future<Invitation?> fetch(String inviteId) async {
    if (fetchFailure != null) throw fetchFailure!;
    return invitation;
  }

  @override
  Future<AcceptedInvite> accept(String inviteId) async {
    accepted.add(inviteId);
    if (acceptFailure != null) throw acceptFailure!;
    return const AcceptedInvite(businessId: 'B1', role: 'manager', propertyIds: ['P1']);
  }
}

void main() {
  final now = DateTime(2026, 10, 26, 10);
  late FakeGateway gateway;
  String? verified;
  late InviteLandingViewModel vm;

  setUp(() {
    gateway = FakeGateway();
    verified = null;
    vm = InviteLandingViewModel(
      inviteId: 'inv1',
      gateway: gateway,
      verifiedPhone: () => verified,
      clock: () => now,
    );
  });

  tearDown(() => vm.dispose());

  group('opening the link', () {
    test('is loading, then ready', () async {
      final pending = vm.load();
      expect(vm.state, LandingState.loading);

      await pending;

      expect(vm.state, LandingState.ready);
      expect(vm.invitation!.businessName, 'Sunrise Stays');
    });

    test('says so when there is no such invitation', () async {
      gateway.invitation = null;
      await vm.load();

      expect(vm.state, LandingState.unavailable);
      expect(vm.problem, 'We could not find this invitation. Ask the owner to send it again.');
    });

    test('says so when it was already used', () async {
      gateway.invitation = const Invitation(
        id: 'inv1', role: 'staff', phone: '+919811100001', status: 'accepted', propertyIds: [], propertyNames: []);
      await vm.load();

      expect(vm.state, LandingState.unavailable);
      expect(vm.problem, 'This invitation has already been used.');
    });

    test('says so when it has expired', () async {
      gateway.invitation = Invitation(
        id: 'inv1', role: 'staff', phone: '+919811100001', status: 'pending', propertyIds: const [], propertyNames: const [],
        expiresAt: DateTime(2026, 10, 20));
      await vm.load();

      expect(vm.state, LandingState.unavailable);
      expect(vm.problem, 'This invitation has expired. Ask the owner for a new one.');
    });

    test('says so when it cannot be reached, and tries again', () async {
      gateway.fetchFailure = Exception('offline');
      await vm.load();

      expect(vm.state, LandingState.failed);
      expect(vm.problem, "Couldn't load this invitation. Check your connection and try again.");

      gateway.fetchFailure = null;
      await vm.load();

      expect(vm.state, LandingState.ready);
    });
  });

  group('accepting', () {
    setUp(() async => vm.load());

    Future<bool> never(Invitation _) async => fail('should not ask for a phone check');

    test('goes straight through when this phone is already verified', () async {
      verified = '+91 98111 00001';

      final result = await vm.accept(verifyPhone: never);

      expect(result!.businessId, 'B1');
      expect(gateway.accepted, ['inv1']);
      expect(vm.needsPhoneCheck, isFalse);
    });

    test('asks to verify the invited number first when it is not', () async {
      verified = null;
      var asked = 0;

      final result = await vm.accept(verifyPhone: (invite) async {
        asked++;
        expect(invite.phone, '+919811100001');
        verified = '+919811100001';
        return true;
      });

      expect(asked, 1);
      expect(result, isNotNull);
    });

    test('a different verified number counts as not verified', () async {
      verified = '+919000000999';
      var asked = false;

      await vm.accept(verifyPhone: (_) async {
        asked = true;
        verified = '+919811100001';
        return true;
      });

      expect(asked, isTrue);
    });

    test('backing out of the phone check is not an error', () async {
      final result = await vm.accept(verifyPhone: (_) async => false);

      expect(result, isNull);
      expect(vm.error, isNull);
      expect(gateway.accepted, isEmpty);
    });

    test('is refused if the phone check ended on some other number', () async {
      final result = await vm.accept(verifyPhone: (_) async {
        verified = '+919000000999';
        return true;
      });

      expect(result, isNull);
      expect(vm.error, 'Verify the invited number to continue.');
      expect(gateway.accepted, isEmpty);
    });

    test('shows the reason the server gave', () async {
      verified = '+919811100001';
      gateway.acceptFailure = const InviteException('This invitation was sent to a different phone number.');

      final result = await vm.accept(verifyPhone: never);

      expect(result, isNull);
      expect(vm.error, 'This invitation was sent to a different phone number.');
      expect(vm.accepting, isFalse);
    });

    test('says something plain for any other failure', () async {
      verified = '+919811100001';
      gateway.acceptFailure = Exception('boom');

      await vm.accept(verifyPhone: never);

      expect(vm.error, "Couldn't accept the invitation. Try again.");
    });

    test('is busy while accepting', () async {
      verified = '+919811100001';
      var sawBusy = false;
      vm.addListener(() => sawBusy = sawBusy || vm.accepting);

      await vm.accept(verifyPhone: never);

      expect(sawBusy, isTrue);
    });

    test('does nothing twice at once', () async {
      verified = '+919811100001';
      final first = vm.accept(verifyPhone: never);
      final second = vm.accept(verifyPhone: never);

      await Future.wait([first, second]);

      expect(gateway.accepted, hasLength(1));
    });
  });
}
