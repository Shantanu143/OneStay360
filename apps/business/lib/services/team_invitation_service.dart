import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class TeamInvitationService {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  TeamInvitationService({FirebaseFunctions? functions, FirebaseFirestore? firestore})
      : _functions = functions ?? FirebaseFunctions.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<Map<String, dynamic>> createInvitation({
    required String businessId,
    required String phone,
    String? email,
    required String role,
    required List<String> propertyIds,
  }) async {
    final callable = _functions.httpsCallable('createBusinessInvitation');
    final result = await callable.call({
      'businessId': businessId,
      'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      'role': role,
      'propertyIds': propertyIds,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> acceptInvitation(String inviteId) async {
    final callable = _functions.httpsCallable('acceptBusinessInvitation');
    final result = await callable.call({
      'inviteId': inviteId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>?> fetchInvitation(String inviteId) async {
    final doc = await _firestore.collection('business_invitations').doc(inviteId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<Map<String, dynamic>> updateMemberPropertyAccess({
    required String businessId,
    required String memberUid,
    required String role,
    required List<String> propertyIds,
  }) async {
    final callable = _functions.httpsCallable('updateMemberPropertyAccess');
    final result = await callable.call({
      'businessId': businessId,
      'memberUid': memberUid,
      'role': role,
      'propertyIds': propertyIds,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }
}
