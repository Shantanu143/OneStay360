// lib/presentation/team/team_source.dart
import 'invite_form_viewmodel.dart';
import 'team_models.dart';

/// A failure with something worth showing to the owner as it is.
class TeamException implements Exception {
  const TeamException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Where the team screens read and write; faked in tests.
abstract class TeamSource {
  /// Everyone with a membership in the business, live.
  Stream<List<TeamMember>> watchMembers(String businessId);

  Future<List<TeamProperty>> loadProperties(String businessId);

  /// Invitations that have been sent and not accepted.
  Future<List<TeamInvite>> loadPendingInvites(String businessId);

  /// For each member (by uid) the ids of the properties they can open.
  Future<Map<String, Set<String>>> loadAccess(String businessId, List<TeamProperty> properties);

  Future<InviteResult> invite(String businessId, InviteRequest request);

  Future<void> updateAccess({
    required String businessId,
    required String memberUid,
    required String role,
    required List<String> propertyIds,
  });

  /// Switches a member's access to the business on or off.
  Future<void> setMemberActive(String businessId, String memberUid, {required bool active});
}
