import 'package:business/presentation/view_models/business_dashboard_viewmodel.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'business_dashboard_viewmodel_test.mocks.dart';

void main() {
  late MockPropertyRepository repo;
  late BusinessDashboardViewModel vm;
  late DateTime now;

  setUp(() {
    repo = MockPropertyRepository();
    when(repo.getPropertiesByBusiness('BUS1')).thenAnswer((_) async => []);
    now = DateTime(2026, 10, 26, 12);
    vm = BusinessDashboardViewModel(
      propertyRepository: repo,
      firestore: FakeFirebaseFirestore(),
      clock: () => now,
    );
  });

  tearDown(() => vm.dispose());

  test('records when it last loaded', () async {
    expect(vm.loadedAt, isNull);

    await vm.loadDashboardMetrics('BUS1');

    expect(vm.loadedAt, now);
  });

  test('refreshIfStale loads when nothing has been loaded yet', () async {
    await vm.refreshIfStale('BUS1', maxAge: const Duration(minutes: 1));

    verify(repo.getPropertiesByBusiness('BUS1')).called(1);
  });

  test('refreshIfStale leaves fresh data alone', () async {
    await vm.loadDashboardMetrics('BUS1');
    now = now.add(const Duration(seconds: 30));

    await vm.refreshIfStale('BUS1', maxAge: const Duration(minutes: 1));

    verify(repo.getPropertiesByBusiness('BUS1')).called(1);
  });

  test('refreshIfStale reloads once the data is older than maxAge', () async {
    await vm.loadDashboardMetrics('BUS1');
    now = now.add(const Duration(minutes: 2));

    await vm.refreshIfStale('BUS1', maxAge: const Duration(minutes: 1));

    verify(repo.getPropertiesByBusiness('BUS1')).called(2);
    expect(vm.loadedAt, now);
  });

  test(
    'a silent refresh keeps showing the old numbers (no loading flash)',
    () async {
      await vm.loadDashboardMetrics('BUS1');
      now = now.add(const Duration(minutes: 5));

      final refresh = vm.refreshIfStale(
        'BUS1',
        maxAge: const Duration(minutes: 1),
      );

      expect(
        vm.hasLoaded,
        isTrue,
        reason: 'UI keeps its content during refresh',
      );
      await refresh;
    },
  );
}
