// lib/presentation/profile/firestore_kyc_source.dart
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'kyc_viewmodel.dart';

/// Reads and writes the `kyc` map on the business document; documents go to
/// Storage under `business_documents/{businessId}/`.
class FirestoreKycSource implements KycSource {
  FirestoreKycSource({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _fs = firestore ?? FirebaseFirestore.instance,
      _storage = storage;

  final FirebaseFirestore _fs;
  final FirebaseStorage? _storage;

  DocumentReference<Map<String, dynamic>> _doc(String businessId) =>
      _fs.collection('businesses').doc(businessId);

  @override
  Future<Kyc> load(String businessId) async {
    final data = (await _doc(businessId).get()).data();
    final kyc = data?['kyc'];
    if (kyc is! Map) return const Kyc();
    final docs = kyc['documents'];
    return Kyc(
      gstin: kyc['gstin']?.toString() ?? '',
      pan: kyc['pan']?.toString() ?? '',
      address: kyc['address']?.toString() ?? '',
      documents: {
        if (docs is Map)
          for (final e in docs.entries)
            if (e.value is Map && (e.value as Map)['url'] != null)
              e.key.toString(): (e.value as Map)['url'].toString(),
      },
    );
  }

  @override
  Future<void> save(String businessId, Kyc kyc) {
    // Dotted paths update only these fields and leave `documents` alone.
    return _doc(businessId).update({
      'kyc.gstin': kyc.gstin,
      'kyc.pan': kyc.pan,
      'kyc.address': kyc.address,
      'kyc.updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<String> uploadDocument(
    String businessId,
    String kind,
    String fileName,
    Uint8List bytes,
  ) async {
    final storage = _storage ?? FirebaseStorage.instance;
    final lower = fileName.toLowerCase();
    final ext = lower.endsWith('.png')
        ? 'png'
        : lower.endsWith('.pdf')
        ? 'pdf'
        : 'jpg';
    final type = ext == 'pdf'
        ? 'application/pdf'
        : 'image/${ext == 'png' ? 'png' : 'jpeg'}';
    final ref = storage
        .ref()
        .child('business_documents')
        .child(businessId)
        .child('${kind}_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await ref.putData(bytes, SettableMetadata(contentType: type));
    final url = await ref.getDownloadURL();
    await _doc(businessId).update({
      'kyc.documents.$kind': {
        'url': url,
        'uploadedAt': FieldValue.serverTimestamp(),
      },
    });
    return url;
  }
}

/// Picks a photo of a certificate from the gallery.
class GalleryDocumentPicker implements DocumentPicker {
  GalleryDocumentPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedDocument?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (file == null) return null;
    return PickedDocument(file.name, await file.readAsBytes());
  }
}
