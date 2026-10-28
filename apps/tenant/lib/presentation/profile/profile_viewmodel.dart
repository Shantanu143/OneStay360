// lib/presentation/profile/profile_viewmodel.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_services/services/image_service.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:models/tenant/tenant_document_model.dart';

import '../common/phone_format.dart';

/// Where ID documents are stored. Firebase Storage in the app, faked in tests.
abstract class DocumentStore {
  Future<String> upload(XFile file, String tenantId, String type);

  Future<void> delete(String url);
}

class StorageDocumentStore implements DocumentStore {
  ImageService? _service;
  ImageService get _images => _service ??= ImageService();

  @override
  Future<String> upload(XFile file, String tenantId, String type) => _images.uploadTenantDocument(file, tenantId, type);

  @override
  Future<void> delete(String url) => _images.deleteImages([url]);
}

/// Text fields on the profile, with their Firestore keys.
enum ProfileField {
  name('name', 'Full name'),
  phone('mobileNumber', 'Mobile number'),
  altPhone('alternatePhone', 'Alternate number'),
  emergencyName('emergencyContactName', 'Emergency contact'),
  emergencyPhone('emergencyContactPhone', 'Emergency number'),
  workName('officeInstituteName', 'Office or college'),
  workId('officeInstituteId', 'Employee or student ID'),
  idNumber('idNumber', 'Aadhaar number'),
  address('addressLine1', 'Permanent address'),
  city('city', 'City'),
  pincode('pincode', 'PIN code');

  const ProfileField(this.key, this.label);

  final String key;
  final String label;
}

/// Editing the tenant's personal details, KYC and ID documents.
///
/// Identity (name, phone, email) is kept on `users/{uid}`; the details owners
/// see live on `tenants/{tenantId}`.
class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    required FirebaseFirestore firestore,
    required this.uid,
    required this.email,
    DocumentStore? store,
  })  : _fs = firestore,
        _store = store ?? StorageDocumentStore();

  final FirebaseFirestore _fs;
  final String uid;
  final String email;
  final DocumentStore _store;

  static const genders = ['Male', 'Female', 'Other'];
  static const nationalities = ['Indian', 'Other'];
  static const languages = [
    'Hindi', 'English', 'Marathi', 'Kannada', 'Tamil', 'Telugu', 'Bengali', 'Gujarati', //
    'Malayalam', 'Punjabi', 'Odia', 'Urdu', 'Assamese', 'Other',
  ];

  final Map<ProfileField, String> _values = {for (final f in ProfileField.values) f: ''};
  String? _gender;
  DateTime? _dob;
  String _nationality = 'Indian';
  String? _language;
  String? _tenantId;
  List<TenantDocument> _documents = const [];
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  bool _attempted = false;
  String? _error;
  bool _disposed = false;

  bool get loading => _loading;
  bool get saving => _saving;
  bool get uploading => _uploading;
  String? get error => _error;
  String? get tenantId => _tenantId;
  String? get gender => _gender;
  DateTime? get dateOfBirth => _dob;
  String get nationality => _nationality;
  String? get language => _language;
  List<TenantDocument> get documents => _documents;
  bool get canUploadDocuments => _tenantId != null;

  String value(ProfileField f) => _values[f]!;

  /// What owners need before move-in, in order.
  Map<String, bool> get _required => {
        'Full name': value(ProfileField.name).trim().isNotEmpty,
        'Mobile number': value(ProfileField.phone).trim().isNotEmpty,
        'Gender': _gender != null,
        'Date of birth': _dob != null,
        'Aadhaar number': value(ProfileField.idNumber).trim().isNotEmpty,
        'Permanent address': value(ProfileField.address).trim().isNotEmpty,
        'City': value(ProfileField.city).trim().isNotEmpty,
        'PIN code': value(ProfileField.pincode).trim().isNotEmpty,
      };

  double get completion => _required.values.where((v) => v).length / _required.length;
  bool get isComplete => _required.values.every((v) => v);
  List<String> get missing => [for (final e in _required.entries) if (!e.value) e.key];

  String? errorFor(ProfileField f) {
    if (!_attempted) return null;
    final v = value(f).trim();
    String? phone(bool required) {
      if (v.isEmpty) return required ? 'Enter your mobile number.' : null;
      return normalizePhoneNumber(v) == null ? 'Enter a 10-digit mobile number.' : null;
    }

    return switch (f) {
      ProfileField.name => v.isEmpty ? 'Enter your name.' : null,
      ProfileField.phone => phone(true),
      ProfileField.altPhone || ProfileField.emergencyPhone => phone(false),
      ProfileField.pincode => v.isNotEmpty && !RegExp(r'^\d{6}$').hasMatch(v) ? 'PIN codes have 6 digits.' : null,
      ProfileField.idNumber =>
        v.isNotEmpty && !RegExp(r'^\d{12}$').hasMatch(v.replaceAll(' ', '')) ? 'Aadhaar numbers have 12 digits.' : null,
      _ => null,
    };
  }

  bool get _valid => ProfileField.values.every((f) => errorFor(f) == null);

  void set(ProfileField f, String v) => _change(() => _values[f] = v);
  void setGender(String? v) => _change(() => _gender = v);
  void setDateOfBirth(DateTime? v) => _change(() => _dob = v);
  void setNationality(String v) => _change(() => _nationality = v);
  void setLanguage(String? v) => _change(() => _language = v);

  void _change(VoidCallback change) {
    change();
    _error = null;
    _notify();
  }

  Future<void> load() async {
    _loading = true;
    _notify();
    try {
      final user = (await _fs.doc('users/$uid').get()).data() ?? {};
      final data = Map<String, dynamic>.from(user);
      final tid = user['tenantId']?.toString();
      _tenantId = tid == null || tid.isEmpty ? null : tid;
      if (_tenantId != null) {
        try {
          data.addAll((await _fs.doc('tenants/$_tenantId').get()).data() ?? {});
        } catch (e) {
          debugPrint('⚠️ [Profile] tenant doc: $e');
        }
      }
      String text(Object? v) => v?.toString().trim() ?? '';
      for (final f in ProfileField.values) {
        _values[f] = text(data[f.key]);
      }
      _values[ProfileField.name] = text(data['name']).isNotEmpty ? text(data['name']) : text(data['fullName']);
      if (_values[ProfileField.phone]!.isEmpty) _values[ProfileField.phone] = text(data['phone']);
      final g = text(data['gender']);
      _gender = genders.contains(g) ? g : null;
      final dob = data['dateOfBirth'];
      _dob = dob is Timestamp ? dob.toDate() : (dob is DateTime ? dob : null);
      _nationality = nationalities.contains(text(data['nationality'])) ? text(data['nationality']) : 'Indian';
      final lang = text(data['motherTongue']);
      _language = languages.contains(lang) ? lang : null;
      await _loadDocuments();
    } catch (e) {
      debugPrint('❌ [Profile] load: $e');
      _error = "Couldn't load your profile. Pull down to try again.";
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> _loadDocuments() async {
    if (_tenantId == null) return;
    try {
      final snap = await _fs.collection('tenants/$_tenantId/documents').orderBy('uploadedAt', descending: true).get();
      _documents = snap.docs.map((d) => TenantDocument.fromMap(d.data(), d.id)).toList();
    } catch (e) {
      debugPrint('⚠️ [Profile] documents: $e');
    }
  }

  Future<bool> save() async {
    if (_saving) return false;
    _attempted = true;
    if (!_valid) {
      _notify();
      return false;
    }
    _saving = true;
    _error = null;
    _notify();
    try {
      final name = value(ProfileField.name).trim();
      final phone = value(ProfileField.phone).trim();
      final complete = isComplete;
      await _fs.doc('users/$uid').set({
        'name': name,
        'fullName': name,
        'mobileNumber': phone,
        'phone': phone,
        'email': email,
        'userType': 'tenant',
        'tenantId': ?_tenantId,
        'profileComplete': complete,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (_tenantId != null) {
        await _fs.doc('tenants/$_tenantId').set({
          for (final f in ProfileField.values) f.key: value(f).trim(),
          'fullName': name,
          'phone': phone,
          'gender': _gender,
          'dateOfBirth': _dob == null ? null : Timestamp.fromDate(_dob!),
          'nationality': _nationality,
          'motherTongue': _language,
          'idType': 'Aadhaar',
          'profileComplete': complete,
          'userId': uid,
          'tenantId': _tenantId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return true;
    } catch (e) {
      debugPrint('❌ [Profile] save: $e');
      _error = "Couldn't save. Check your connection and try again.";
      return false;
    } finally {
      _saving = false;
      _notify();
    }
  }

  Future<bool> uploadDocument(DocumentType type, XFile file) async {
    final tid = _tenantId;
    if (tid == null || _uploading) return false;
    _uploading = true;
    _error = null;
    _notify();
    try {
      final url = await _store.upload(file, tid, type.name);
      await _fs.collection('tenants/$tid/documents').add({
        'tenantId': tid,
        'type': type.name,
        'documentUrl': url,
        'fileName': file.name,
        'uploadedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _loadDocuments();
      return true;
    } catch (e) {
      debugPrint('❌ [Profile] upload: $e');
      _error = "Couldn't upload that file. Try again.";
      return false;
    } finally {
      _uploading = false;
      _notify();
    }
  }

  Future<bool> deleteDocument(TenantDocument doc) async {
    final tid = _tenantId;
    if (tid == null || doc.id == null) return false;
    try {
      if (doc.documentUrl.isNotEmpty) {
        try {
          await _store.delete(doc.documentUrl);
        } catch (e) {
          debugPrint('⚠️ [Profile] storage delete: $e');
        }
      }
      await _fs.doc('tenants/$tid/documents/${doc.id}').delete();
      await _loadDocuments();
      _notify();
      return true;
    } catch (e) {
      debugPrint('❌ [Profile] delete: $e');
      _error = "Couldn't delete that document. Try again.";
      _notify();
      return false;
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
