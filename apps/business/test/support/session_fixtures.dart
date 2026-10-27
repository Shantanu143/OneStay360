import 'package:business/data/providers/business_state_provider.dart';
import 'package:business/models/business_membership_model.dart';
import 'package:business/services/business_membership_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

class FakeMembership implements BusinessMembershipService {
  FakeMembership(this.role);
  final String role;

  @override
  Future<BusinessMembership?> getActiveMembership(
    String uid,
    String businessId,
  ) async => BusinessMembership(
    id: uid,
    uid: uid,
    businessId: businessId,
    role: role,
    status: 'active',
    name: 'Rajesh Sharma',
    email: '',
    phone: '',
  );

  @override
  Future<bool> isActiveMember(String uid, String businessId) async => true;

  @override
  Stream<BusinessMembership?> streamActiveMembership(
    String uid,
    String businessId,
  ) => const Stream.empty();
}

/// A signed-in, ready session for [businessId] with the given [role].
///
/// [scope] is the properties a manager or staff member can open; the default
/// (null) lets them open all of them, so tests about something else need not
/// seed access documents.
Future<BusinessStateProvider> readyProvider({
  String role = 'owner',
  String businessId = 'BUS1',
  FakeFirebaseFirestore? firestore,
  Set<String>? scope,
}) async {
  final fs = firestore ?? FakeFirebaseFirestore();
  await fs.collection('users').doc('u1').set({
    'fullName': 'Rajesh Sharma',
    'businessName': 'Apex Living',
    'businessId': businessId,
  });
  final provider = BusinessStateProvider(
    membershipService: FakeMembership(role),
    auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1')),
    firestore: fs,
    membershipRetryDelay: Duration.zero,
    propertyScopeLoader: (_, __, ___) async => scope,
  );
  await provider.loadUserData();
  return provider;
}
