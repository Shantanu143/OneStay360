class PaymentMethod {
  final String id;
  final String businessId;
  final String type; // 'upi', 'bank', 'cash'
  final String? upiId;
  final String? phoneNumber;
  
  // Bank details
  final String? accountHolderName;
  final String? accountNumber;
  final String? ifscCode;
  final String? bankName;
  final String? accountType; // Savings, Current
  
  // Status
  final bool isActive;
  final bool isPreferred;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PaymentMethod({
    required this.id,
    required this.businessId,
    required this.type,
    this.upiId,
    this.phoneNumber,
    this.accountHolderName,
    this.accountNumber,
    this.ifscCode,
    this.bankName,
    this.accountType,
    required this.isActive,
    required this.isPreferred,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert to Firestore JSON
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'businessId': businessId,
      'type': type,
      'upiId': upiId,
      'phoneNumber': phoneNumber,
      'accountHolderName': accountHolderName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
      'bankName': bankName,
      'accountType': accountType,
      'isActive': isActive,
      'isPreferred': isPreferred,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? createdAt,
    };
  }

  // Convert from Firestore JSON
  factory PaymentMethod.fromFirestore(Map<String, dynamic> data) {
    return PaymentMethod(
      id: data['id'] ?? '',
      businessId: data['businessId'] ?? '',
      type: data['type'] ?? 'cash',
      upiId: data['upiId'],
      phoneNumber: data['phoneNumber'],
      accountHolderName: data['accountHolderName'],
      accountNumber: data['accountNumber'],
      ifscCode: data['ifscCode'],
      bankName: data['bankName'],
      accountType: data['accountType'],
      isActive: data['isActive'] ?? true,
      isPreferred: data['isPreferred'] ?? false,
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as dynamic)?.toDate(),
    );
  }

  // Copy with changes
  PaymentMethod copyWith({
    String? id,
    String? businessId,
    String? type,
    String? upiId,
    String? phoneNumber,
    String? accountHolderName,
    String? accountNumber,
    String? ifscCode,
    String? bankName,
    String? accountType,
    bool? isActive,
    bool? isPreferred,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      type: type ?? this.type,
      upiId: upiId ?? this.upiId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      bankName: bankName ?? this.bankName,
      accountType: accountType ?? this.accountType,
      isActive: isActive ?? this.isActive,
      isPreferred: isPreferred ?? this.isPreferred,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
