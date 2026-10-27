// lib/presentation/profile/kyc_viewmodel.dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// The business's compliance details.
class Kyc {
  const Kyc({
    this.gstin = '',
    this.pan = '',
    this.address = '',
    this.documents = const {},
  });

  final String gstin;
  final String pan;
  final String address;

  /// Document kind ('incorporation', 'gst') to where it is stored.
  final Map<String, String> documents;

  Kyc copyWith({
    String? gstin,
    String? pan,
    String? address,
    Map<String, String>? documents,
  }) => Kyc(
    gstin: gstin ?? this.gstin,
    pan: pan ?? this.pan,
    address: address ?? this.address,
    documents: documents ?? this.documents,
  );
}

class PickedDocument {
  const PickedDocument(this.name, this.bytes);

  final String name;
  final Uint8List bytes;
}

/// Lets the owner choose a photo of a certificate.
abstract class DocumentPicker {
  Future<PickedDocument?> pick();
}

abstract class KycSource {
  Future<Kyc> load(String businessId);
  Future<void> save(String businessId, Kyc kyc);

  /// Stores the file and records where; returns its URL.
  Future<String> uploadDocument(
    String businessId,
    String kind,
    String fileName,
    Uint8List bytes,
  );
}

class KycViewModel extends ChangeNotifier {
  KycViewModel({
    required this.businessId,
    required KycSource source,
    required DocumentPicker picker,
  }) : _source = source,
       _picker = picker;

  final String businessId;
  final KycSource _source;
  final DocumentPicker _picker;
  bool _disposed = false;

  static final _gstin = RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');
  static final _pan = RegExp(r'^[A-Z]{5}\d{4}[A-Z]$');

  Kyc _kyc = const Kyc();
  bool _loading = true;
  bool _saving = false;
  String? _uploading;
  String? _error;
  String? _gstinError;
  String? _panError;

  Kyc get kyc => _kyc;
  bool get loading => _loading;
  bool get saving => _saving;

  /// The kind of document being uploaded right now.
  String? get uploading => _uploading;
  String? get error => _error;
  String? get gstinError => _gstinError;
  String? get panError => _panError;
  bool hasDocument(String kind) => _kyc.documents.containsKey(kind);

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      _kyc = await _source.load(businessId);
    } catch (e) {
      debugPrint('❌ [Kyc] load: $e');
      _error = "Couldn't load your KYC details.";
    } finally {
      _loading = false;
      _notify();
    }
  }

  void setGstin(String v) {
    _kyc = _kyc.copyWith(gstin: v);
    _gstinError = null;
    _notify();
  }

  void setPan(String v) {
    _kyc = _kyc.copyWith(pan: v);
    _panError = null;
    _notify();
  }

  void setAddress(String v) {
    _kyc = _kyc.copyWith(address: v);
    _notify();
  }

  Future<bool> save() async {
    final clean = _kyc.copyWith(
      gstin: _kyc.gstin.trim().toUpperCase(),
      pan: _kyc.pan.trim().toUpperCase(),
      address: _kyc.address.trim(),
    );
    _gstinError = clean.gstin.isNotEmpty && !_gstin.hasMatch(clean.gstin)
        ? 'Enter the 15-character GSTIN, like 22ABCDE1234F1Z5.'
        : null;
    _panError = clean.pan.isNotEmpty && !_pan.hasMatch(clean.pan)
        ? 'Enter a PAN like ABCDE1234F.'
        : null;
    if (_gstinError != null || _panError != null) {
      _notify();
      return false;
    }

    _saving = true;
    _error = null;
    _notify();
    try {
      await _source.save(businessId, clean);
      _kyc = clean;
      return true;
    } catch (e) {
      debugPrint('❌ [Kyc] save: $e');
      _error = "Couldn't save. Try again.";
      return false;
    } finally {
      _saving = false;
      _notify();
    }
  }

  Future<bool> upload(String kind) async {
    final picked = await _picker.pick();
    if (picked == null) return false;
    _uploading = kind;
    _error = null;
    _notify();
    try {
      final url = await _source.uploadDocument(
        businessId,
        kind,
        picked.name,
        picked.bytes,
      );
      _kyc = _kyc.copyWith(documents: {..._kyc.documents, kind: url});
      return true;
    } catch (e) {
      debugPrint('❌ [Kyc] upload: $e');
      _error = "Couldn't upload the document. Try again.";
      return false;
    } finally {
      _uploading = null;
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
