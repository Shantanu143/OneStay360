// lib/presentation/views/property_form/property_form_checks.dart
//
// What each step of the property form needs before moving on. Pure, so the
// rules are unit tested apart from the screen.

typedef RoomDraft = ({String number, String? floor, int? sharing});

abstract final class PropertyFormChecks {
  static String? basics({
    required String name,
    required String? city,
    required String address,
    required String pincode,
    required String floors,
  }) {
    if (name.trim().isEmpty) return 'Enter the property name.';
    if (city == null || city.isEmpty) return 'Choose the city.';
    if (address.trim().isEmpty) return 'Enter the full address.';
    if (!RegExp(r'^\d{6}$').hasMatch(pincode.trim())) return 'PIN codes have 6 digits.';
    final f = int.tryParse(floors.trim());
    if (f == null || f < 0) return 'Enter how many floors (0 if only ground).';
    if (f > 60) return 'That is a lot of floors. Check the number.';
    return null;
  }

  /// [prices] is (non-AC, AC) per sharing, as typed.
  static String? pricing({required int maxSharing, required List<(String, String)> prices}) {
    if (maxSharing <= 0) return 'Choose up to how many people share a room.';
    final typed = [for (final (a, b) in prices) ...[a.trim(), b.trim()]].where((s) => s.isNotEmpty).toList();
    if (typed.isEmpty) return 'Add a rent for at least one sharing type.';
    if (typed.any((s) => int.tryParse(s) == null)) return 'Rents must be numbers, like 8000.';
    return null;
  }

  static String? rooms(List<RoomDraft> rooms, {required int maxSharing}) {
    if (rooms.isEmpty) return 'Add at least one room.';
    final seen = <String>{};
    for (var i = 0; i < rooms.length; i++) {
      final r = rooms[i];
      final number = r.number.trim();
      if (number.isEmpty) return 'Room ${i + 1} needs a room number.';
      if (r.floor == null) return 'Room $number needs a floor.';
      if (r.sharing == null || r.sharing! < 1 || r.sharing! > maxSharing) return 'Room $number needs a sharing type.';
      if (!seen.add(number)) return 'Room $number is listed twice.';
    }
    return null;
  }

  static String? food({required bool hasFood, required bool anyMeal}) =>
      hasFood && !anyMeal ? 'Pick the meals you serve, or turn off Meals.' : null;

  static String? rules({required String? gender}) => gender == null ? 'Choose who can stay.' : null;

  static List<String> floorOptions(int floors) => ['Ground', for (var i = 1; i <= floors; i++) '$i'];

  static String floorLabel(String floor) {
    final n = int.tryParse(floor);
    if (n == null) return floor;
    final suffix = (n % 100 >= 11 && n % 100 <= 13)
        ? 'th'
        : switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
    return '$n$suffix floor';
  }
}
