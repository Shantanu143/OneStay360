import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/data/models.dart';
import 'package:tenant/data/tenant_session.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBackend backend;
  late TenantSession session;

  setUp(() {
    backend = FakeBackend();
    session = TenantSession(source: backend);
  });

  tearDown(() => session.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('starts idle with nothing loaded', () {
    expect(session.phase, SessionPhase.idle);
    expect(session.account, isNull);
    expect(session.stay, isNull);
    expect(session.hasStay, isFalse);
  });

  test('is loading until the account arrives', () async {
    session.start('u1');
    expect(session.phase, SessionPhase.loading);
    expect(session.uid, 'u1');

    backend.account.set(testAccount(tenantId: null));
    await settle();

    expect(session.phase, SessionPhase.ready);
    expect(session.displayName, 'Asha Rao');
    expect(session.hasStay, isFalse);
  });

  test('waits for the stay once there is a tenant id, then exposes it', () async {
    session.start('u1');
    backend.account.set(testAccount());
    await settle();
    expect(session.phase, SessionPhase.loading, reason: 'stay not known yet');
    expect(backend.watchedStaysFor, ['TEN1']);

    backend.stay.set(testStay);
    await settle();

    expect(session.phase, SessionPhase.ready);
    expect(session.stay!.propertyName, 'Green Nest');
    expect(session.hasStay, isTrue);
  });

  test('follows the unread count', () async {
    session.start('u1');
    backend.account.set(testAccount());
    backend.stay.set(null);
    backend.unread.set(3);
    await settle();
    expect(session.unread, 3);
    backend.unread.set(0);
    await settle();
    expect(session.unread, 0);
  });

  test('a vacated stay disappears', () async {
    session.start('u1');
    backend.account.set(testAccount());
    backend.stay.set(testStay);
    await settle();
    backend.stay.set(null);
    await settle();
    expect(session.hasStay, isFalse);
  });

  test('a missing account is still ready (bootstrap has not written it)', () async {
    session.start('u1');
    backend.account.set(null);
    await settle();
    expect(session.phase, SessionPhase.ready);
    expect(session.displayName, 'there');
  });

  test('starting again for the same user does nothing; reset clears', () async {
    session.start('u1');
    session.start('u1');
    expect(backend.account.listens, 1);

    backend.account.set(testAccount());
    backend.stay.set(testStay);
    await settle();
    session.reset();

    expect(session.phase, SessionPhase.idle);
    expect(session.account, isNull);
    expect(session.stay, isNull);
    expect(session.uid, isNull);
  });

  test('a stream error does not leave it loading forever', () async {
    session.start('u1');
    backend.account.fail(Exception('offline'));
    await settle();
    expect(session.phase, SessionPhase.ready);
    expect(session.error, isNotNull);
  });

  test('picks up a tenant id that arrives later (invitation accepted)', () async {
    session.start('u1');
    backend.account.set(testAccount(tenantId: null));
    await settle();
    expect(backend.watchedStaysFor, isEmpty);

    backend.account.set(testAccount(tenantId: 'TEN7'));
    await settle();
    expect(backend.watchedStaysFor, ['TEN7']);
    expect(session.tenantId, 'TEN7');
  });

  test('favourites come from the account', () async {
    session.start('u1');
    backend.account.set(testAccount(favorites: {'P1'}));
    await settle();
    expect(session.isFavorite('P1'), isTrue);
    expect(session.isFavorite('P2'), isFalse);
  });

  test('exposes a stay copy for widgets', () {
    expect(const Stay(id: 'a', businessId: 'b', propertyId: 'c').roomLabel, 'Room  · Bed ');
  });
}
