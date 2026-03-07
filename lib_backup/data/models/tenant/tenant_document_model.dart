import 'package:cloud_firestore/cloud_firestore.dart';

enum DocumentType {
  aadhar,
  pan,
  rentalAgreement,
  other,
}

class TenantDocument {
  final String? id;
  final String tenantId;
  final DocumentType type;
  final String documentUrl;
  final String? fileName;
  final DateTime uploadedAt;
  final DateTime? updatedAt;

  TenantDocument({
    this.id,
    required this.tenantId,
    required this.type,
    required this.documentUrl,
    this.fileName,
    required this.uploadedAt,
    this.updatedAt,
  });

  String get typeName {
    switch (type) {
      case DocumentType.aadhar:
        return 'Aadhaar Card';
      case DocumentType.pan:
        return 'PAN Card';
      case DocumentType.rentalAgreement:
        return 'Rental Agreement';
      case DocumentType.other:
        return 'Other Document';
    }
  }

  factory TenantDocument.fromMap(Map<String, dynamic> map, String id) {
    return TenantDocument(
      id: id,
      tenantId: map['tenantId']?.toString() ?? '',
      type: _parseDocumentType(map['type']?.toString() ?? ''),
      documentUrl: map['documentUrl']?.toString() ?? '',
      fileName: map['fileName']?.toString(),
      uploadedAt: (map['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static DocumentType _parseDocumentType(String type) {
    switch (type.toLowerCase()) {
      case 'aadhar':
      case 'aadhaar':
        return DocumentType.aadhar;
      case 'pan':
        return DocumentType.pan;
      case 'rental_agreement':
      case 'rentalagreement':
        return DocumentType.rentalAgreement;
      default:
        return DocumentType.other;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId,
      'type': type.toString().split('.').last,
      'documentUrl': documentUrl,
      'fileName': fileName,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

