// lib/presentation/profile/my_details_source.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Where a person's own name and contact details are saved. Faked in tests.
abstract class MyDetailsSource {
  Future<void> save({
    required String businessId,
    required String uid,
    required String name,
    String? email,
    String? phone,
  });
}

/// Saves to both places that carry the name: the team record (what the owner
/// sees) and the person's own profile (what the greeting reads).
class FirestoreMyDetailsSource implements MyDetailsSource {
  FirestoreMyDetailsSource({FirebaseFirestore? firestore}) : _fs = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _fs;

  @override
  Future<void> save({
    required String businessId,
    required String uid,
    required String name,
    String? email,
    String? phone,
  }) async {
    final batch = _fs.batch();
    batch.set(
      _fs.collection('businesses').doc(businessId).collection('members').doc(uid),
      {
        'name': name,
        'displayName': name,
        'email': email ?? FieldValue.delete(),
        'phone': phone ?? FieldValue.delete(),
        'updatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    // The sign-in number on the profile belongs to the account and is left alone.
    batch.set(
      _fs.collection('users').doc(uid),
      {'fullName': name, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    await batch.commit();
  }
}
