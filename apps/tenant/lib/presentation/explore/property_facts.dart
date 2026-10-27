// lib/presentation/explore/property_facts.dart
//
// Plain-language facts about a listed property, shared by Explore, the PG
// page and the join form.
import 'package:models/business/property/property_model.dart';

import '../common/format.dart';

/// One way to stay: "Double sharing, AC, ₹9,000".
class PriceOption {
  const PriceOption({required this.sharing, required this.ac, required this.price});

  final int sharing;
  final bool ac;
  final int price;

  String get sharingLabel => switch (sharing) {
        1 => 'Single',
        2 => 'Double sharing',
        3 => 'Triple sharing',
        _ => '$sharing sharing',
      };

  /// What the join form sends as the sharing preference.
  String get shortLabel => switch (sharing) {
        1 => 'Single',
        2 => 'Double',
        3 => 'Triple',
        _ => '$sharing sharing',
      };
}

/// Every priced option, cheapest first.
List<PriceOption> priceOptions(Property p) {
  final pricing = p.pricing;
  final max = pricing.maxSharing;
  final options = <PriceOption>[
    for (final e in pricing.sharing)
      if (e.sharing > 0 && (max == null || e.sharing <= max)) ...[
        if ((e.nonAc ?? 0) > 0) PriceOption(sharing: e.sharing, ac: false, price: e.nonAc!),
        if ((e.ac ?? 0) > 0) PriceOption(sharing: e.sharing, ac: true, price: e.ac!),
      ],
  ];
  if (options.isEmpty) {
    if (pricing.single > 0) options.add(PriceOption(sharing: 1, ac: false, price: pricing.single));
    if (pricing.double > 0) options.add(PriceOption(sharing: 2, ac: false, price: pricing.double));
    if (pricing.triple > 0) options.add(PriceOption(sharing: 3, ac: false, price: pricing.triple));
  }
  options.sort((a, b) => a.price.compareTo(b.price));
  return options;
}

int minPriceOf(Property p) => priceOptions(p).firstOrNull?.price ?? 0;

int maxPriceOf(Property p) => priceOptions(p).lastOrNull?.price ?? 0;

String priceLabelOf(Property p) {
  final min = minPriceOf(p);
  return min == 0 ? 'Price on request' : 'from ${formatInr(min)}';
}

enum GenderPolicy { girls, boys, coed, unknown }

GenderPolicy genderOf(Property p) {
  final g = p.rules.genderAllowed.trim().toLowerCase();
  if (const {'female', 'girls', 'women', 'girls only'}.contains(g)) return GenderPolicy.girls;
  if (const {'male', 'boys', 'men', 'boys only'}.contains(g)) return GenderPolicy.boys;
  if (const {'co-ed', 'coed', 'both', 'any', 'mixed', 'unisex'}.contains(g)) return GenderPolicy.coed;
  return GenderPolicy.unknown;
}

String genderLabelOf(Property p) => switch (genderOf(p)) {
      GenderPolicy.girls => 'Girls',
      GenderPolicy.boys => 'Boys',
      GenderPolicy.coed => 'Co-ed',
      GenderPolicy.unknown => p.rules.genderAllowed,
    };

/// Amenity flags that are on, with a label for each.
List<(String key, String label)> amenitiesOf(Property p) {
  final a = p.amenities;
  return [
    if (a.wifi) ('wifi', 'Wi-Fi'),
    if (a.ac) ('ac', 'AC'),
    if (a.foodIncluded) ('foodIncluded', 'Meals'),
    if (a.laundry) ('laundry', 'Laundry'),
    if (a.housekeeping) ('housekeeping', 'Housekeeping'),
    if (a.geyser) ('geyser', 'Hot water'),
    if (a.powerBackup) ('powerBackup', 'Power backup'),
    if (a.parking) ('parking', 'Parking'),
    if (a.cctv) ('cctv', 'CCTV'),
  ];
}
