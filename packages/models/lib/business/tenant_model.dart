class Tenant {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? alternatePhone; // NEW
  final String? address; // NEW (current address)
  final String? nationality; // NEW
  final String? motherTongue; // NEW
  final String? idType; // NEW
  final String? idNumber; // NEW
  final String? idAddress; // NEW
  final String propertyId;
  final String roomId;
  final String bedId;
  final DateTime checkInDate;
  final DateTime? checkOutDate;
  final double monthlyRent;
  final String status; // 'active', 'inactive', 'pending'
  final String? profileImage;
  final String? emergencyContact;
  final String? emergencyContactPhone;
  final String? officeInstituteName; // NEW
  final String? officeInstituteId; // NEW
  final Map<String, dynamic>? additionalInfo;

  Tenant({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.alternatePhone,
    this.address,
    this.nationality,
    this.motherTongue,
    this.idType,
    this.idNumber,
    this.idAddress,
    required this.propertyId,
    required this.roomId,
    required this.bedId,
    required this.checkInDate,
    this.checkOutDate,
    required this.monthlyRent,
    this.status = 'active',
    this.profileImage,
    this.emergencyContact,
    this.emergencyContactPhone,
    this.officeInstituteName,
    this.officeInstituteId,
    this.additionalInfo,
  });

  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      alternatePhone: map['alternatePhone'],
      address: map['address'],
      nationality: map['nationality'],
      motherTongue: map['motherTongue'],
      idType: map['idType'],
      idNumber: map['idNumber'],
      idAddress: map['idAddress'],
      propertyId: map['propertyId'] ?? '',
      roomId: map['roomId'] ?? '',
      bedId: map['bedId'] ?? '',
      checkInDate: DateTime.parse(map['checkInDate']),
      checkOutDate: map['checkOutDate'] != null ? DateTime.parse(map['checkOutDate']) : null,
      monthlyRent: (map['monthlyRent'] ?? 0).toDouble(),
      status: map['status'] ?? 'active',
      profileImage: map['profileImage'],
      emergencyContact: map['emergencyContact'],
      emergencyContactPhone: map['emergencyContactPhone'],
      officeInstituteName: map['officeInstituteName'],
      officeInstituteId: map['officeInstituteId'],
      additionalInfo: map['additionalInfo'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'alternatePhone': alternatePhone,
      'address': address,
      'nationality': nationality,
      'motherTongue': motherTongue,
      'idType': idType,
      'idNumber': idNumber,
      'idAddress': idAddress,
      'propertyId': propertyId,
      'roomId': roomId,
      'bedId': bedId,
      'checkInDate': checkInDate.toIso8601String(),
      'checkOutDate': checkOutDate?.toIso8601String(),
      'monthlyRent': monthlyRent,
      'status': status,
      'profileImage': profileImage,
      'emergencyContact': emergencyContact,
      'emergencyContactPhone': emergencyContactPhone,
      'officeInstituteName': officeInstituteName,
      'officeInstituteId': officeInstituteId,
      'additionalInfo': additionalInfo,
    };
  }

  Tenant copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? alternatePhone,
    String? address,
    String? nationality,
    String? motherTongue,
    String? idType,
    String? idNumber,
    String? idAddress,
    String? propertyId,
    String? roomId,
    String? bedId,
    DateTime? checkInDate,
    DateTime? checkOutDate,
    double? monthlyRent,
    String? status,
    String? profileImage,
    String? emergencyContact,
    String? emergencyContactPhone,
    String? officeInstituteName,
    String? officeInstituteId,
    Map<String, dynamic>? additionalInfo,
  }) {
    return Tenant(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      alternatePhone: alternatePhone ?? this.alternatePhone,
      address: address ?? this.address,
      nationality: nationality ?? this.nationality,
      motherTongue: motherTongue ?? this.motherTongue,
      idType: idType ?? this.idType,
      idNumber: idNumber ?? this.idNumber,
      idAddress: idAddress ?? this.idAddress,
      propertyId: propertyId ?? this.propertyId,
      roomId: roomId ?? this.roomId,
      bedId: bedId ?? this.bedId,
      checkInDate: checkInDate ?? this.checkInDate,
      checkOutDate: checkOutDate ?? this.checkOutDate,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      status: status ?? this.status,
      profileImage: profileImage ?? this.profileImage,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      officeInstituteName: officeInstituteName ?? this.officeInstituteName,
      officeInstituteId: officeInstituteId ?? this.officeInstituteId,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }
}

