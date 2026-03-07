class PropertyRoom {
  final String roomNumber;
  final String floor;

  // Legacy field (kept): 'Single' | 'Double' | 'Triple' | ...
  final String occupancyType;

  // New fields
  final int? sharingType; // 1, 2, 3, ...
  final bool hasAC; // default false
  final String? gender; // optional room gender: 'Male' | 'Female' | 'Co-ed' | null

  final String status; // available, occupied, maintenance

  PropertyRoom({
    required this.roomNumber,
    required this.floor,
    required this.occupancyType, // keep required for backward compatibility
    this.sharingType, // prefer using this moving forward
    this.hasAC = false,
    this.status = 'available',
    this.gender,
  });

  factory PropertyRoom.fromMap(Map<String, dynamic> map) {
    // Derive sharingType from legacy occupancyType if needed
    int? deriveSharingType(String occ) {
      final o = (occ).toLowerCase();
      if (o.contains('single') || o.contains('1')) return 1;
      if (o.contains('double') || o.contains('2')) return 2;
      if (o.contains('triple') || o.contains('3')) return 3;
      return null;
    }

    final occupancy = map['occupancyType']?.toString() ?? '';
    final st = (map['sharingType'] as num?)?.toInt() ?? deriveSharingType(occupancy);

    return PropertyRoom(
      roomNumber: map['roomNumber']?.toString() ?? '',
      floor: map['floor']?.toString() ?? '',
      occupancyType: occupancy,
      sharingType: st,
      hasAC: map['hasAC'] as bool? ?? false,
      status: map['status']?.toString() ?? 'available',
      gender: map['gender']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    // Provide occupancyType text for compatibility if not set
    String occ = occupancyType;
    if (occ.isEmpty && sharingType != null) {
      occ = switch (sharingType) {
        1 => 'Single',
        2 => 'Double',
        3 => 'Triple',
        _ => '$sharingType-Sharing',
      };
    }

    return {
      'roomNumber': roomNumber,
      'floor': floor,
      'occupancyType': occ,
      'sharingType': sharingType,
      'hasAC': hasAC,
      'status': status,
      'gender': gender,
    };
  }
}
