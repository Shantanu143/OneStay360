import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/data/models.dart';
import 'package:tenant/data/sources.dart';
import 'package:tenant/data/tenant_session.dart';
import 'package:tenant/presentation/home/activity_feed.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBackend backend;
  late TenantSession session;
  late ActivityFeed feed;
  final now = DateTime(2026, 3, 20);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  EnrollmentRequest req(String id, EnrollmentStage stage, DateTime created) =>
      EnrollmentRequest(id: id, stage: stage, createdAt: created, propertyName: id);

  setUp(() async {
    backend = FakeBackend();
    session = TenantSession(source: backend);
    feed = ActivityFeed(session: session, backend: backend, clock: () => now);
    session.start('u1');
    backend.account.set(testAccount(tenantId: null));
    await settle();
  });

  tearDown(() {
    feed.dispose();
    session.dispose();
  });

  test('the active request is the newest open one', () async {
    backend.requests.set([
      req('new-confirmed', EnrollmentStage.confirmed, DateTime(2026, 3, 10)),
      req('bill', EnrollmentStage.billSent, DateTime(2026, 3, 5)),
      req('old-pending', EnrollmentStage.pending, DateTime(2026, 1, 1)),
    ]);
    await settle();
    expect(feed.activeRequest!.id, 'bill');
    expect(feed.hasPendingRequestFor('x'), isFalse);
  });

  test('a recent rejection is shown when nothing else is open', () async {
    backend.requests.set([req('no', EnrollmentStage.rejected, DateTime(2026, 3, 15))]);
    await settle();
    expect(feed.activeRequest, isNull);
    expect(feed.recentRejection!.id, 'no');

    backend.requests.set([req('no', EnrollmentStage.rejected, DateTime(2026, 2, 1))]);
    await settle();
    expect(feed.recentRejection, isNull, reason: 'older than two weeks');
  });

  test('knows which properties already have an open request', () async {
    backend.requests.set([
      const EnrollmentRequest(id: 'a', stage: EnrollmentStage.pending, propertyId: 'P1'),
      const EnrollmentRequest(id: 'b', stage: EnrollmentStage.rejected, propertyId: 'P2'),
    ]);
    await settle();
    expect(feed.hasPendingRequestFor('P1'), isTrue);
    expect(feed.hasPendingRequestFor('P2'), isFalse);
  });

  test('loads invitations, and reloads on demand', () async {
    backend.invitations = [const PendingInvitation(id: 'I1', businessId: 'B', propertyId: 'P')];
    await feed.refreshInvitations();
    expect(feed.invitations.single.id, 'I1');

    backend.invitations = [];
    await feed.refreshInvitations();
    expect(feed.invitations, isEmpty);
  });

  test('an invitation lookup failure just shows none', () async {
    backend.listFailure = const TenantFailure('offline');
    await feed.refreshInvitations();
    expect(feed.invitations, isEmpty);
  });

  test('loads invitations once a user is known', () async {
    expect(backend.calls, contains('listInvitations'));
  });

  test('counts active maintenance requests', () async {
    backend.maintenance.set([
      const MaintenanceRequest(id: '1', title: 'a', status: MaintenanceStatus.open),
      const MaintenanceRequest(id: '2', title: 'b', status: MaintenanceStatus.inProgress),
      const MaintenanceRequest(id: '3', title: 'c', status: MaintenanceStatus.resolved),
    ]);
    await settle();
    expect(feed.activeMaintenance.length, 2);
    expect(feed.maintenance.length, 3);
  });

  test('a sign out clears everything', () async {
    backend.requests.set([req('bill', EnrollmentStage.billSent, DateTime(2026, 3, 5))]);
    await settle();
    session.reset();
    await settle();
    expect(feed.activeRequest, isNull);
    expect(feed.maintenance, isEmpty);
  });
}
