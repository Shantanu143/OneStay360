import 'package:business/presentation/team/firestore_team_source.dart';
import 'package:business/presentation/team/invite_form_viewmodel.dart';
import 'package:business/presentation/team/team_models.dart';
import 'package:business/presentation/team/team_source.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore fs;
  late List<({String name, Map<String, dynamic> data})> called;
  Object? callFailure;
  Map<String, dynamic> callResult = {};
  late FirestoreTeamSource source;

  setUp(() {
    fs = FakeFirebaseFirestore();
    called = [];
    callFailure = null;
    callResult = {'inviteId': 'inv9', 'inviteLink': 'https://app.example.test/invite?inviteId=inv9'};
    source = FirestoreTeamSource(
      firestore: fs,
      currentUid: () => 'u_owner',
      callable: (name, data) async {
        called.add((name: name, data: data));
        if (callFailure != null) throw callFailure!;
        return callResult;
      },
      clock: () => DateTime(2026, 10, 26),
    );
  });

  group('members', () {
    test('are read live from the business', () async {
      await fs.doc('businesses/B1/members/u_owner').set({'name': 'Rajesh', 'role': 'owner', 'status': 'active'});
      await fs.doc('businesses/B2/members/other').set({'name': 'Elsewhere', 'role': 'staff', 'status': 'active'});

      final first = await source.watchMembers('B1').first;

      expect(first.map((m) => m.uid), ['u_owner']);
      expect(first.single.isOwner, isTrue);
    });

    test('follow changes', () async {
      await fs.doc('businesses/B1/members/m1').set({'name': 'Priya', 'role': 'manager', 'status': 'active'});
      final emissions = <List<String>>[];
      final sub = source.watchMembers('B1').listen((l) => emissions.add([for (final m in l) m.status]));

      await Future<void>.delayed(Duration.zero);
      await fs.doc('businesses/B1/members/m1').update({'status': 'disabled'});
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emissions.first, ['active']);
      expect(emissions.last, ['disabled']);
    });
  });

  test('properties come with their names', () async {
    await fs.doc('businesses/B1/properties/P1').set({'name': 'Sunrise Boys PG'});
    await fs.doc('businesses/B1/properties/P2').set({'status': 'draft'});

    final list = await source.loadProperties('B1');

    expect(list.map((p) => '${p.id}:${p.name}'), unorderedEquals(['P1:Sunrise Boys PG', 'P2:P2']),
        reason: 'a nameless property is shown by its id rather than as blank');
  });

  group('pending invitations', () {
    Future<void> add(String id, Map<String, Object?> extra) => fs.doc('business_invitations/$id').set({
          'businessId': 'B1',
          'phone': '+919811100001',
          'role': 'manager',
          'propertyIds': ['P1'],
          'status': 'pending',
          'createdAt': Timestamp.fromDate(DateTime(2026, 10, 24)),
          'expiresAt': Timestamp.fromDate(DateTime(2026, 10, 31)),
          ...extra,
        });

    test('are this business\'s that nobody has accepted', () async {
      await add('a', {});
      await add('b', {'status': 'accepted'});
      await add('c', {'businessId': 'B2'});
      await add('d', {'status': 'expired'});

      final list = await source.loadPendingInvites('B1');

      expect(list.map((i) => i.id), ['a']);
    });

    test('carry what the owner needs to recognise them', () async {
      await add('a', {'email': 'new@example.test', 'role': 'staff', 'propertyIds': ['P1', 'P2']});

      final i = (await source.loadPendingInvites('B1')).single;

      expect(i.phone, '+919811100001');
      expect(i.email, 'new@example.test');
      expect(i.role, 'staff');
      expect(i.propertyIds, ['P1', 'P2']);
      expect(i.expiresAt, DateTime(2026, 10, 31));
    });

    test('survive a missing date', () async {
      await fs.doc('business_invitations/x').set({'businessId': 'B1', 'phone': '+919811100002', 'role': 'staff', 'status': 'pending'});

      final i = (await source.loadPendingInvites('B1')).single;

      expect(i.expiresAt.isAfter(DateTime(2026, 10, 26)), isTrue, reason: 'unknown expiry is not treated as expired');
    });
  });

  group('access', () {
    test('says which properties each member can open', () async {
      await fs.doc('businesses/B1/properties/P1/access/m1').set({'role': 'manager'});
      await fs.doc('businesses/B1/properties/P1/access/s1').set({'role': 'staff'});
      await fs.doc('businesses/B1/properties/P2/access/m1').set({'role': 'manager'});

      final access = await source.loadAccess('B1', const [
        TeamProperty(id: 'P1', name: 'One'),
        TeamProperty(id: 'P2', name: 'Two'),
        TeamProperty(id: 'P3', name: 'Three'),
      ]);

      expect(access['m1'], {'P1', 'P2'});
      expect(access['s1'], {'P1'});
      expect(access.containsKey('nobody'), isFalse);
    });
  });

  group('inviting', () {
    const request = InviteRequest(phone: '+919811100001', email: 'a@example.test', role: 'staff', propertyIds: ['P1']);

    test('sends it to the server and returns the link', () async {
      final r = await source.invite('B1', request);

      expect(r.id, 'inv9');
      expect(r.link, 'https://app.example.test/invite?inviteId=inv9');
      expect(called.single.name, 'createBusinessInvitation');
      expect(called.single.data, {
        'businessId': 'B1',
        'phone': '+919811100001',
        'email': 'a@example.test',
        'role': 'staff',
        'propertyIds': ['P1'],
      });
    });

    test('leaves out an email that was not given', () async {
      await source.invite('B1', const InviteRequest(phone: '+919811100001', role: 'manager', propertyIds: ['P1']));

      expect(called.single.data.containsKey('email'), isFalse);
    });

    test('explains a refusal in plain words', () async {
      callFailure = FirebaseFunctionsException(code: 'permission-denied', message: 'Permission denied');

      await expectLater(
        source.invite('B1', request),
        throwsA(isA<TeamException>().having((e) => e.message, 'message', 'Only the owner can invite team members.')),
      );
    });

    test('explains that invitations are not set up on the server', () async {
      callFailure = FirebaseFunctionsException(code: 'failed-precondition', message: 'INVITE_BASE_URL not configured. Set via: ...');

      await expectLater(
        source.invite('B1', request),
        throwsA(isA<TeamException>().having((e) => e.message, 'message', contains("aren't set up"))),
      );
    });

    test('lets any other failure through for a generic message', () async {
      callFailure = Exception('network');

      await expectLater(source.invite('B1', request), throwsA(isNot(isA<TeamException>())));
    });
  });

  group('changing access', () {
    test('asks the server', () async {
      await source.updateAccess(businessId: 'B1', memberUid: 'm1', role: 'staff', propertyIds: ['P1']);

      expect(called.single.name, 'updateMemberPropertyAccess');
      expect(called.single.data, {'businessId': 'B1', 'memberUid': 'm1', 'role': 'staff', 'propertyIds': ['P1']});
    });

    test('explains when their access is off', () async {
      callFailure = FirebaseFunctionsException(code: 'failed-precondition', message: 'Member inactive');

      await expectLater(
        source.updateAccess(businessId: 'B1', memberUid: 'm1', role: 'staff', propertyIds: []),
        throwsA(isA<TeamException>().having((e) => e.message, 'message', contains('access is off'))),
      );
    });

    test('explains that the owner cannot be changed', () async {
      callFailure = FirebaseFunctionsException(code: 'failed-precondition', message: 'Owner role cannot be changed');

      await expectLater(
        source.updateAccess(businessId: 'B1', memberUid: 'o1', role: 'staff', propertyIds: []),
        throwsA(isA<TeamException>().having((e) => e.message, 'message', contains("owner's"))),
      );
    });

    test('explains a refusal', () async {
      callFailure = FirebaseFunctionsException(code: 'permission-denied', message: 'Permission denied');

      await expectLater(
        source.updateAccess(businessId: 'B1', memberUid: 'm1', role: 'staff', propertyIds: []),
        throwsA(isA<TeamException>().having((e) => e.message, 'message', 'Only the owner can change access.')),
      );
    });
  });

  group('turning access off and on', () {
    test('writes the status and who did it', () async {
      await fs.doc('businesses/B1/members/m1').set({'name': 'Priya', 'role': 'manager', 'status': 'active'});

      await source.setMemberActive('B1', 'm1', active: false);

      final d = (await fs.doc('businesses/B1/members/m1').get()).data()!;
      expect(d['status'], 'disabled');
      expect(d['updatedBy'], 'u_owner');
      expect(d['name'], 'Priya', reason: 'nothing else is touched');

      await source.setMemberActive('B1', 'm1', active: true);
      expect((await fs.doc('businesses/B1/members/m1').get()).data()!['status'], 'active');
    });
  });
}
