import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/data/models.dart';
import 'package:tenant/presentation/notifications/notifications_viewmodel.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBackend backend;
  late NotificationsViewModel vm;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    backend = FakeBackend();
    vm = NotificationsViewModel(source: backend, tenantId: 'TEN1');
  });

  tearDown(() => vm.dispose());

  test('lists notifications and counts unread', () async {
    expect(vm.loading, isTrue);
    backend.notifications.set(const [
      TenantNotification(id: 'a', type: 'bill_received', title: 'Pay', read: false),
      TenantNotification(id: 'b', type: 'tenant_invitation', title: 'Invite', read: true),
    ]);
    await settle();
    expect(vm.loading, isFalse);
    expect(vm.items.length, 2);
    expect(vm.unreadCount, 1);
  });

  test('opening one marks it read', () async {
    backend.notifications.set(const [TenantNotification(id: 'a', type: 'x', title: 'Pay')]);
    await settle();
    await vm.markRead(vm.items.first);
    expect(backend.markedRead, ['a']);
  });

  test('opening a read one writes nothing', () async {
    backend.notifications.set(const [TenantNotification(id: 'a', type: 'x', title: 'Pay', read: true)]);
    await settle();
    await vm.markRead(vm.items.first);
    expect(backend.markedRead, isEmpty);
  });

  test('marks all unread as read at once', () async {
    backend.notifications.set(const [
      TenantNotification(id: 'a', type: 'x', title: '1'),
      TenantNotification(id: 'b', type: 'x', title: '2', read: true),
      TenantNotification(id: 'c', type: 'x', title: '3'),
    ]);
    await settle();
    await vm.markAllRead();
    expect(backend.markedRead, ['a', 'c']);
  });

  test('without a tenant id there is simply nothing', () async {
    final none = NotificationsViewModel(source: backend, tenantId: null);
    expect(none.loading, isFalse);
    expect(none.items, isEmpty);
    none.dispose();
  });
}
