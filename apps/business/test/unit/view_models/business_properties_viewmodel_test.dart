import 'package:business/presentation/view_models/business_properties_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../support/property_fixtures.dart';
import 'business_dashboard_viewmodel_test.mocks.dart';

void main() {
  late MockPropertyRepository repo;
  late BusinessPropertiesViewModel vm;

  setUp(() {
    repo = MockPropertyRepository();
    vm = BusinessPropertiesViewModel(propertyRepository: repo);
  });

  tearDown(() => vm.dispose());

  void stubProperties(List<dynamic> list) => when(
    repo.getPropertiesByBusiness('BUS1'),
  ).thenAnswer((_) async => List.from(list));

  group('which properties are listed', () {
    BusinessPropertiesViewModel scoped(Set<String>? Function() scope) =>
        BusinessPropertiesViewModel(propertyRepository: repo, propertyScope: scope);

    test('everything for the owner (no scope)', () async {
      stubProperties([makeProperty(id: 'a'), makeProperty(id: 'b'), makeProperty(id: 'c')]);
      final owner = scoped(() => null);
      addTearDown(owner.dispose);

      await owner.loadProperties('BUS1');

      expect(owner.properties.map((p) => p.id), ['a', 'b', 'c']);
    });

    test('only what a manager was given', () async {
      stubProperties([makeProperty(id: 'a'), makeProperty(id: 'b'), makeProperty(id: 'c')]);
      final manager = scoped(() => {'a', 'c'});
      addTearDown(manager.dispose);

      await manager.loadProperties('BUS1');

      expect(manager.properties.map((p) => p.id), ['a', 'c']);
      expect(manager.summaryLine, '2 properties · Pune');
      expect(manager.countFor(PropertyStatusFilter.all), 2);
    });

    test('nothing for someone given nothing', () async {
      stubProperties([makeProperty(id: 'a')]);
      final nobody = scoped(() => <String>{});
      addTearDown(nobody.dispose);

      await nobody.loadProperties('BUS1');

      expect(nobody.properties, isEmpty);
      expect(nobody.summaryLine, 'No properties yet');
    });

    test('drafts they were not given are not counted', () async {
      stubProperties([makeProperty(id: 'a', status: 'draft'), makeProperty(id: 'b', status: 'active')]);
      final manager = scoped(() => {'b'});
      addTearDown(manager.dispose);

      await manager.loadProperties('BUS1');

      expect(manager.draftCount, 0);
    });

    test('follows the scope as it is when the list is refreshed', () async {
      stubProperties([makeProperty(id: 'a'), makeProperty(id: 'b')]);
      var scope = <String>{'a'};
      final manager = scoped(() => scope);
      addTearDown(manager.dispose);
      await manager.loadProperties('BUS1');
      expect(manager.properties.map((p) => p.id), ['a']);

      scope = {'a', 'b'};
      await manager.refreshProperties('BUS1');

      expect(manager.properties.map((p) => p.id), ['a', 'b']);
    });
  });

  group('beds in use', () {
    BusinessPropertiesViewModel withCounts(Future<Map<String, int>> Function(String) loader) =>
        BusinessPropertiesViewModel(propertyRepository: repo, occupancyLoader: loader);

    test('come from the property\'s stored counter when nothing better is known', () async {
      stubProperties([makeProperty(id: 'a', beds: 10, availableBeds: 4)]);
      await vm.loadProperties('BUS1');

      expect(vm.occupiedBedsOf(vm.properties.single), 6);
    });

    test('are the active tenants when they can be counted, whatever the stored counter says', () async {
      stubProperties([makeProperty(id: 'a', beds: 10, availableBeds: 10)]);
      final counted = withCounts((_) async => {'a': 3});
      addTearDown(counted.dispose);

      await counted.loadProperties('BUS1');

      expect(counted.occupiedBedsOf(counted.properties.single), 3);
      expect(counted.getOccupancyRate(counted.properties.single), closeTo(0.3, 1e-9));
    });

    test('are zero for a property with no active tenants', () async {
      stubProperties([makeProperty(id: 'a', beds: 10, availableBeds: 2)]);
      final counted = withCounts((_) async => {'other': 5});
      addTearDown(counted.dispose);

      await counted.loadProperties('BUS1');

      expect(counted.occupiedBedsOf(counted.properties.single), 0);
    });

    test('never exceed the beds there are', () async {
      stubProperties([makeProperty(id: 'a', beds: 4, availableBeds: 4)]);
      final counted = withCounts((_) async => {'a': 9});
      addTearDown(counted.dispose);

      await counted.loadProperties('BUS1');

      expect(counted.occupiedBedsOf(counted.properties.single), 4);
    });

    test('fall back to the stored counter, and the properties still load, when counting fails', () async {
      stubProperties([makeProperty(id: 'a', beds: 10, availableBeds: 4)]);
      final counted = withCounts((_) async => throw Exception('denied'));
      addTearDown(counted.dispose);

      await counted.loadProperties('BUS1');

      expect(counted.properties, hasLength(1));
      expect(counted.hasError, isFalse);
      expect(counted.occupiedBedsOf(counted.properties.single), 6);
    });

    test('are counted again on refresh', () async {
      stubProperties([makeProperty(id: 'a', beds: 10, availableBeds: 10)]);
      var live = {'a': 3};
      final counted = withCounts((_) async => live);
      addTearDown(counted.dispose);
      await counted.loadProperties('BUS1');

      live = {'a': 5};
      await counted.refreshProperties('BUS1');

      expect(counted.occupiedBedsOf(counted.properties.single), 5);
    });

    test('sorting by occupancy uses the counted beds', () async {
      stubProperties([
        makeProperty(id: 'low', name: 'Low', beds: 10, availableBeds: 0),
        makeProperty(id: 'high', name: 'High', beds: 10, availableBeds: 10),
      ]);
      final counted = withCounts((_) async => {'low': 1, 'high': 9});
      addTearDown(counted.dispose);
      await counted.loadProperties('BUS1');

      counted.updateSortOption(PropertySortOption.occupancy);

      expect(counted.filteredProperties.map((p) => p.id), ['high', 'low']);
    });
  });

  group('summary line', () {
    test('says so when there are no properties', () async {
      stubProperties([]);
      await vm.loadProperties('BUS1');
      expect(vm.summaryLine, 'No properties yet');
    });

    test('names the city when every property is in one', () async {
      stubProperties([makeProperty(id: 'a'), makeProperty(id: 'b')]);
      await vm.loadProperties('BUS1');
      expect(vm.summaryLine, '2 properties · Pune');
    });

    test('uses the singular for one property', () async {
      stubProperties([makeProperty()]);
      await vm.loadProperties('BUS1');
      expect(vm.summaryLine, '1 property · Pune');
    });

    test('counts cities when properties are spread out', () async {
      stubProperties([
        makeProperty(id: 'a', city: 'Pune'),
        makeProperty(id: 'b', city: 'Mumbai'),
        makeProperty(id: 'c', city: 'pune '),
      ]);
      await vm.loadProperties('BUS1');
      expect(vm.summaryLine, '3 properties · 2 cities');
    });
  });

  group('filters', () {
    setUp(() async {
      stubProperties([
        makeProperty(id: 'a', status: 'active'),
        makeProperty(id: 'b', status: 'active'),
        makeProperty(id: 'c', status: 'vacant'),
        makeProperty(id: 'd', status: 'maintenance'),
        makeProperty(id: 'e', status: 'draft'),
      ]);
      await vm.loadProperties('BUS1');
    });

    test('counts per filter', () {
      expect(vm.countFor(PropertyStatusFilter.all), 5);
      expect(vm.countFor(PropertyStatusFilter.active), 2);
      expect(vm.countFor(PropertyStatusFilter.vacant), 1);
      expect(vm.countFor(PropertyStatusFilter.maintenance), 1);
      expect(vm.countFor(PropertyStatusFilter.draft), 1);
    });

    test('filters by status', () {
      vm.updateStatusFilter(PropertyStatusFilter.active);
      expect(
        vm.filteredProperties.map((p) => p.id),
        unorderedEquals(['a', 'b']),
      );

      vm.updateStatusFilter(PropertyStatusFilter.draft);
      expect(vm.filteredProperties.map((p) => p.id), ['e']);
    });

    test('exposes the draft count for the banner', () {
      expect(vm.draftCount, 1);
      expect(vm.firstDraft?.id, 'e');
    });

    test('has no banner without drafts', () async {
      stubProperties([makeProperty()]);
      await vm.refreshProperties('BUS1');
      expect(vm.draftCount, 0);
      expect(vm.firstDraft, isNull);
    });
  });

  group('search', () {
    setUp(() async {
      stubProperties([
        makeProperty(
          id: 'a',
          name: 'Green Valley',
          address: 'Baner Rd',
          city: 'Pune',
        ),
        makeProperty(
          id: 'b',
          name: 'Sunrise Boys PG',
          address: 'Kothrud',
          city: 'Pune',
        ),
        makeProperty(
          id: 'c',
          name: 'Lake View',
          address: 'Powai',
          city: 'Mumbai',
        ),
      ]);
      await vm.loadProperties('BUS1');
    });

    test('matches name, address and city, ignoring case and padding', () {
      vm.updateSearchQuery('  sunrise ');
      expect(vm.filteredProperties.map((p) => p.id), ['b']);

      vm.updateSearchQuery('POWAI');
      expect(vm.filteredProperties.map((p) => p.id), ['c']);

      vm.updateSearchQuery('mumbai');
      expect(vm.filteredProperties.map((p) => p.id), ['c']);
    });

    test('combines with the status filter', () {
      vm.updateSearchQuery('pune');
      expect(vm.filteredProperties, hasLength(2));
      vm.updateStatusFilter(PropertyStatusFilter.vacant);
      expect(vm.filteredProperties, isEmpty);
    });

    test('a blank query shows everything', () {
      vm.updateSearchQuery('   ');
      expect(vm.filteredProperties, hasLength(3));
    });
  });

  group('sorting', () {
    setUp(() async {
      stubProperties([
        makeProperty(
          id: 'old',
          beds: 10,
          availableBeds: 1,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 3, 1),
        ),
        makeProperty(
          id: 'new',
          beds: 10,
          availableBeds: 9,
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 2, 1),
        ),
        makeProperty(
          id: 'full',
          beds: 10,
          availableBeds: 0,
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 4, 1),
        ),
      ]);
      await vm.loadProperties('BUS1');
    });

    test('recently updated first by default', () {
      expect(vm.filteredProperties.map((p) => p.id), ['full', 'old', 'new']);
    });

    test('newest first', () {
      vm.updateSortOption(PropertySortOption.newest);
      expect(vm.filteredProperties.map((p) => p.id), ['new', 'full', 'old']);
    });

    test('most occupied first', () {
      vm.updateSortOption(PropertySortOption.occupancy);
      expect(vm.filteredProperties.map((p) => p.id), ['full', 'old', 'new']);
    });
  });

  group('rent range', () {
    test('formats a spread in thousands', () {
      final p = makeProperty(single: 12000, double: 8000, triple: 6500);
      expect(vm.rentRange(p), '₹6.5K–12K');
    });

    test('shows one figure when the prices match', () {
      final p = makeProperty(single: 9000, double: 9000, triple: 9000);
      expect(vm.rentRange(p), '₹9K');
    });

    test('ignores unset (zero) prices', () {
      final p = makeProperty(single: 0, double: 7500, triple: 0);
      expect(vm.rentRange(p), '₹7.5K');
    });

    test('is null, not a crash, when no price is set', () {
      final p = makeProperty(single: 0, double: 0, triple: 0);
      expect(vm.rentRange(p), isNull);
    });

    test('formats lakhs and small amounts', () {
      expect(
        vm.rentRange(makeProperty(single: 150000, double: 120000, triple: 0)),
        '₹1.2L–1.5L',
      );
      expect(
        vm.rentRange(makeProperty(single: 800, double: 0, triple: 0)),
        '₹800',
      );
    });
  });

  group('location line', () {
    test('appends the city to the address', () {
      final p = makeProperty(address: 'Baner-Pashan Link Rd', city: 'Pune');
      expect(vm.locationLine(p), 'Baner-Pashan Link Rd, Pune');
    });

    test('does not repeat a city the address already ends with', () {
      final p = makeProperty(address: '21, Baner-Pashan Link Road, Baner, Pune', city: 'Pune');
      expect(vm.locationLine(p), '21, Baner-Pashan Link Road, Baner, Pune');
    });

    test('ignores case when checking for the city', () {
      final p = makeProperty(address: 'Powai, MUMBAI', city: 'Mumbai');
      expect(vm.locationLine(p), 'Powai, MUMBAI');
    });

    test('copes with a missing address or city', () {
      expect(vm.locationLine(makeProperty(address: '', city: 'Pune')), 'Pune');
      expect(vm.locationLine(makeProperty(address: 'Kothrud', city: '')), 'Kothrud');
      expect(vm.locationLine(makeProperty(address: '', city: '')), '');
    });
  });

  group('card facts', () {
    test('beds, rooms and occupancy', () {
      final p = makeProperty(beds: 10, availableBeds: 3, rooms: 4);
      expect(vm.bedsOf(p), 10);
      expect(vm.roomsOf(p), 4);
      expect(vm.occupiedBedsOf(p), 7);
      expect(vm.getOccupancyRate(p), closeTo(0.7, 1e-9));
    });

    test('occupancy is zero for a property with no beds', () {
      expect(vm.getOccupancyRate(makeProperty(beds: 0, availableBeds: 0)), 0);
    });

    test('updated-ago wording', () {
      final now = DateTime(2026, 10, 26, 12);
      String ago(Duration d) =>
          vm.updatedAgo(makeProperty(updatedAt: now.subtract(d)), now: now);

      expect(ago(const Duration(seconds: 20)), 'Just now');
      expect(ago(const Duration(minutes: 20)), '20m ago');
      expect(ago(const Duration(hours: 3)), '3h ago');
      expect(ago(const Duration(hours: 30)), 'Yesterday');
      expect(ago(const Duration(days: 4)), '4d ago');
      expect(ago(const Duration(days: 30)), '26 Sep');
    });

    test('status presentation', () {
      expect(vm.statusLabel(makeProperty(status: 'draft')), 'Draft');
      expect(vm.statusLabel(makeProperty(status: 'active')), 'Active');
      expect(vm.statusLabel(makeProperty(status: 'weird')), 'Weird');
    });
  });

  group('loading', () {
    test('refresh really reloads, even when already loaded', () async {
      stubProperties([makeProperty(id: 'a')]);
      await vm.loadProperties('BUS1');

      stubProperties([makeProperty(id: 'a'), makeProperty(id: 'b')]);
      await vm.refreshProperties('BUS1');

      expect(vm.properties, hasLength(2));
      verify(repo.getPropertiesByBusiness('BUS1')).called(2);
    });

    test('loadProperties is a no-op once loaded', () async {
      stubProperties([makeProperty()]);
      await vm.loadProperties('BUS1');
      await vm.loadProperties('BUS1');

      verify(repo.getPropertiesByBusiness('BUS1')).called(1);
    });

    test('a failed load exposes the error and a retry recovers', () async {
      when(
        repo.getPropertiesByBusiness('BUS1'),
      ).thenThrow(Exception('offline'));
      await vm.loadProperties('BUS1');
      expect(vm.hasError, isTrue);
      expect(vm.isLoading, isFalse);
      expect(vm.hasLoaded, isTrue);

      stubProperties([makeProperty()]);
      await vm.refreshProperties('BUS1');

      expect(vm.hasError, isFalse);
      expect(vm.properties, hasLength(1));
    });

    test('a failed refresh keeps the properties already on screen', () async {
      stubProperties([makeProperty()]);
      await vm.loadProperties('BUS1');

      when(
        repo.getPropertiesByBusiness('BUS1'),
      ).thenThrow(Exception('offline'));
      await vm.refreshProperties('BUS1');

      expect(vm.hasError, isTrue);
      expect(
        vm.properties,
        hasLength(1),
        reason: "don't blank the list on a blip",
      );
    });

    test('hasLoaded is false until the first load finishes', () async {
      expect(vm.hasLoaded, isFalse);
      stubProperties([]);
      await vm.loadProperties('BUS1');
      expect(vm.hasLoaded, isTrue);
    });

    test('a missing business is reported, not queried', () async {
      await vm.loadProperties(null);
      expect(vm.hasError, isTrue);
      verifyNever(repo.getPropertiesByBusiness(any));
    });
  });
}
