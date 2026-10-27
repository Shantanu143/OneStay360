// lib/presentation/team/team_viewmodel.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'invite_form_viewmodel.dart';
import 'team_models.dart';
import 'team_source.dart';

/// The Team screen: members (live), who can open what, and invitations that
/// are still waiting to be accepted.
class TeamViewModel extends ChangeNotifier {
  TeamViewModel({required TeamSource source, DateTime Function()? clock})
      : _source = source,
        _clock = clock ?? DateTime.now;

  final TeamSource _source;
  final DateTime Function() _clock;

  String? _businessId;
  StreamSubscription<List<TeamMember>>? _sub;
  List<TeamMember> _members = const [];
  List<TeamProperty> _properties = const [];
  List<TeamInvite> _invites = const [];
  Map<String, Set<String>>? _access;
  bool _loading = false;
  bool _hasLoaded = false;
  bool _inviting = false;
  bool _disposed = false;
  String? _error;
  String? _inviteError;
  String? _actionError;
  String? _busyUid;

  List<TeamMember> get members => _members;
  List<TeamProperty> get properties => _properties;
  List<TeamInvite> get invites => _invites;
  bool get loading => _loading;
  bool get hasLoaded => _hasLoaded;
  bool get isInviting => _inviting;
  String? get error => _error;
  String? get inviteError => _inviteError;
  String? get actionError => _actionError;
  String? get busyUid => _busyUid;

  String get summaryLine => _members.length == 1 ? '1 member' : '${_members.length} members';

  /// "2 properties", "All properties" for the owner.
  String accessSummary(TeamMember m) {
    if (m.isOwner) return 'All properties';
    final access = _access;
    if (access == null) return 'Access not loaded';
    final n = access[m.uid]?.length ?? 0;
    return switch (n) { 0 => 'No properties', 1 => '1 property', _ => '$n properties' };
  }

  /// The property ids [uid] can open, or null if that could not be read.
  Set<String>? accessOf(String uid) => _access?[uid];

  /// Starts watching the team; completes once the members first arrive (or
  /// fail to).
  Future<void> load(String businessId) async {
    unawaited(_sub?.cancel());
    _businessId = businessId;
    _loading = true;
    _error = null;
    _notify();

    try {
      _properties = await _source.loadProperties(businessId);
    } catch (e) {
      debugPrint('❌ [Team] properties: $e');
      _fail();
      return;
    }
    await Future.wait([_loadInvites(), _loadAccess()]);

    final first = Completer<void>();
    _sub = _source.watchMembers(businessId).listen(
      (list) {
        _members = _sorted(list);
        _hasLoaded = true;
        _loading = false;
        _error = null;
        _notify();
        if (!first.isCompleted) first.complete();
      },
      onError: (Object e) {
        debugPrint('❌ [Team] members: $e');
        _fail();
        if (!first.isCompleted) first.complete();
      },
    );
    await first.future;
  }

  /// Reads invitations and access again (members are live already).
  Future<void> refresh() async {
    final id = _businessId;
    if (id == null) return;
    try {
      _properties = await _source.loadProperties(id);
    } catch (e) {
      debugPrint('⚠️ [Team] refresh: $e');
    }
    await Future.wait([_loadInvites(), _loadAccess()]);
    _notify();
  }

  Future<InviteResult?> invite(InviteRequest request) async {
    final id = _businessId;
    if (id == null) return null;
    _inviting = true;
    _inviteError = null;
    _notify();
    try {
      final result = await _source.invite(id, request);
      await _loadInvites();
      return result;
    } on TeamException catch (e) {
      _inviteError = e.message;
      return null;
    } catch (e) {
      debugPrint('❌ [Team] invite: $e');
      _inviteError = "Couldn't send the invitation. Try again.";
      return null;
    } finally {
      _inviting = false;
      _notify();
    }
  }

  /// Turns [member]'s access to the business off or on. Never the owner's.
  Future<bool> setActive(TeamMember member, bool active) async {
    final id = _businessId;
    if (id == null || member.isOwner) return false;
    _busyUid = member.uid;
    _actionError = null;
    _notify();
    try {
      await _source.setMemberActive(id, member.uid, active: active);
      return true;
    } catch (e) {
      debugPrint('❌ [Team] setActive: $e');
      _actionError = "Couldn't change their access. Try again.";
      return false;
    } finally {
      _busyUid = null;
      _notify();
    }
  }

  void clearActionError() {
    _actionError = null;
    _notify();
  }

  Future<void> _loadInvites() async {
    try {
      final now = _clock();
      final all = await _source.loadPendingInvites(_businessId!);
      _invites = [for (final i in all) if (!i.isExpired(now)) i]..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    } catch (e) {
      debugPrint('⚠️ [Team] invitations: $e');
    }
  }

  Future<void> _loadAccess() async {
    try {
      _access = await _source.loadAccess(_businessId!, _properties);
    } catch (e) {
      debugPrint('⚠️ [Team] access: $e');
      _access = null;
    }
  }

  void _fail() {
    _error = "Couldn't load your team.";
    _loading = false;
    _notify();
  }

  /// Owner first, then people with access by name, then those without.
  List<TeamMember> _sorted(List<TeamMember> list) => [...list]..sort((a, b) {
        int rank(TeamMember m) => m.isOwner ? 0 : (m.isActive ? 1 : 2);
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
