// lib/presentation/team/firestore_team_source.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'invite_form_viewmodel.dart';
import 'team_models.dart';
import 'team_source.dart';

/// Calls a Cloud Function and returns what it sent back.
typedef TeamCallable = Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data);

class FirestoreTeamSource implements TeamSource {
  FirestoreTeamSource({
    FirebaseFirestore? firestore,
    String? Function()? currentUid,
    TeamCallable? callable,
    DateTime Function()? clock,
  })  : _fs = firestore ?? FirebaseFirestore.instance,
        _currentUid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _callable = callable ?? _callFunction,
        _clock = clock ?? DateTime.now;

  final FirebaseFirestore _fs;
  final String? Function() _currentUid;
  final TeamCallable _callable;
  final DateTime Function() _clock;

  static Future<Map<String, dynamic>> _callFunction(String name, Map<String, dynamic> data) async {
    final result = await FirebaseFunctions.instance.httpsCallable(name).call<Object?>(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  CollectionReference<Map<String, dynamic>> _members(String businessId) =>
      _fs.collection('businesses').doc(businessId).collection('members');

  @override
  Stream<List<TeamMember>> watchMembers(String businessId) => _members(businessId)
      .snapshots()
      .map((snap) => [for (final d in snap.docs) TeamMember.fromMap(d.id, d.data())]);

  @override
  Future<List<TeamProperty>> loadProperties(String businessId) async {
    final snap = await _fs.collection('businesses').doc(businessId).collection('properties').get();
    return [
      for (final d in snap.docs)
        TeamProperty(id: d.id, name: (d.data()['name'] ?? '').toString().trim().isEmpty ? d.id : d.data()['name'].toString()),
    ];
  }

  @override
  Future<List<TeamInvite>> loadPendingInvites(String businessId) async {
    final snap = await _fs
        .collection('business_invitations')
        .where('businessId', isEqualTo: businessId)
        .where('status', isEqualTo: 'pending')
        .get();
    final now = _clock();
    return [
      for (final d in snap.docs)
        () {
          final x = d.data();
          final email = (x['email'] ?? '').toString();
          return TeamInvite(
            id: d.id,
            phone: (x['phone'] ?? '').toString(),
            email: email.isEmpty ? null : email,
            role: (x['role'] ?? 'staff').toString(),
            propertyIds: [for (final p in (x['propertyIds'] as List? ?? const [])) p.toString()],
            createdAt: _date(x['createdAt']) ?? now,
            // An unknown expiry must not read as already expired.
            expiresAt: _date(x['expiresAt']) ?? now.add(const Duration(days: 7)),
          );
        }(),
    ];
  }

  @override
  Future<Map<String, Set<String>>> loadAccess(String businessId, List<TeamProperty> properties) async {
    final snaps = await Future.wait([
      for (final p in properties)
        _fs.collection('businesses').doc(businessId).collection('properties').doc(p.id).collection('access').get(),
    ]);
    final access = <String, Set<String>>{};
    for (var i = 0; i < properties.length; i++) {
      for (final d in snaps[i].docs) {
        access.putIfAbsent(d.id, () => {}).add(properties[i].id);
      }
    }
    return access;
  }

  @override
  Future<InviteResult> invite(String businessId, InviteRequest request) async {
    try {
      final r = await _callable('createBusinessInvitation', {
        'businessId': businessId,
        'phone': request.phone,
        if (request.email != null) 'email': request.email,
        'role': request.role,
        'propertyIds': request.propertyIds,
      });
      return InviteResult(id: (r['inviteId'] ?? '').toString(), link: (r['inviteLink'] ?? '').toString());
    } on FirebaseFunctionsException catch (e) {
      throw _explainInvite(e);
    }
  }

  @override
  Future<void> updateAccess({
    required String businessId,
    required String memberUid,
    required String role,
    required List<String> propertyIds,
  }) async {
    try {
      await _callable('updateMemberPropertyAccess', {
        'businessId': businessId,
        'memberUid': memberUid,
        'role': role,
        'propertyIds': propertyIds,
      });
    } on FirebaseFunctionsException catch (e) {
      throw _explainAccess(e);
    }
  }

  @override
  Future<void> setMemberActive(String businessId, String memberUid, {required bool active}) async {
    try {
      await _members(businessId).doc(memberUid).update({
        'status': active ? 'active' : 'disabled',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _currentUid(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw const TeamException('Only the owner can change access.');
      rethrow;
    }
  }

  Object _explainInvite(FirebaseFunctionsException e) {
    final message = e.message ?? '';
    if (e.code == 'permission-denied') return const TeamException('Only the owner can invite team members.');
    if (e.code == 'unauthenticated') return const TeamException('Please sign in again.');
    if (message.contains('INVITE_BASE_URL')) {
      return const TeamException("Invitations aren't set up on the server yet. Please contact support.");
    }
    return e;
  }

  Object _explainAccess(FirebaseFunctionsException e) {
    final message = e.message ?? '';
    if (e.code == 'permission-denied') return const TeamException('Only the owner can change access.');
    if (e.code == 'unauthenticated') return const TeamException('Please sign in again.');
    if (message.contains('Member inactive')) return const TeamException('Their access is off. Turn it on first.');
    if (message.contains('Owner role')) return const TeamException("The owner's access can't be changed.");
    return e;
  }

  DateTime? _date(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
