// lib/presentation/tenant_detail/tenant_detail_models.dart
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../views/home/home_format.dart';

DateTime? _date(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// Text from a map, or null for blanks and the placeholder strings older
/// screens put in when a value was unknown.
String? _text(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  const placeholders = {
    'not provided',
    'not recorded',
    'not specified',
    'n/a',
    'no payment',
    'null',
  };
  return s.isEmpty || placeholders.contains(s.toLowerCase()) ? null : s;
}

double? _number(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

/// One tenant, as the detail screen shows them.
class TenantProfile {
  const TenantProfile({
    required this.id,
    required this.name,
    required this.businessId,
    required this.propertyName,
    this.phone,
    this.email,
    this.room,
    this.bed,
    this.rent,
    this.status = 'active',
    this.joinDate,
    this.propertyId,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? room;
  final String? bed;
  final double? rent;
  final String status;
  final DateTime? joinDate;
  final String businessId;
  final String? propertyId;
  final String propertyName;

  /// Builds one from the map the property screen hands over.
  factory TenantProfile.fromMap(
    Map<String, dynamic> m, {
    required String propertyName,
    required String businessId,
  }) {
    return TenantProfile(
      id: _text(m['tenantId']) ?? _text(m['id']) ?? '',
      name: _text(m['name']) ?? '',
      phone: _text(m['phone']),
      email: _text(m['email']),
      room: _text(m['room']) ?? _text(m['roomNumber']) ?? _text(m['roomId']),
      bed: _text(m['bed']) ?? _text(m['bedNumber']) ?? _text(m['bedId']),
      rent: _number(m['rent'] ?? m['monthlyRent']),
      status: _text(m['status']) ?? 'active',
      joinDate: _date(m['joinDate'] ?? m['checkInDate'] ?? m['createdAt']),
      businessId: businessId.isNotEmpty ? businessId : (_text(m['businessId']) ?? ''),
      propertyId: _text(m['propertyId']),
      propertyName: propertyName,
    );
  }

  bool get hasName => name.trim().isNotEmpty;
  String get displayName => hasName ? name.trim() : 'Unnamed tenant';
  String get initials => hasName ? initialsOf(name) : '?';

  /// "TEN0000001"; the business prefix and long opaque ids are shortened.
  String get displayId {
    var shown = id.contains('_') ? id.split('_').last : id;
    if (shown.length > 15 && !shown.startsWith('TEN')) {
      shown = '${shown.substring(0, 8)}…';
    }
    return shown;
  }

  String get statusLabel =>
      status.isEmpty ? 'Unknown' : status[0].toUpperCase() + status.substring(1).toLowerCase();
  bool get isActive => status.toLowerCase() == 'active';

  /// "Room 101 · Bed 1"
  String get location => [
        if (room != null) 'Room $room',
        if (bed != null) 'Bed $bed',
      ].join(' · ');

  /// Same tenant with new contact details; an empty email clears it.
  TenantProfile withContact({required String name, required String phone, required String email}) {
    return TenantProfile(
      id: id,
      name: name,
      phone: phone.isEmpty ? null : phone,
      email: email.isEmpty ? null : email,
      room: room,
      bed: bed,
      rent: rent,
      status: status,
      joinDate: joinDate,
      businessId: businessId,
      propertyId: propertyId,
      propertyName: propertyName,
    );
  }

  /// What the record-payment screen reads.
  Map<String, dynamic> toRecordMap() => {
        'id': id,
        'tenantId': id,
        'businessId': businessId,
        'propertyId': propertyId,
        'name': displayName,
        'room': room ?? '',
        'bed': bed ?? '',
        'rent': rent ?? 0,
      };
}

enum PaymentTone { success, warning, danger, neutral }

class PaymentView {
  const PaymentView(this.label, this.tone);

  final String label;
  final PaymentTone tone;
}

/// One payment on the tenant's history.
class TenantPayment {
  const TenantPayment({
    required this.id,
    required this.month,
    required this.amount,
    required this.status,
    this.method,
    this.date,
    this.rejectionReason,
  });

  final String id;
  final String month;
  final double amount;
  final String status;
  final String? method;
  final DateTime? date;
  final String? rejectionReason;

  factory TenantPayment.fromMap(String id, Map<String, dynamic> m) {
    return TenantPayment(
      id: id,
      month: _text(m['month']) ?? 'Payment',
      amount: _number(m['amount']) ?? 0,
      status: _text(m['status']) ?? '',
      method: _text(m['method']),
      date: _date(m['date'] ?? m['createdAt']),
      rejectionReason: _text(m['rejectionReason']),
    );
  }

  PaymentView get view {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'verified':
        return const PaymentView('Paid', PaymentTone.success);
      case 'pending_verification':
        return const PaymentView('Awaiting check', PaymentTone.warning);
      case 'rejected':
        return const PaymentView('Rejected', PaymentTone.danger);
      case '':
        return const PaymentView('Unknown', PaymentTone.neutral);
      default:
        final s = status.replaceAll('_', ' ');
        return PaymentView(s[0].toUpperCase() + s.substring(1), PaymentTone.neutral);
    }
  }
}
