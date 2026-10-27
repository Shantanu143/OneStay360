import 'dart:async';

import 'package:business/presentation/requests/request_list_viewmodel.dart';
import 'package:business/presentation/requests/request_models.dart';
import 'package:business/presentation/requests/request_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/request_fakes.dart';

class FakeListSource implements RequestListSource {
  final controller = StreamController<List<EnrollmentRequest>>.broadcast();
  int watches = 0;
  String? lastBusiness;

  @override
  Stream<List<EnrollmentRequest>> watchAll(String businessId) {
    watches++;
    lastBusiness = businessId;
    return controller.stream;
  }
}

EnrollmentRequest req(String id, String status, {String property = 'P1', String name = 'Tenant', int day = 20}) =>
    EnrollmentRequest.fromMap(id, {
      ...requestDoc(status: status),
      'tenantName': name,
      'propertyId': property,
      'createdAt': DateTime(2026, 10, day),
    });

void main() {
  late FakeListSource source;
  late RequestListViewModel vm;

  setUp(() {
    source = FakeListSource();
    vm = RequestListViewModel(source: source, businessId: 'BUS1');
  });

  tearDown(() => vm.dispose());

  Future<void> push(List<EnrollmentRequest> list) async {
    source.controller.add(list);
    await Future<void>.delayed(Duration.zero);
  }

  group('who can see which requests', () {
    RequestListViewModel scoped(Set<String>? Function() scope, {String? property}) {
      final v = RequestListViewModel(
        source: source,
        businessId: 'BUS1',
        propertyId: property,
        propertyScope: scope,
      );
      addTearDown(v.dispose);
      return v;
    }

    final requests = [
      req('a', 'pending', property: 'P1'),
      req('b', 'pending', property: 'P2'),
      req('c', 'pending', property: 'P3'),
    ];

    test('the owner sees every request', () async {
      final v = scoped(() => null)..start();
      await push(requests);

      expect(v.visible.map((r) => r.id).toSet(), {'a', 'b', 'c'});
    });

    test('a manager sees only requests for their properties', () async {
      final v = scoped(() => {'P1', 'P3'})..start();
      await push(requests);

      expect(v.visible.map((r) => r.id).toSet(), {'a', 'c'});
    });

    test('someone given nothing sees none', () async {
      final v = scoped(() => <String>{})..start();
      await push(requests);

      expect(v.visible, isEmpty);
    });

    test('a request for one property still has to be in their scope', () async {
      final v = scoped(() => {'P1'}, property: 'P2')..start();
      await push(requests);

      expect(v.visible, isEmpty);
    });
  });

  test('loads for the business', () async {
    vm.start();
    expect(vm.loading, isTrue);

    await push([req('a', 'pending')]);

    expect(source.lastBusiness, 'BUS1');
    expect(vm.loading, isFalse);
    expect(vm.visible, hasLength(1));
  });

  test('opens on "Needs you" when something needs the owner', () async {
    vm.start();
    await push([req('a', 'pending'), req('b', 'bill_sent'), req('c', 'payment_submitted')]);

    expect(vm.filter, RequestFilter.needsYou);
    expect(vm.visible.map((r) => r.id), ['a', 'c']);
  });

  test('opens on All when nothing needs the owner', () async {
    vm.start();
    await push([req('b', 'bill_sent'), req('d', 'confirmed')]);

    expect(vm.filter, RequestFilter.all);
    expect(vm.visible, hasLength(2));
  });

  test('counts each filter', () async {
    vm.start();
    await push([
      req('a', 'pending'),
      req('b', 'bill_sent'),
      req('c', 'payment_submitted'),
      req('d', 'confirmed'),
      req('e', 'rejected'),
      req('f', 'approved'),
    ]);

    expect(vm.count(RequestFilter.needsYou), 2);
    expect(vm.count(RequestFilter.waiting), 2, reason: 'bill sent + approved');
    expect(vm.count(RequestFilter.done), 2);
    expect(vm.count(RequestFilter.all), 6);
  });

  test('switching filters changes what is shown, newest first', () async {
    vm.start();
    await push([
      req('old', 'confirmed', day: 3),
      req('new', 'confirmed', day: 25),
      req('mid', 'rejected', day: 12),
    ]);

    vm.setFilter(RequestFilter.done);
    expect(vm.visible.map((r) => r.id), ['new', 'mid', 'old']);

    vm.setFilter(RequestFilter.needsYou);
    expect(vm.visible, isEmpty);
  });

  test('a request that could not be completed needs the owner', () async {
    vm.start();
    await push([req('a', 'approval_failed'), req('b', 'bill_sent')]);

    expect(vm.filter, RequestFilter.needsYou);
    expect(vm.visible.map((r) => r.id), ['a']);
  });

  test('can be limited to one property', () async {
    vm = RequestListViewModel(source: source, businessId: 'BUS1', propertyId: 'P2')..start();
    await push([req('a', 'pending', property: 'P1'), req('b', 'pending', property: 'P2')]);

    expect(vm.visible.map((r) => r.id), ['b']);
    expect(vm.count(RequestFilter.all), 1);
  });

  test('keeps the chosen filter when the list changes', () async {
    vm.start();
    await push([req('a', 'pending'), req('d', 'confirmed')]);
    vm.setFilter(RequestFilter.all);

    await push([req('a', 'pending'), req('d', 'confirmed'), req('e', 'pending')]);

    expect(vm.filter, RequestFilter.all);
    expect(vm.visible, hasLength(3));
  });

  test('reports a failure and can retry', () async {
    vm.start();
    source.controller.addError(Exception('denied'));
    await Future<void>.delayed(Duration.zero);

    expect(vm.error, "Couldn't load requests.");

    vm.retry();
    expect(source.watches, 2);
    expect(vm.error, isNull);
    expect(vm.loading, isTrue);
  });

  test('stops listening on dispose', () {
    vm.start();
    vm.dispose();

    expect(source.controller.hasListener, isFalse);
    vm = RequestListViewModel(source: source, businessId: 'BUS1');
  });
}
