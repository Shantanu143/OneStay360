// lib/presentation/onboarding/invite_landing_viewmodel.dart
import 'package:flutter/foundation.dart';

import '../common/phone_format.dart';
import 'invite_gateway.dart';
import 'invite_models.dart';

enum LandingState { loading, ready, unavailable, failed }

/// The page a teammate lands on from an invitation link.
class InviteLandingViewModel extends ChangeNotifier {
  InviteLandingViewModel({
    required this.inviteId,
    required InviteGateway gateway,
    required String? Function() verifiedPhone,
    DateTime Function()? clock,
  })  : _gateway = gateway,
        _verifiedPhone = verifiedPhone,
        _clock = clock ?? DateTime.now;

  final String inviteId;
  final InviteGateway _gateway;
  final String? Function() _verifiedPhone;
  final DateTime Function() _clock;

  LandingState _state = LandingState.loading;
  Invitation? _invitation;
  String? _problem;
  String? _error;
  bool _accepting = false;
  bool _disposed = false;

  LandingState get state => _state;
  Invitation? get invitation => _invitation;

  /// Why the invitation cannot be used.
  String? get problem => _problem;

  /// Why accepting did not work.
  String? get error => _error;
  bool get accepting => _accepting;

  /// This phone has not been verified as the invited number yet.
  bool get needsPhoneCheck => !phonesMatch(_verifiedPhone(), _invitation?.phone);

  Future<void> load() async {
    _state = LandingState.loading;
    _problem = null;
    _notify();
    try {
      final invite = await _gateway.fetch(inviteId);
      _invitation = invite;
      if (invite == null) {
        _state = LandingState.unavailable;
        _problem = 'We could not find this invitation. Ask the owner to send it again.';
      } else {
        switch (invite.availability(_clock())) {
          case InviteAvailability.ready:
            _state = LandingState.ready;
          case InviteAvailability.used:
            _state = LandingState.unavailable;
            _problem = 'This invitation has already been used.';
          case InviteAvailability.expired:
            _state = LandingState.unavailable;
            _problem = 'This invitation has expired. Ask the owner for a new one.';
        }
      }
    } catch (e) {
      debugPrint('❌ [Invite] load: $e');
      _state = LandingState.failed;
      _problem = "Couldn't load this invitation. Check your connection and try again.";
    }
    _notify();
  }

  /// Verifies the invited number if it has not been, then accepts. Null when
  /// they backed out or it did not work ([error] says why).
  Future<AcceptedInvite?> accept({required Future<bool> Function(Invitation invite) verifyPhone}) async {
    final invite = _invitation;
    if (invite == null || _accepting) return null;
    _accepting = true;
    _error = null;
    _notify();
    try {
      if (needsPhoneCheck) {
        final done = await verifyPhone(invite);
        if (!done) return null;
        if (needsPhoneCheck) {
          _error = 'Verify the invited number to continue.';
          return null;
        }
      }
      return await _gateway.accept(inviteId);
    } on InviteException catch (e) {
      _error = e.message;
      return null;
    } catch (e) {
      debugPrint('❌ [Invite] accept: $e');
      _error = "Couldn't accept the invitation. Try again.";
      return null;
    } finally {
      _accepting = false;
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
