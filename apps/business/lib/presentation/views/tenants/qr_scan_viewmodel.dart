// lib/presentation/views/tenants/qr_scan_viewmodel.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

const _prefix = 'onestay360:tenant:';

/// The tenant id in a tenant's profile QR code, or null for any other code.
String? tenantIdFromQr(String raw) {
  final text = raw.trim();
  if (!text.startsWith(_prefix)) return null;
  final id = text.substring(_prefix.length).trim();
  return id.isEmpty ? null : id;
}

/// Reading that tenant is not allowed for this person.
class QrLookupDenied implements Exception {
  const QrLookupDenied();
}

/// Finds a tenant's details from the id in their QR code. Faked in tests.
abstract class TenantLookup {
  /// Null when there is no such tenant.
  Future<Map<String, dynamic>?> find(String tenantId);
}

class FirestoreTenantLookup implements TenantLookup {
  FirestoreTenantLookup({
    FirebaseFirestore? firestore,
    Future<DocumentSnapshot<Map<String, dynamic>>> Function(DocumentReference<Map<String, dynamic>> ref)? read,
  })  : _fs = firestore ?? FirebaseFirestore.instance,
        _read = read ?? ((ref) => ref.get());

  final FirebaseFirestore _fs;
  final Future<DocumentSnapshot<Map<String, dynamic>>> Function(DocumentReference<Map<String, dynamic>>) _read;

  @override
  Future<Map<String, dynamic>?> find(String tenantId) async {
    try {
      final tenant = await _read(_fs.collection('tenants').doc(tenantId));
      final data = tenant.data();
      if (data == null) return null;

      Map<String, dynamic>? profile;
      final userId = data['userId']?.toString() ?? '';
      if (userId.isNotEmpty) {
        profile = (await _read(_fs.collection('users').doc(userId))).data();
      }
      return {...data, ...?profile, 'tenantId': tenantId};
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw const QrLookupDenied();
      rethrow;
    }
  }
}

/// What the scanner is doing with the codes the camera sees.
class QrScanViewModel extends ChangeNotifier {
  QrScanViewModel({required TenantLookup lookup}) : _lookup = lookup;

  final TenantLookup _lookup;

  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _found;
  bool _disposed = false;

  bool get busy => _busy;
  String? get error => _error;

  /// The tenant, once found.
  Map<String, dynamic>? get found => _found;

  /// Called for every code the camera sees, many times a second.
  Future<void> onCode(String raw) async {
    if (_busy || _found != null) return;
    _error = null;
    final id = tenantIdFromQr(raw);
    if (id == null) {
      _error = "That isn't a OneStay360 tenant code. Ask the tenant to show the QR on their profile.";
      _notify();
      return;
    }
    _busy = true;
    _notify();
    try {
      final tenant = await _lookup.find(id);
      if (tenant == null) {
        _error = "We couldn't find that tenant. Check the code and try again.";
      } else {
        _found = tenant;
      }
    } on QrLookupDenied {
      _error = "You can't look up tenants this way. Ask the owner to add them for you.";
    } catch (e) {
      debugPrint('❌ [QrScan] $e');
      _error = "Couldn't look up that tenant. Check your connection and try again.";
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
