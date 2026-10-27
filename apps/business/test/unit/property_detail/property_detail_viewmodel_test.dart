import 'package:business/presentation/property_detail/property_detail_models.dart';
import 'package:business/presentation/property_detail/property_detail_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/business/property/property_room_model.dart';

import '../../support/detail_fakes.dart';
import '../../support/property_fixtures.dart';

PropertyRoom room(String number, String floor, int sharing, {bool ac = false}) => PropertyRoom(
      roomNumber: number,
      floor: floor,
      occupancyType: '$sharing',
      sharingType: sharing,
      hasAC: ac,
    );

void main() {
  late FakeDetailSource source;
  late PropertyDetailViewModel vm;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 10, 26, 12);
    source = FakeDetailSource()
      ..prop = makeProperty(id: 'P1', name: 'Skyline', status: 'active')
      ..roomList = [room('101', '1', 2), room('102', '1', 3), room('201', '2', 2, ac: true)]
      ..tenantList = [
        tenant('T1', name: 'Amit Patel', phone: '+91 98765 43210', room: '101', bed: '1', rent: 6500),
        tenant('T2', name: 'Neha Verma', phone: '9811122233', room: '102', bed: '2', rent: 5000),
      ];
    vm = PropertyDetailViewModel(source: source, clock: () => now);
  });

  tearDown(() => vm.dispose());

  group('core', () {
    test('loads the property, layout, tenants and stats together', () async {
      await vm.load('P1');

      expect(vm.loading, isFalse);
      expect(vm.error, isNull);
      expect(vm.property?.name, 'Skyline');
      expect(vm.tenants, hasLength(2));
      expect(vm.floors.map((f) => f.floor), ['1', '2']);
      expect(vm.stats.totalRooms, 3);
      expect(vm.stats.totalBeds, 7);
      expect(vm.stats.occupiedBeds, 2);
      expect(vm.stats.occupiedRooms, 2);
      expect(vm.stats.vacantBeds, 5);
      expect(vm.stats.occupancy, closeTo(2 / 7, 1e-9));
      expect(vm.stats.expectedMonthlyRent, 11500);
    });

    test('says who sleeps in which bed', () async {
      await vm.load('P1');

      expect(vm.occupantAt('101', '1')?.name, 'Amit Patel');
      expect(vm.occupantAt('102', '2')?.name, 'Neha Verma');
      expect(vm.occupantAt('102', '1'), isNull);
    });

    test('reports a missing property', () async {
      source.prop = null;
      await vm.load('P1');

      expect(vm.error, 'Property not found');
      expect(vm.property, isNull);
    });

    test('reports a failure and a retry recovers', () async {
      source.coreFailure = Exception('offline');
      await vm.load('P1');
      expect(vm.error, isNotNull);

      source.coreFailure = null;
      await vm.load('P1');
      expect(vm.error, isNull);
      expect(vm.property, isNotNull);
    });

    test('a property with no rooms still loads', () async {
      source.roomList = const [];
      source.tenantList = const [];
      await vm.load('P1');

      expect(vm.floors, isEmpty);
      expect(vm.stats.totalBeds, 0);
      expect(vm.stats.occupancy, 0);
    });

    test('an empty property id is rejected', () async {
      await vm.load('');
      expect(vm.error, isNotNull);
      expect(source.propertyCalls, 0);
    });
  });

  group('tenants', () {
    setUp(() => vm.load('P1'));

    test('are listed by room then bed', () async {
      source.tenantList = [
        tenant('T3', name: 'C', room: '102', bed: '1'),
        tenant('T1', name: 'A', room: '101', bed: '2'),
        tenant('T2', name: 'B', room: '101', bed: '1'),
      ];
      await vm.load('P1');

      expect(vm.visibleTenants.map((t) => t.id), ['T2', 'T1', 'T3']);
    });

    test('search matches name, room and phone digits', () {
      vm.setSearch('amit');
      expect(vm.visibleTenants.map((t) => t.id), ['T1']);

      vm.setSearch('102');
      expect(vm.visibleTenants.map((t) => t.id), ['T2']);

      vm.setSearch('98765 43210');
      expect(vm.visibleTenants.map((t) => t.id), ['T1']);

      vm.setSearch('  ');
      expect(vm.visibleTenants, hasLength(2));
    });

    test('a query with no match leaves the list empty', () {
      vm.setSearch('zzz');
      expect(vm.visibleTenants, isEmpty);
    });

    test('a tenant converts to what the detail screen expects', () {
      final map = vm.tenants.first.toDetailMap(businessId: 'BUS1', propertyId: 'P1');
      expect(map['name'], 'Amit Patel');
      expect(map['room'], '101');
      expect(map['bed'], '1');
      expect(map['businessId'], 'BUS1');
      expect(map['propertyId'], 'P1');
      expect(map['status'], 'Active');
      expect(map['rent'], 6500);
    });

    test('unknown contact details are left out, not filled with placeholder text', () {
      final bare = PropertyTenant(
        id: 'T9',
        name: 'No Contact',
        phone: '',
        roomId: '101',
        bedId: '2',
        monthlyRent: 5000,
        status: 'active',
      );

      final map = bare.toDetailMap(businessId: 'BUS1', propertyId: 'P1');

      expect(map['phone'], isNull);
      expect(map['email'], isNull);
      expect(map['joinDate'], isNull);
    });
  });

  group('requests', () {
    setUp(() => vm.load('P1'));

    test('are live, newest first, with a pending count', () async {
      vm.listenRequests('P1');
      source.requestsController.add([
        request('a', 'pending', at: DateTime(2026, 10, 1)),
        request('b', 'confirmed', at: DateTime(2026, 10, 25)),
        request('c', 'pending', at: DateTime(2026, 10, 20)),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(vm.requests.map((r) => r.id), ['b', 'c', 'a']);
      expect(vm.pendingRequestsCount, 2);
      expect(vm.requestsLoading, isFalse);
    });

    test('update when a request changes', () async {
      vm.listenRequests('P1');
      source.requestsController.add([request('a', 'pending')]);
      await Future<void>.delayed(Duration.zero);
      expect(vm.pendingRequestsCount, 1);

      source.requestsController.add([request('a', 'approved')]);
      await Future<void>.delayed(Duration.zero);
      expect(vm.pendingRequestsCount, 0);
    });

    test('a stream error is surfaced', () async {
      vm.listenRequests('P1');
      source.requestsController.addError(Exception('denied'));
      await Future<void>.delayed(Duration.zero);

      expect(vm.requestsError, isNotNull);
      expect(vm.requestsLoading, isFalse);
    });

    test('listening twice does not duplicate', () async {
      vm.listenRequests('P1');
      vm.listenRequests('P1');
      source.requestsController.add([request('a', 'pending')]);
      await Future<void>.delayed(Duration.zero);

      expect(vm.requests, hasLength(1));
    });

    test('statuses read in plain words', () {
      expect(RequestStatus.ofStatus('pending').label, 'Pending');
      expect(RequestStatus.ofStatus('approved').label, 'Approved');
      expect(RequestStatus.ofStatus('bill_sent').label, 'Bill sent');
      expect(RequestStatus.ofStatus('approval_failed').label, "Couldn't add tenant");
      expect(RequestStatus.ofStatus('payment_submitted').label, 'Payment to confirm');
      expect(RequestStatus.ofStatus('confirmed').tone, 'success');
      expect(RequestStatus.ofStatus('rejected').tone, 'danger');
      expect(RequestStatus.ofStatus('weird_new').label, 'Weird new');
    });
  });

  group('billing (loaded when the tab is opened)', () {
    setUp(() => vm.load('P1'));

    test('is not fetched up front', () {
      expect(source.billingCalls, 0);
    });

    test('loads once and caches', () async {
      source.payments = [
        {'id': 'p1', 'status': 'success', 'amount': 1500},
      ];
      await vm.ensureBilling();
      await vm.ensureBilling();

      expect(source.billingCalls, 1);
      expect(vm.payments, hasLength(1));
    });

    test('fetches the unpaid invoice only when payment is due', () async {
      await vm.ensureBilling();
      expect(source.unpaidCalls, 0);

      source.prop = makeProperty(id: 'P1', status: 'active').copyWith(billingStatus: 'past_due');
      source.unpaid = 'INV1';
      await vm.load('P1');
      await vm.ensureBilling(force: true);

      expect(vm.unpaidInvoiceId, 'INV1');
    });

    test('a failure is reported and can be retried', () async {
      source.billingFailure = Exception('denied');
      await vm.ensureBilling();
      expect(vm.billingError, isNotNull);

      source.billingFailure = null;
      await vm.ensureBilling();
      expect(vm.billingError, isNull);
    });

    test('billing status is described for the header', () {
      expect(BillingStatusView.of('paid').label, 'Billing active');
      expect(BillingStatusView.of('paid').canPay, isFalse);
      expect(BillingStatusView.of('due').canPay, isTrue);
      expect(BillingStatusView.of('grace').label, 'Payment due');
      expect(BillingStatusView.of('past_due').tone, 'warning');
      expect(BillingStatusView.of('suspended').tone, 'danger');
      expect(BillingStatusView.of('suspended').canPay, isTrue);
      expect(BillingStatusView.of('payment_due').label, 'Activation pending');
    });
  });

  group('analytics (loaded when the tab is opened)', () {
    setUp(() => vm.load('P1'));

    test('sums this month\'s invoices for the property\'s tenants', () async {
      source.invoices = [
        const InvoiceSummary(tenantId: 'T1', amount: 6500, status: 'paid'),
        InvoiceSummary(
            tenantId: 'T2', amount: 5000, status: 'unpaid', dueDate: DateTime(2026, 10, 3)),
        InvoiceSummary(
            tenantId: 'T3', amount: 4000, status: 'unpaid', dueDate: DateTime(2026, 10, 30)),
      ];
      await vm.ensureAnalytics();

      expect(source.lastPeriod, '2026-10');
      expect(source.lastInvoiceTenants, ['T1', 'T2']);
      expect(vm.collection.expected, 15500);
      expect(vm.collection.collected, 6500);
      expect(vm.collection.outstanding, 9000);
      expect(vm.collection.paidCount, 1);
      expect(vm.collection.unpaidCount, 2);
      expect(vm.collection.overdueCount, 1, reason: 'only the one past its due date');
      expect(vm.collection.rate, closeTo(6500 / 15500, 1e-9));
    });

    test('an invoice marked overdue counts as overdue', () async {
      source.invoices = [
        const InvoiceSummary(tenantId: 'T1', amount: 100, status: 'overdue'),
      ];
      await vm.ensureAnalytics();
      expect(vm.collection.overdueCount, 1);
    });

    test('is skipped (and empty) when nobody lives there', () async {
      source.tenantList = const [];
      await vm.load('P1');
      await vm.ensureAnalytics();

      expect(source.invoiceCalls, 0);
      expect(vm.collection.hasInvoices, isFalse);
    });

    test('loads once, then only on a forced refresh', () async {
      await vm.ensureAnalytics();
      await vm.ensureAnalytics();
      expect(source.invoiceCalls, 1);

      await vm.ensureAnalytics(force: true);
      expect(source.invoiceCalls, 2);
    });

    test('a failure is reported without breaking the rest', () async {
      source.invoicesFailure = Exception('denied');
      await vm.ensureAnalytics();

      expect(vm.analyticsError, isNotNull);
      expect(vm.property, isNotNull);
    });
  });

  group('tabs', () {
    setUp(() => vm.load('P1'));

    test('selecting the analytics or payments tab triggers its load', () async {
      vm.selectTab(PropertyDetailTab.analytics);
      await Future<void>.delayed(Duration.zero);
      expect(source.invoiceCalls, 1);

      vm.selectTab(PropertyDetailTab.payments);
      await Future<void>.delayed(Duration.zero);
      expect(source.billingCalls, 1);
    });

    test('a tab chosen before the property arrives loads once it does', () async {
      vm.dispose();
      vm = PropertyDetailViewModel(source: source, clock: () => now);

      vm.selectTab(PropertyDetailTab.payments); // e.g. opened from a notification
      expect(source.billingCalls, 0, reason: 'nothing to bill yet');

      await vm.load('P1');
      await Future<void>.delayed(Duration.zero);

      expect(source.billingCalls, 1);
      expect(vm.payments, isEmpty);
      expect(vm.billingLoading, isFalse);
    });

    test('tab indexes stay stable for deep links', () {
      expect(PropertyDetailTab.values.indexOf(PropertyDetailTab.overview), 0);
      expect(PropertyDetailTab.values.indexOf(PropertyDetailTab.payments), 4);
      expect(PropertyDetailTab.values.indexOf(PropertyDetailTab.requests), 5);
    });

    test('refresh reloads the core and anything already opened', () async {
      vm.selectTab(PropertyDetailTab.analytics);
      await Future<void>.delayed(Duration.zero);

      await vm.refresh('P1');

      expect(source.propertyCalls, 2);
      expect(source.invoiceCalls, 2);
      expect(source.billingCalls, 0, reason: 'payments tab was never opened');
    });
  });

  test('disposing cancels the requests subscription', () async {
    await vm.load('P1');
    vm.listenRequests('P1');
    expect(source.requestsController.hasListener, isTrue);

    vm.dispose();

    expect(source.requestsController.hasListener, isFalse);
    vm = PropertyDetailViewModel(source: source); // for tearDown
  });
}
