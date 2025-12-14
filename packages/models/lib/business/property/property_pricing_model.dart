class SharingPricingEntry {
  final int sharing; // e.g., 1, 2, 3, 4...
  final int? nonAc;  // monthly rent for Non-AC for this sharing
  final int? ac;     // monthly rent for AC for this sharing

  SharingPricingEntry({
    required this.sharing,
    this.nonAc,
    this.ac,
  });

  factory SharingPricingEntry.fromMap(Map<String, dynamic> map) {
    return SharingPricingEntry(
      sharing: (map['sharing'] as num?)?.toInt() ?? 0,
      nonAc: (map['nonAc'] as num?)?.toInt(),
      ac: (map['ac'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sharing': sharing,
      'nonAc': nonAc,
      'ac': ac,
    };
  }
}

class PropertyPricing {
  // Legacy fixed fields (kept for backward compatibility)
  final int single;
  final int double;
  final int triple;

  // Common charges
  final int securityDeposit;
  final int oneTimeMaintenance;
  final bool maintenanceDeductedFromDeposit;

  // New: dynamic pricing by sharing with AC/Non-AC
  final List<SharingPricingEntry> sharing;

  // Optional: helps UI know what was the max sharing used to fill 'sharing'
  final int? maxSharing;

  PropertyPricing({
    // Legacy required fields remain to avoid breaking existing code
    required this.single,
    required this.double,
    required this.triple,
    required this.securityDeposit,
    required this.oneTimeMaintenance,
    required this.maintenanceDeductedFromDeposit,
    List<SharingPricingEntry>? sharing,
    this.maxSharing,
  }) : sharing = sharing ?? const [];

  factory PropertyPricing.fromMap(Map<String, dynamic> map) {
    // Parse legacy values
    final single = (map['single'] as num?)?.toInt() ?? 0;
    final dbl = (map['double'] as num?)?.toInt() ?? 0;
    final triple = (map['triple'] as num?)?.toInt() ?? 0;

    // Parse dynamic sharing list if present
    List<SharingPricingEntry> dynamicSharing = const [];
    final rawSharing = map['sharing'];
    if (rawSharing is List) {
      dynamicSharing = rawSharing
          .whereType<Map>()
          .map((e) => SharingPricingEntry.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } else if (rawSharing is List<dynamic>) {
      dynamicSharing = rawSharing
          .map((e) => SharingPricingEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else {
      // Build from legacy fields if dynamic missing
      final temp = <SharingPricingEntry>[];
      if (single > 0) temp.add(SharingPricingEntry(sharing: 1, nonAc: single));
      if (dbl > 0) temp.add(SharingPricingEntry(sharing: 2, nonAc: dbl));
      if (triple > 0) temp.add(SharingPricingEntry(sharing: 3, nonAc: triple));
      dynamicSharing = temp;
    }

    return PropertyPricing(
      single: single,
      double: dbl,
      triple: triple,
      securityDeposit: (map['securityDeposit'] as num?)?.toInt() ?? 0,
      oneTimeMaintenance: (map['oneTimeMaintenance'] as num?)?.toInt() ?? 0,
      maintenanceDeductedFromDeposit: map['maintenanceDeductedFromDeposit'] as bool? ?? false,
      sharing: dynamicSharing,
      maxSharing: (map['maxSharing'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    // Also provide legacy fields for compatibility if present in dynamic
    int legacySingle = single;
    int legacyDouble = double;
    int legacyTriple = triple;

    int? findNonAc(int s) {
      final entry = sharing.firstWhere(
            (e) => e.sharing == s && e.nonAc != null,
        orElse: () => SharingPricingEntry(sharing: s),
      );
      return entry.nonAc;
    }

    legacySingle = legacySingle == 0 ? (findNonAc(1) ?? 0) : legacySingle;
    legacyDouble = legacyDouble == 0 ? (findNonAc(2) ?? 0) : legacyDouble;
    legacyTriple = legacyTriple == 0 ? (findNonAc(3) ?? 0) : legacyTriple;

    return {
      // Legacy fields
      'single': legacySingle,
      'double': legacyDouble,
      'triple': legacyTriple,

      // Common charges
      'securityDeposit': securityDeposit,
      'oneTimeMaintenance': oneTimeMaintenance,
      'maintenanceDeductedFromDeposit': maintenanceDeductedFromDeposit,

      // New dynamic list
      'sharing': sharing.map((e) => e.toMap()).toList(),
      if (maxSharing != null) 'maxSharing': maxSharing,
    };
  }

  // Helper: returns price for a sharing type and AC/Non-AC preference
  int? getPriceFor(int sharingType, {required bool acRoom}) {
    final entry = sharing.firstWhere(
          (e) => e.sharing == sharingType,
      orElse: () => SharingPricingEntry(sharing: sharingType),
    );
    return acRoom ? entry.ac : entry.nonAc;
  }
}

