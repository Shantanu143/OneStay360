// lib/presentation/onboarding/invite_gateway.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'invite_models.dart';

/// A refusal with a message fit to show as it is.
class InviteException implements Exception {
  const InviteException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Where the invitation screens read and write; faked in tests.
abstract class InviteGateway {
  /// Null when there is no such invitation.
  Future<Invitation?> fetch(String inviteId);

  Future<AcceptedInvite> accept(String inviteId);
}

class FirebaseInviteGateway implements InviteGateway {
  FirebaseInviteGateway({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _fs = firestore ?? FirebaseFirestore.instance,
        _functions = functions;

  final FirebaseFirestore _fs;
  final FirebaseFunctions? _functions;

  @override
  Future<Invitation?> fetch(String inviteId) async {
    final doc = await _fs.collection('business_invitations').doc(inviteId).get();
    final data = doc.data();
    return data == null ? null : Invitation.fromMap(doc.id, data);
  }

  @override
  Future<AcceptedInvite> accept(String inviteId) async {
    try {
      final result = await (_functions ?? FirebaseFunctions.instance)
          .httpsCallable('acceptBusinessInvitation')
          .call<Object?>({'inviteId': inviteId});
      final data = Map<String, dynamic>.from(result.data as Map);
      return AcceptedInvite(
        businessId: data['businessId'].toString(),
        role: data['role'].toString(),
        propertyIds: [for (final p in (data['propertyIds'] as List? ?? const [])) p.toString()],
      );
    } on FirebaseFunctionsException catch (e) {
      throw explainAcceptError(e);
    }
  }
}

/// Plain words for why accepting was refused.
Object explainAcceptError(FirebaseFunctionsException e) {
  final message = e.message ?? '';
  if (e.code == 'permission-denied') {
    return const InviteException('This invitation was sent to a different phone number.');
  }
  if (e.code == 'unauthenticated') {
    return const InviteException('Verify your phone number to accept this invitation.');
  }
  if (e.code == 'not-found') {
    return const InviteException('We could not find this invitation. Ask the owner to send it again.');
  }
  if (message.contains('expired')) {
    return const InviteException('This invitation has expired. Ask the owner for a new one.');
  }
  if (message.contains('not pending')) {
    return const InviteException('This invitation has already been used.');
  }
  return e;
}
