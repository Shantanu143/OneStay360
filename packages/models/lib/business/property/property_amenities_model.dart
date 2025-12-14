class PropertyAmenities {
  final bool wifi;
  final bool ac;
  final bool laundry;
  final bool foodIncluded;
  final bool parking;
  final bool geyser;
  final bool powerBackup;
  final bool cctv;
  final bool housekeeping;

  PropertyAmenities({
    required this.wifi,
    required this.ac,
    required this.laundry,
    required this.foodIncluded,
    required this.parking,
    required this.geyser,
    required this.powerBackup,
    required this.cctv,
    required this.housekeeping,
  });

  factory PropertyAmenities.fromMap(Map<String, dynamic> map) {
    return PropertyAmenities(
      wifi: map['wifi'] ?? false,
      ac: map['ac'] ?? false,
      laundry: map['laundry'] ?? false,
      foodIncluded: map['foodIncluded'] ?? false,
      parking: map['parking'] ?? false,
      geyser: map['geyser'] ?? false,
      powerBackup: map['powerBackup'] ?? false,
      cctv: map['cctv'] ?? false,
      housekeeping: map['housekeeping'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wifi': wifi,
      'ac': ac,
      'laundry': laundry,
      'foodIncluded': foodIncluded,
      'parking': parking,
      'geyser': geyser,
      'powerBackup': powerBackup,
      'cctv': cctv,
      'housekeeping': housekeeping,
    };
  }
}
