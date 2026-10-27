import 'dart:async';

import 'package:business/presentation/maintenance/maintenance_models.dart';
import 'package:business/presentation/maintenance/maintenance_source.dart';
import 'package:business/presentation/maintenance/maintenance_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMaintenanceSource implements MaintenanceSource {
  final controller = StreamController<List<MaintenanceItem>>.broadcast();
  final updates = <String>[];
  Object? failure;
  String? watchedBusiness;

  @override
  Stream<List<MaintenanceItem>> watch(String businessId) {
    watchedBusiness = businessId;
    return controller.stream;
  }

  @override
  Future<void> update(String id, {required MaintenanceState status, String? note, required String by}) async {
    if (failure != null) throw failure!;
    updates.add('$id:${status.wire}:${note ?? ''}:$by');
  }
}

MaintenanceItem item(String id, MaintenanceState s, {String property = 'P1', bool urgent = false, int ageHours = 1}) =>
    MaintenanceItem(
      id: id,
      title: 'Issue $id',
      status: s,
      propertyId: property,
      urgent: urgent,
      createdAt: DateTime(2026, 3, 10, 12).subtract(Duration(hours: ageHours)),
    );

void main() {
  late FakeMaintenanceSource source;
  late MaintenanceViewModel vm;
  Set<String>? scope;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    source = FakeMaintenanceSource();
    scope = null;
    vm = MaintenanceViewModel(source: source, businessId: 'BUS1', uid: 'owner1', scope: () => scope);
  });

  tearDown(() => vm.dispose());

  test('loads the business requests, urgent and open ones first', () async {
    expect(vm.loading, isTrue);
    expect(source.watchedBusiness, 'BUS1');
    source.controller.add([
      item('a', MaintenanceState.open, ageHours: 1),
      item('b', MaintenanceState.open, urgent: true, ageHours: 5),
      item('c', MaintenanceState.inProgress, ageHours: 2),
      item('d', MaintenanceState.resolved),
      item('e', MaintenanceState.cancelled),
    ]);
    await settle();
    expect(vm.loading, isFalse);
    expect(vm.visible.map((m) => m.id), ['b', 'a', 'c']);
    expect(vm.activeCount, 3);
    expect(vm.openCount, 2);
  });

  test('filters to done requests', () async {
    source.controller.add([item('a', MaintenanceState.open), item('d', MaintenanceState.resolved), item('e', MaintenanceState.cancelled)]);
    await settle();
    vm.setFilter(MaintenanceFilter.done);
    expect(vm.visible.map((m) => m.id), ['d', 'e']);
  });

  test('managers and staff only see their properties', () async {
    scope = {'P2'};
    source.controller.add([item('a', MaintenanceState.open, property: 'P1'), item('b', MaintenanceState.open, property: 'P2')]);
    await settle();
    expect(vm.visible.map((m) => m.id), ['b']);
    expect(vm.activeCount, 1);
  });

  test('starting work and resolving with a note', () async {
    source.controller.add([item('a', MaintenanceState.open)]);
    await settle();
    expect(await vm.start(vm.visible.single), isTrue);
    expect(await vm.resolve(vm.visible.single, note: ' Replaced the fan '), isTrue);
    expect(source.updates, ['a:in_progress::owner1', 'a:resolved:Replaced the fan:owner1']);
  });

  test('a failed update says so and frees the row', () async {
    source.controller.add([item('a', MaintenanceState.open)]);
    await settle();
    source.failure = Exception('denied');
    expect(await vm.start(vm.visible.single), isFalse);
    expect(vm.error, "Couldn't update the request. Try again.");
    expect(vm.isBusy('a'), isFalse);
  });

  test('a stream error is shown', () async {
    source.controller.addError(Exception('offline'));
    await settle();
    expect(vm.loading, isFalse);
    expect(vm.loadError, isNotNull);
  });
}
