import 'package:business/presentation/views/property_form/property_form_checks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('basics', () {
    String? check({
      String name = 'Green Nest',
      String? city = 'Pune',
      String address = '12 MG Road',
      String pincode = '411001',
      String floors = '2',
    }) =>
        PropertyFormChecks.basics(name: name, city: city, address: address, pincode: pincode, floors: floors);

    test('passes with everything filled in', () => expect(check(), isNull));
    test('needs a name', () => expect(check(name: ' '), 'Enter the property name.'));
    test('needs a city', () => expect(check(city: null), 'Choose the city.'));
    test('needs an address', () => expect(check(address: ''), 'Enter the full address.'));
    test('needs a 6-digit PIN code', () {
      expect(check(pincode: '4110'), 'PIN codes have 6 digits.');
      expect(check(pincode: 'abcdef'), 'PIN codes have 6 digits.');
    });
    test('floors are a small number', () {
      expect(check(floors: ''), 'Enter how many floors (0 if only ground).');
      expect(check(floors: '0'), isNull);
      expect(check(floors: '99'), 'That is a lot of floors. Check the number.');
    });
  });

  group('pricing', () {
    test('needs max sharing and at least one price', () {
      expect(PropertyFormChecks.pricing(maxSharing: 0, prices: const []), 'Choose up to how many people share a room.');
      expect(PropertyFormChecks.pricing(maxSharing: 2, prices: const [('', ''), ('', '')]),
          'Add a rent for at least one sharing type.');
      expect(PropertyFormChecks.pricing(maxSharing: 2, prices: const [('8000', ''), ('', '')]), isNull);
    });

    test('prices must be numbers', () {
      expect(PropertyFormChecks.pricing(maxSharing: 1, prices: const [('8k', '')]), 'Rents must be numbers, like 8000.');
    });
  });

  group('rooms', () {
    test('needs at least one complete room', () {
      expect(PropertyFormChecks.rooms(const [], maxSharing: 2), 'Add at least one room.');
      expect(PropertyFormChecks.rooms(const [(number: '', floor: 'Ground', sharing: 2)], maxSharing: 2),
          'Room 1 needs a room number.');
      expect(PropertyFormChecks.rooms(const [(number: '101', floor: null, sharing: 2)], maxSharing: 2),
          'Room 101 needs a floor.');
      expect(PropertyFormChecks.rooms(const [(number: '101', floor: 'Ground', sharing: 3)], maxSharing: 2),
          'Room 101 needs a sharing type.');
      expect(PropertyFormChecks.rooms(const [(number: '101', floor: 'Ground', sharing: 2)], maxSharing: 2), isNull);
    });

    test('room numbers are unique', () {
      expect(
        PropertyFormChecks.rooms(const [
          (number: '101', floor: 'Ground', sharing: 1),
          (number: ' 101', floor: '1', sharing: 1),
        ], maxSharing: 2),
        'Room 101 is listed twice.',
      );
    });
  });

  test('food needs a plan when meals are included', () {
    expect(PropertyFormChecks.food(hasFood: true, anyMeal: false), 'Pick the meals you serve, or turn off Meals.');
    expect(PropertyFormChecks.food(hasFood: true, anyMeal: true), isNull);
    expect(PropertyFormChecks.food(hasFood: false, anyMeal: false), isNull);
  });

  test('rules need who can stay', () {
    expect(PropertyFormChecks.rules(gender: null), 'Choose who can stay.');
    expect(PropertyFormChecks.rules(gender: 'Co-ed'), isNull);
  });

  test('floor labels', () {
    expect(PropertyFormChecks.floorOptions(3), ['Ground', '1', '2', '3']);
    expect(PropertyFormChecks.floorLabel('Ground'), 'Ground');
    expect(PropertyFormChecks.floorLabel('2'), '2nd floor');
  });
}
