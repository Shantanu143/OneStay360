import 'package:cloud_firestore/cloud_firestore.dart';

class PropertyBed {
  final String id;
  final String bedNumber;
  final bool isOccupied;
  final String? tenantId;
  final String? tenantName;
  final double? rent;
  final DateTime? occupiedAt;

  PropertyBed({
    required this.id,
    required this.bedNumber,
    this.isOccupied = false,
    this.tenantId,
    this.tenantName,
    this.rent,
    this.occupiedAt,
  });

  factory PropertyBed.fromMap(Map<String, dynamic> map, String id) {
    return PropertyBed(
      id: id,
      bedNumber: map['bedNumber']?.toString() ?? '',
      isOccupied: map['isOccupied'] as bool? ?? false,
      tenantId: map['tenantId']?.toString(),
      tenantName: map['tenantName']?.toString(),
      rent: (map['rent'] as num?)?.toDouble(),
      occupiedAt: map['occupiedAt'] is Timestamp ? (map['occupiedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bedNumber': bedNumber,
      'isOccupied': isOccupied,
      if (tenantId != null) 'tenantId': tenantId,
      if (tenantName != null) 'tenantName': tenantName,
      if (rent != null) 'rent': rent,
      if (occupiedAt != null) 'occupiedAt': occupiedAt,
    };
  }
}
