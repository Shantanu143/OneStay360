// lib/data/firestore_sources.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:models/business/property/property_model.dart';

import 'models.dart';
import 'sources.dart';

/// Runs a callable Cloud Function and returns its result as a map.
typedef CallableRunner = Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data);

Future<Map<String, dynamic>> _firebaseCall(String name, Map<String, dynamic> data) async {
  try {
    final result = await FirebaseFunctions.instance.httpsCallable(name).call<dynamic>(data);
    final raw = result.data;
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  } on FirebaseFunctionsException catch (e) {
    debugPrint('❌ [$name] ${e.code}: ${e.message}');
    throw TenantFailure(_explain(e));
  }
}

String _explain(FirebaseFunctionsException e) {
  final message = e.message?.trim();
  if (message != null && message.isNotEmpty && e.code != 'internal') return message;
  return switch (e.code) {
    'unavailable' || 'deadline-exceeded' => 'No connection. Check your internet and try again.',
    'unauthenticated' => 'Your session expired. Sign in again.',
    'permission-denied' => "You don't have access to do that.",
    _ => 'Something went wrong. Try again.',
  };
}

/// Cities the Explore tab lists (and where a property is looked up when only
/// its id is known).
const exploreCities = [
  'Bangalore',
  'Mumbai',
  'Delhi',
  'Pune',
  'Hyderabad',
  'Chennai',
  'Kolkata',
  'Ahmedabad',
];

/// Every tenant-side source, backed by Firestore and Cloud Functions.
class FirestoreTenantBackend implements TenantBackend {
  FirestoreTenantBackend({FirebaseFirestore? firestore, CallableRunner? call})
      : _fs = firestore ?? FirebaseFirestore.instance,
        _call = call ?? _firebaseCall;

  final FirebaseFirestore _fs;
  final CallableRunner _call;

  // ── Session ──────────────────────────────────────────────

  @override
  Stream<TenantAccount?> watchAccount(String uid) => _fs.doc('users/$uid').snapshots().map((d) {
        final data = d.data();
        return data == null ? null : TenantAccount.fromMap(uid, data);
      });

  @override
  Stream<Stay?> watchActiveStay(String tenantId) => _fs
      .collection('tenants/$tenantId/stays')
      .where('status', isEqualTo: 'active')
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : Stay.fromMap(s.docs.first.id, s.docs.first.data()));

  @override
  Stream<int> watchUnreadCount(String tenantId) => _fs
      .collection('tenants/$tenantId/notifications')
      .where('read', isEqualTo: false)
      .snapshots()
      .map((s) => s.size);

  // ── Stay ─────────────────────────────────────────────────

  @override
  Stream<PropertyContact?> watchProperty(String businessId, String propertyId) {
    return _fs.doc('businesses/$businessId/properties/$propertyId').snapshots().map((d) {
      final m = d.data();
      if (m == null) return null;
      final amenities = m['amenities'];
      return PropertyContact(
        address: readText(m['address']) ?? '',
        city: readText(m['city']) ?? '',
        phone: readText(m['businessPhone']) ?? readText(m['phone']) ?? '',
        ownerName: readText(m['businessName']) ?? '',
        amenities: amenities is Map
            ? [
                for (final e in amenities.entries)
                  if (e.value == true) e.key.toString(),
              ]
            : const [],
      );
    }).transform(_nullOnError());
  }

  @override
  Future<RoomInfo?> loadRoom(String businessId, String propertyId, String roomId) async {
    if (roomId.isEmpty) return null;
    final rooms = _fs.collection('businesses/$businessId/properties/$propertyId/rooms');
    try {
      final byId = await rooms.doc(roomId).get();
      var data = byId.data();
      if (data == null) {
        final byNumber = await rooms.where('roomNumber', isEqualTo: roomId).limit(1).get();
        if (byNumber.docs.isNotEmpty) data = byNumber.docs.first.data();
      }
      if (data == null) return null;
      return RoomInfo(
        sharing: readNum(data['sharingType'] ?? data['capacity'])?.toInt(),
        hasAC: data['hasAC'] == true,
        floor: readText(data['floor']),
      );
    } catch (e) {
      debugPrint('⚠️ [Stay] room: $e');
      return null;
    }
  }

  @override
  Stream<List<RentInvoice>> watchInvoices(String businessId, String tenantId) => _fs
      .collection('businesses/$businessId/tenants/$tenantId/rent_invoices')
      .snapshots()
      .map((s) => s.docs.map((d) => RentInvoice.fromMap(d.id, d.data())).toList()
        ..sort((a, b) {
          final byPeriod = b.periodMonth.compareTo(a.periodMonth);
          if (byPeriod != 0) return byPeriod;
          return (b.dueDate ?? DateTime(0)).compareTo(a.dueDate ?? DateTime(0));
        }));

  @override
  Stream<List<RentPayment>> watchPayments(String businessId, String tenantId) => _fs
      .collection('businesses/$businessId/tenants/$tenantId/payments')
      .snapshots()
      .map((s) => s.docs.map((d) => RentPayment.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0))));

  // ── Enrollment ───────────────────────────────────────────

  @override
  Stream<List<EnrollmentRequest>> watchMyRequests(String uid) => _fs
      .collection('enrollmentRequests')
      .where('tenantId', isEqualTo: uid)
      .snapshots()
      .map((s) {
        // A just-written server timestamp reads as null: treat it as newest.
        final far = DateTime(9999);
        return s.docs.map((d) => EnrollmentRequest.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => (b.createdAt ?? far).compareTo(a.createdAt ?? far));
      });

  @override
  Stream<EnrollmentRequest?> watchRequest(String requestId) => _fs
      .doc('enrollmentRequests/$requestId')
      .snapshots()
      .map((d) => d.data() == null ? null : EnrollmentRequest.fromMap(d.id, d.data()!));

  @override
  Future<String> submitEnrollment(EnrollmentDraft d) async {
    final result = await _call('submitEnrollmentRequest', {
      'propertyId': d.propertyId,
      'businessId': d.businessId,
      'propertyName': d.propertyName,
      'tenantName': d.name,
      'tenantPhone': d.phone,
      'moveInDate': d.moveIn.toIso8601String(),
      'sharingType': d.sharing ?? '',
      'notes': d.notes ?? '',
    });
    return readText(result['requestId']) ?? '';
  }

  @override
  Future<void> submitBillPayment(String requestId, {required String uid, required String reference}) {
    return _fs.doc('enrollmentRequests/$requestId').update({
      'status': 'payment_submitted',
      'transactionId': reference,
      'paymentSubmittedAt': FieldValue.serverTimestamp(),
      'paymentSubmittedBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> withdraw(String requestId) => _fs.doc('enrollmentRequests/$requestId').delete();

  // ── Rent ─────────────────────────────────────────────────

  @override
  Future<PaymentSettings> loadSettings(String businessId) async {
    try {
      final d = (await _fs.doc('businesses/$businessId/settings/razorpay').get()).data();
      if (d == null) return const PaymentSettings();
      return PaymentSettings(onlineEnabled: d['paymentsEnabled'] == true, upiId: readText(d['upiId']));
    } catch (e) {
      debugPrint('⚠️ [Rent] settings: $e');
      return const PaymentSettings();
    }
  }

  @override
  Future<String> createPaymentLink({
    required String businessId,
    required String tenantId,
    required String invoiceId,
  }) async {
    final result = await _call('createPaymentLink', {
      'businessId': businessId,
      'tenantId': tenantId,
      'rentInvoiceId': invoiceId,
    });
    final url = readText(result['paymentLinkUrl']);
    if (url == null) throw const TenantFailure("Couldn't create a payment link. Try again.");
    return url;
  }

  @override
  Future<void> submitRentPayment(RentSubmission s) async {
    await _call('submitRentPayment', {
      'businessId': s.businessId,
      'amount': s.amount,
      'month': s.month,
      'paymentMode': s.mode,
      'transactionId': s.reference ?? '',
      if (s.invoiceId != null) 'rentInvoiceId': s.invoiceId,
    });
  }

  // ── Notifications ────────────────────────────────────────

  @override
  Stream<List<TenantNotification>> watchNotifications(String tenantId) => _fs
      .collection('tenants/$tenantId/notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map((d) => TenantNotification.fromMap(d.id, d.data())).toList());

  @override
  Future<void> markRead(String tenantId, Iterable<String> ids) async {
    final batch = _fs.batch();
    for (final id in ids) {
      batch.update(_fs.doc('tenants/$tenantId/notifications/$id'), {'read': true});
    }
    await batch.commit();
  }

  // ── Invitations ──────────────────────────────────────────

  @override
  Future<List<PendingInvitation>> listInvitations() async {
    final result = await _call('listMyTenantInvitations', {});
    final list = result['invitations'];
    if (list is! List) return const [];
    return [
      for (final m in list)
        if (m is Map) PendingInvitation.fromMap(Map<String, dynamic>.from(m)),
    ];
  }

  @override
  Future<PendingInvitation> loadInvitation(String invitationId) async {
    final result = await _call('getMyTenantInvitation', {'invitationId': invitationId});
    final m = result['invitation'];
    if (m is! Map) throw const TenantFailure('This invitation no longer exists.');
    return PendingInvitation.fromMap(Map<String, dynamic>.from(m));
  }

  @override
  Future<void> acceptInvitation(String invitationId) async {
    await _call('approveInvitation', {'invitationId': invitationId});
  }

  @override
  Future<void> declineInvitation(String invitationId, {String? reason}) async {
    await _call('rejectTenantInvitation', {
      'invitationId': invitationId,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  // ── Pinboard ─────────────────────────────────────────────

  @override
  Stream<List<PinNote>> watchPins(String propertyId) => _fs
      .collection('pinboard')
      .where('propertyId', isEqualTo: propertyId)
      .where('expiresAt', isGreaterThan: Timestamp.now())
      .orderBy('expiresAt')
      .snapshots()
      .map((s) => s.docs.map((d) => PinNote.fromMap(d.id, d.data())).toList());

  @override
  Future<void> addPin(PinDraft d) {
    final ref = _fs.collection('pinboard').doc();
    return ref.set({
      'noteId': ref.id,
      'propertyId': d.propertyId,
      'authorId': d.authorId,
      'authorName': d.authorName,
      'authorPhone': d.authorPhone,
      'category': d.category.wire,
      'content': d.content,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 48))),
    });
  }

  @override
  Future<void> deletePin(String noteId) => _fs.doc('pinboard/$noteId').delete();

  // ── Maintenance ──────────────────────────────────────────

  @override
  Stream<List<MaintenanceRequest>> watchMyMaintenance(String uid) => _fs
      .collection('maintenanceRequests')
      .where('tenantUid', isEqualTo: uid)
      .snapshots()
      .map((s) {
        final far = DateTime(9999);
        return s.docs.map((d) => MaintenanceRequest.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => (b.createdAt ?? far).compareTo(a.createdAt ?? far));
      });

  @override
  Future<void> raiseMaintenance(MaintenanceDraft d) {
    final ref = _fs.collection('maintenanceRequests').doc();
    return ref.set({
      'id': ref.id,
      'tenantUid': d.uid,
      'tenantId': d.tenantId,
      'tenantName': d.tenantName,
      'tenantPhone': d.tenantPhone,
      'businessId': d.stay.businessId,
      'propertyId': d.stay.propertyId,
      'propertyName': d.stay.propertyName,
      'roomNumber': d.stay.roomNumber,
      'bedNumber': d.stay.bedNumber,
      'category': d.category.name,
      'title': d.title,
      'description': d.description,
      'priority': d.urgent ? 'urgent' : 'normal',
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> cancelMaintenance(String requestId) => _fs.doc('maintenanceRequests/$requestId').update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // ── Explore ──────────────────────────────────────────────

  @override
  Future<PropertyPage> loadCity(String city, {Object? cursor, int pageSize = 10}) async {
    Query<Map<String, dynamic>> q = _fs
        .collection('properties_by_city/$city/properties')
        .where('status', isEqualTo: 'active')
        .orderBy('updatedAt', descending: true);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    final snap = await q.limit(pageSize).get();
    final properties = <Property>[];
    for (final d in snap.docs) {
      try {
        properties.add(Property.fromMap(d.data(), d.id));
      } catch (e) {
        debugPrint('⚠️ [Explore] skipping ${d.id}: $e');
      }
    }
    return PropertyPage(
      properties,
      cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length == pageSize,
    );
  }

  @override
  Future<Property?> loadProperty(String propertyId, {String? businessId}) async {
    Future<Property?> fromBusiness(String bid) async {
      try {
        final d = await _fs.doc('businesses/$bid/properties/$propertyId').get();
        return d.data() == null ? null : Property.fromMap(d.data()!, d.id);
      } catch (e) {
        // Not readable (inactive or unpaid property): fall back to the index.
        debugPrint('⚠️ [Explore] business copy of $propertyId: $e');
        return null;
      }
    }

    final derived = RegExp(r'^(BUS\d{7})').firstMatch(propertyId)?.group(1);
    for (final bid in {?businessId, ?derived}) {
      final p = await fromBusiness(bid);
      if (p != null) return p;
    }

    for (final city in exploreCities) {
      final d = await _fs.doc('properties_by_city/$city/properties/$propertyId').get();
      final data = d.data();
      if (data == null) continue;
      final bid = readText(data['businessId']);
      if (bid != null && bid != businessId && bid != derived) {
        final p = await fromBusiness(bid);
        if (p != null) return p;
      }
      return Property.fromMap(data, d.id);
    }
    return null;
  }

  @override
  Future<void> setFavorite(String uid, String propertyId, bool favorite) {
    return _fs.doc('users/$uid').set({
      'favoritePropertyIds':
          favorite ? FieldValue.arrayUnion([propertyId]) : FieldValue.arrayRemove([propertyId]),
    }, SetOptions(merge: true));
  }
}

StreamTransformer<T?, T?> _nullOnError<T>() => StreamTransformer.fromHandlers(
      handleError: (error, stack, sink) {
        debugPrint('⚠️ [Stay] $error');
        sink.add(null);
      },
    );
