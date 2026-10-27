import 'package:flutter_test/flutter_test.dart';
import 'package:models/business/property/property_model.dart';
import 'package:tenant/data/sources.dart';
import 'package:tenant/presentation/explore/explore_viewmodel.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBackend backend;
  late Set<String> favorites;
  late ExploreViewModel vm;

  final girls = testProperty(id: 'G', name: 'Lotus Girls PG', single: 11000, double: 8000, gender: 'female', rating: 4.8);
  final boys = testProperty(id: 'B', name: 'Raja Boys Hostel', single: 14000, double: 12000, gender: 'Male', rating: 4.0, featured: true);
  final coed = testProperty(id: 'C', name: 'City Nest', single: 9500, double: 0, gender: 'co-ed', rating: 4.2, updatedAt: DateTime(2026, 2, 1));

  setUp(() {
    backend = FakeBackend();
    favorites = {};
    backend.pages['Pune'] = [
      PropertyPage([girls, boys]),
      PropertyPage([coed]),
    ];
    vm = ExploreViewModel(source: backend, favorites: () => favorites, initialCity: 'Pune');
  });

  tearDown(() => vm.dispose());

  test('loads the first page of the city', () async {
    await vm.load();
    expect(vm.visible.map((p) => p.id), ['G', 'B']);
    expect(vm.hasMore, isTrue);
    expect(vm.loading, isFalse);
  });

  test('loads more pages and stops at the end', () async {
    await vm.load();
    await vm.loadMore();
    expect(vm.visible.map((p) => p.id), ['G', 'B', 'C']);
    expect(vm.hasMore, isFalse);
    await vm.loadMore();
    expect(backend.calls.where((c) => c.startsWith('loadCity')).length, 2);
  });

  test('changing city starts over', () async {
    backend.pages['Mumbai'] = [PropertyPage([coed])];
    await vm.load();
    await vm.setCity('Mumbai');
    expect(vm.city, 'Mumbai');
    expect(vm.visible.map((p) => p.id), ['C']);
  });

  test('searches name, address and landmarks', () async {
    await vm.load();
    await vm.loadMore();
    vm.setQuery('lotus');
    expect(vm.visible.map((p) => p.id), ['G']);
    vm.setQuery('  metro ');
    expect(vm.visible.length, 3);
    vm.setQuery('');
    expect(vm.visible.length, 3);
  });

  test('filters by gender, budget, featured and saved', () async {
    await vm.load();
    await vm.loadMore();

    vm.setFilter(ExploreFilter.girls);
    expect(vm.visible.map((p) => p.id), ['G']);
    vm.setFilter(ExploreFilter.boys);
    expect(vm.visible.map((p) => p.id), ['B']);
    vm.setFilter(ExploreFilter.coed);
    expect(vm.visible.map((p) => p.id), ['C']);
    vm.setFilter(ExploreFilter.budget);
    expect(vm.visible.map((p) => p.id), ['G', 'C']);
    vm.setFilter(ExploreFilter.featured);
    expect(vm.visible.map((p) => p.id), ['B']);

    favorites.add('C');
    vm.setFilter(ExploreFilter.saved);
    expect(vm.visible.map((p) => p.id), ['C']);
  });

  test('sorts by price and rating', () async {
    await vm.load();
    await vm.loadMore();
    vm.setSort(ExploreSort.priceLow);
    expect(vm.visible.map((p) => p.id), ['G', 'C', 'B']);
    vm.setSort(ExploreSort.priceHigh);
    expect(vm.visible.map((p) => p.id), ['B', 'C', 'G']);
    vm.setSort(ExploreSort.rating);
    expect(vm.visible.map((p) => p.id), ['G', 'C', 'B']);
  });

  test('a load failure is explained and can be retried', () async {
    backend.failure = Exception('offline');
    await vm.load();
    expect(vm.error, isNotNull);
    expect(vm.visible, isEmpty);
    backend.failure = null;
    await vm.load();
    expect(vm.error, isNull);
    expect(vm.visible.length, 2);
  });

  test('saving a PG goes to the account', () async {
    await vm.toggleFavorite('u1', girls);
    expect(backend.favorites, {'G'});
    favorites.add('G');
    await vm.toggleFavorite('u1', girls);
    expect(backend.favorites, isEmpty);
  });

  group('price and labels', () {
    test('lowest price across sharing options, AC and non-AC', () {
      final p = Property.fromMap({
        'pricing': {
          'single': 0,
          'double': 0,
          'triple': 0,
          'maxSharing': 3,
          'sharing': [
            {'sharing': 1, 'nonAc': 9000, 'ac': 11000},
            {'sharing': 2, 'nonAc': 7000},
          ],
        },
      }, 'X');
      expect(ExploreViewModel.minPrice(p), 7000);
      expect(ExploreViewModel.priceLabel(p), 'from ₹7,000');
      expect(ExploreViewModel.minPrice(Property.fromMap({}, 'Y')), 0);
      expect(ExploreViewModel.priceLabel(Property.fromMap({}, 'Y')), 'Price on request');
    });

    test('gender labels', () {
      expect(ExploreViewModel.genderLabel(girls), 'Girls');
      expect(ExploreViewModel.genderLabel(boys), 'Boys');
      expect(ExploreViewModel.genderLabel(coed), 'Co-ed');
    });
  });
}
