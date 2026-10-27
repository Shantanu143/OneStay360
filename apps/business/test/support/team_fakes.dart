import 'dart:async';

import 'package:business/presentation/team/invite_form_viewmodel.dart';
import 'package:business/presentation/team/team_models.dart';
import 'package:business/presentation/team/team_source.dart';

TeamMember member(
  String uid,
  String name, {
  String role = 'manager',
  String status = 'active',
  String? phone,
  String? email,
}) =>
    TeamMember(uid: uid, name: name, role: role, status: status, phone: phone, email: email);

class FakeTeamSource implements TeamSource {
  FakeTeamSource({
    List<TeamMember>? members,
    this.properties = const [
      TeamProperty(id: 'P1', name: 'Sunrise Boys PG'),
      TeamProperty(id: 'P2', name: 'Lotus Ladies Hostel'),
    ],
    List<TeamInvite>? invites,
    Map<String, Set<String>>? access,
  })  : members = members ?? [],
        invites = invites ?? [],
        access = access ?? {};

  List<TeamMember> members;
  final List<TeamProperty> properties;
  List<TeamInvite> invites;
  Map<String, Set<String>> access;

  Object? membersFailure;
  Object? propertiesFailure;
  Object? inviteFailure;
  Object? updateFailure;
  Object? activeFailure;
  Object? accessFailure;
  Completer<void>? membersGate;

  final calls = <String>[];
  final invited = <InviteRequest>[];
  final updates = <({String uid, String role, List<String> propertyIds})>[];
  final _sinks = <StreamController<List<TeamMember>>>[];

  /// Pushes a new member list to everyone watching.
  void emit(List<TeamMember> next) {
    members = next;
    for (final c in List.of(_sinks)) {
      c.add(next);
    }
  }

  void emitError(Object error) {
    for (final c in List.of(_sinks)) {
      c.addError(error);
    }
  }

  @override
  Stream<List<TeamMember>> watchMembers(String businessId) {
    calls.add('watchMembers');
    final c = StreamController<List<TeamMember>>();
    _sinks.add(c);
    c.onCancel = () => _sinks.remove(c);
    () async {
      if (membersGate != null) await membersGate!.future;
      if (membersFailure != null) {
        c.addError(membersFailure!);
      } else if (!c.isClosed) {
        c.add(members);
      }
    }();
    return c.stream;
  }

  @override
  Future<List<TeamProperty>> loadProperties(String businessId) async {
    calls.add('loadProperties');
    if (propertiesFailure != null) throw propertiesFailure!;
    return properties;
  }

  @override
  Future<List<TeamInvite>> loadPendingInvites(String businessId) async {
    calls.add('loadPendingInvites');
    return invites;
  }

  @override
  Future<Map<String, Set<String>>> loadAccess(String businessId, List<TeamProperty> properties) async {
    calls.add('loadAccess');
    if (accessFailure != null) throw accessFailure!;
    return access;
  }

  @override
  Future<InviteResult> invite(String businessId, InviteRequest request) async {
    calls.add('invite');
    if (inviteFailure != null) throw inviteFailure!;
    invited.add(request);
    final id = 'inv${invited.length}';
    invites = [
      ...invites,
      TeamInvite(
        id: id,
        phone: request.phone,
        email: request.email,
        role: request.role,
        propertyIds: request.propertyIds,
        createdAt: DateTime(2026, 10, 26),
        expiresAt: DateTime(2026, 11, 2),
      ),
    ];
    return InviteResult(id: id, link: 'https://app.example.test/invite?inviteId=$id');
  }

  @override
  Future<void> updateAccess({
    required String businessId,
    required String memberUid,
    required String role,
    required List<String> propertyIds,
  }) async {
    calls.add('updateAccess');
    if (updateFailure != null) throw updateFailure!;
    updates.add((uid: memberUid, role: role, propertyIds: propertyIds));
    access = {...access, memberUid: propertyIds.toSet()};
  }

  @override
  Future<void> setMemberActive(String businessId, String memberUid, {required bool active}) async {
    calls.add('setMemberActive:$memberUid:$active');
    if (activeFailure != null) throw activeFailure!;
    emit([
      for (final m in members)
        if (m.uid == memberUid)
          TeamMember(
            uid: m.uid,
            name: m.name,
            role: m.role,
            status: active ? 'active' : 'disabled',
            phone: m.phone,
            email: m.email,
          )
        else
          m,
    ]);
  }

  void dispose() {
    for (final c in List.of(_sinks)) {
      c.close();
    }
  }
}
