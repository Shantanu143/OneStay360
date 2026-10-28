// lib/presentation/invitations/invitation_viewmodel.dart
import 'package:flutter/foundation.dart';

import '../../data/models.dart';
import '../../data/sources.dart';

enum InvitationOutcome { none, accepted, declined }

/// An owner's invitation to join their PG: read it, accept or decline.
class InvitationViewModel extends ChangeNotifier {
  InvitationViewModel({required InvitationSource source, required this.invitationId}) : _source = source;

  final InvitationSource _source;
  final String invitationId;

  PendingInvitation? _invitation;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  InvitationOutcome _outcome = InvitationOutcome.none;
  bool _disposed = false;

  PendingInvitation? get invitation => _invitation;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;
  InvitationOutcome get outcome => _outcome;
  bool get canRespond => _invitation?.isPending == true && _outcome == InvitationOutcome.none;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      _invitation = await _source.loadInvitation(invitationId);
    } catch (e) {
      _error = e is TenantFailure ? e.message : "Couldn't open this invitation. Try again.";
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<bool> accept() => _respond(() => _source.acceptInvitation(invitationId), InvitationOutcome.accepted);

  Future<bool> decline(String? reason) =>
      _respond(() => _source.declineInvitation(invitationId, reason: reason), InvitationOutcome.declined);

  Future<bool> _respond(Future<void> Function() action, InvitationOutcome outcome) async {
    if (_busy || !canRespond) return false;
    _busy = true;
    _error = null;
    _notify();
    try {
      await action();
      _outcome = outcome;
      return true;
    } catch (e) {
      debugPrint('❌ [Invitation] $e');
      _error = e is TenantFailure ? e.message : "Couldn't send your answer. Try again.";
      return false;
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
