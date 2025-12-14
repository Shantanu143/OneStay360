class PropertyTotals {
  final int rooms;
  final int beds;
  final int availableBeds;

  PropertyTotals({
    required this.rooms,
    required this.beds,
    required this.availableBeds,
  });

  factory PropertyTotals.fromMap(Map<String, dynamic> map) {
    return PropertyTotals(
      rooms: map['rooms'] ?? 0,
      beds: map['beds'] ?? 0,
      availableBeds: map['availableBeds'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rooms': rooms,
      'beds': beds,
      'availableBeds': availableBeds,
    };
  }
}
