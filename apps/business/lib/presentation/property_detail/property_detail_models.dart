// lib/presentation/property_detail/property_detail_models.dart
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:models/business/property/property_model.dart';
import 'package:models/business/property/property_room_model.dart';
import 'package:models/tenant/tenant_request_model.dart';

import '../view_models/tenant_wizard/assignment.dart';

/// An active tenant of one property.
class PropertyTenant {
  const PropertyTenant({
    required this.id,
    required this.name,
    required this.phone,
    required this.roomId,
    required this.bedId,
    required this.monthlyRent,
    required this.status,
    this.email = '',
    this.checkInDate,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String roomId;
  final String bedId;
  final double monthlyRent;
  final String status;
  final DateTime? checkInDate;

  /// Builds one from a `businesses/{b}/tenants/{t}` document.
  factory PropertyTenant.fromDoc(String id, Map<String, dynamic> d) {
    DateTime? date(Object? v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    String s(String k) => d[k]?.toString() ?? '';
    return PropertyTenant(
      id: id,
      name: s('name').isNotEmpty ? s('name') : 'Tenant',
      phone: s('phone'),
      email: s('email'),
      roomId: s('roomId').isNotEmpty ? s('roomId') : s('roomNumber'),
      bedId: s('bedId').isNotEmpty ? s('bedId') : s('bedNumber'),
      monthlyRent: (d['monthlyRent'] as num?)?.toDouble() ?? 0,
      status: s('status').isNotEmpty ? s('status') : 'active',
      checkInDate: date(d['checkInDate']),
    );
  }

  /// The shape the tenant detail screen expects.
  Map<String, dynamic> toDetailMap({required String businessId, required String propertyId}) => {
        'id': id,
        'tenantId': id,
        'businessId': businessId,
        'propertyId': propertyId,
        'roomId': roomId,
        'bedId': bedId,
        'name': name,
        'phone': phone.isEmpty ? null : phone,
        'email': email.isEmpty ? null : email,
        'room': roomId,
        'bed': bedId,
        'rent': monthlyRent,
        'joinDate': checkInDate,
        'status': status.isEmpty ? 'Active' : status[0].toUpperCase() + status.substring(1),
      };

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (name.toLowerCase().contains(q) || roomId.toLowerCase().contains(q)) return true;
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return digits.isNotEmpty && phone.replaceAll(RegExp(r'\D'), '').contains(digits);
  }
}

/// This month's rent invoices for the property, summed.
class MonthCollection {
  const MonthCollection({
    required this.expected,
    required this.collected,
    required this.paidCount,
    required this.unpaidCount,
    required this.overdueCount,
  });

  static const empty = MonthCollection(
      expected: 0, collected: 0, paidCount: 0, unpaidCount: 0, overdueCount: 0);

  final double expected;
  final double collected;
  final int paidCount;
  final int unpaidCount;
  final int overdueCount;

  double get outstanding => (expected - collected).clamp(0, double.infinity);
  double get rate => expected <= 0 ? 0 : (collected / expected).clamp(0.0, 1.0);
  bool get hasInvoices => paidCount + unpaidCount > 0;
}

/// A rent invoice reduced to what the property totals need.
class InvoiceSummary {
  const InvoiceSummary({
    required this.tenantId,
    required this.amount,
    required this.status,
    this.dueDate,
  });

  final String tenantId;
  final double amount;
  final String status;
  final DateTime? dueDate;
}

class PropertyStats {
  const PropertyStats({
    required this.totalRooms,
    required this.occupiedRooms,
    required this.totalBeds,
    required this.occupiedBeds,
    required this.expectedMonthlyRent,
  });

  final int totalRooms;
  final int occupiedRooms;
  final int totalBeds;
  final int occupiedBeds;

  /// Sum of the rent of everyone living there now.
  final double expectedMonthlyRent;

  int get vacantBeds => totalBeds - occupiedBeds;
  double get occupancy => totalBeds == 0 ? 0 : occupiedBeds / totalBeds;
}

/// Everything about a property that loads together.
class PropertyCore {
  const PropertyCore(this.property, this.rooms, this.tenants);

  final Property property;
  final List<PropertyRoom> rooms;
  final List<PropertyTenant> tenants;
}

/// Maps a request's raw status to a label + tone key.
class RequestStatus {
  const RequestStatus(this.label, this.tone);

  final String label;

  /// 'warning' | 'success' | 'danger' | 'info' | 'neutral'
  final String tone;

  static RequestStatus of(TenantRequest r) => ofStatus(r.status);

  static RequestStatus ofStatus(String status) {
    switch (status) {
      case 'pending':
        return const RequestStatus('Pending', 'warning');
      case 'approved':
        return const RequestStatus('Approved', 'info');
      case 'bill_sent':
        return const RequestStatus('Bill sent', 'info');
      case 'payment_submitted':
        return const RequestStatus('Payment to confirm', 'warning');
      case 'confirmed':
      case 'accepted':
        return const RequestStatus('Confirmed', 'success');
      case 'rejected':
        return const RequestStatus('Rejected', 'danger');
      case 'approval_failed':
        return const RequestStatus("Couldn't add tenant", 'danger');
      default:
        return RequestStatus(
            status.isEmpty ? 'Unknown' : status[0].toUpperCase() + status.substring(1).replaceAll('_', ' '),
            'neutral');
    }
  }
}

/// Which beds are taken, as the layout and bed picker both need it.
Map<String, Set<String>> occupiedBedsOf(List<PropertyTenant> tenants) {
  final map = <String, Set<String>>{};
  for (final t in tenants) {
    if (t.roomId.isNotEmpty && t.bedId.isNotEmpty) {
      map.putIfAbsent(t.roomId, () => <String>{}).add(t.bedId);
    }
  }
  return map;
}

PropertyStats statsFor(List<FloorSlot> floors, List<PropertyTenant> tenants) {
  var rooms = 0;
  var occupiedRooms = 0;
  var beds = 0;
  var occupiedBeds = 0;
  for (final f in floors) {
    for (final r in f.rooms) {
      rooms++;
      beds += r.totalBeds;
      final occ = r.totalBeds - r.freeBeds;
      occupiedBeds += occ;
      if (occ > 0) occupiedRooms++;
    }
  }
  return PropertyStats(
    totalRooms: rooms,
    occupiedRooms: occupiedRooms,
    totalBeds: beds,
    occupiedBeds: occupiedBeds,
    expectedMonthlyRent: tenants.fold(0.0, (n, t) => n + t.monthlyRent),
  );
}
