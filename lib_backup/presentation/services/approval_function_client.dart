import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ApprovalFunctionClient {
  final HttpsCallable _approve;

  ApprovalFunctionClient()
      : _approve = FirebaseFunctions.instanceFor(region: 'us-central1')
            .httpsCallable('approveInvitation');

  Future<bool> approveInvitation(String invitationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'User must be signed in to approve an invitation.',
      );
    }

    try {
      debugPrint('ApprovalFunctionClient: currentUser.uid=${user.uid}');
      final token = await user.getIdToken();
      final tStr = token ?? '';
      final prefixLen = tStr.length >= 8 ? 8 : tStr.length;
      debugPrint(
          'ApprovalFunctionClient: idToken present len=${tStr.length} prefix=${tStr.substring(0, prefixLen)}');

      final resp = await _approve.call(<String, dynamic>{
        'invitationId': invitationId,
      });

      final data = resp.data;
      if (data is Map && data['success'] == true) return true;

      throw FirebaseFunctionsException(
        code: 'failed',
        message: 'Approval function returned unexpected result: ${resp.data}',
      );
    } on FirebaseFunctionsException {
      rethrow; // region mismatch is already fixed, no fallback needed
    } catch (e) {
      throw FirebaseFunctionsException(
        code: 'unknown',
        message: 'Failed to call approval function: $e',
      );
    }
  }
}
