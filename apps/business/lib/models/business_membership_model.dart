import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a membership linking a user to a business with role + profile info.
/// A single model is used for both access control (role/status) and basic member details.
class BusinessMembership {
  final String id; // doc id (usually uid)
  final String uid;
  final String businessId;
  final String role;   // owner/manager/staff
  final String status; // active/pending/inactive
  final String name;
  final String email;
  final String phone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BusinessMembership({
    required this.id,
    required this.uid,
    required this.businessId,
    required this.role,
    required this.status,
    required this.name,
    required this.email,
    required this.phone,
    this.createdAt,
    this.updatedAt,
  });

  /// Convert model to Firestore document format.
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'businessId': businessId,
      'role': role,
      'status': status,
      'name': name,
      'email': email,
      'phone': phone,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  /// Create model from Firestore document snapshot.
  factory BusinessMembership.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return BusinessMembership(
      id: doc.id,
      uid: data['uid'] as String,
      businessId: data['businessId'] as String,
      role: data['role'] as String? ?? 'owner',
      status: data['status'] as String? ?? 'active',
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Create a copy with optional field overrides.
  BusinessMembership copyWith({
    String? id,
    String? uid,
    String? businessId,
    String? role,
    String? status,
    String? name,
    String? email,
    String? phone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BusinessMembership(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      businessId: businessId ?? this.businessId,
      role: role ?? this.role,
      status: status ?? this.status,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
    String toString() =>
      'BusinessMembership(id: $id, uid: $uid, businessId: $businessId, role: $role, status: $status, name: $name, email: $email, phone: $phone)';
}
