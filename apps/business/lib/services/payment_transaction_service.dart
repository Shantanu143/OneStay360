import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/payment_transaction_model.dart';

/// Service for recording and reading immutable payment transactions.
///
/// DESIGN PRINCIPLE:
/// This service ONLY creates and reads transactions. No update. No delete.
/// Transactions are append-only records for accounting integrity.
/// If a transaction needs correction, a new transaction is created instead.
///
/// All operations are scoped to a business (businessId is mandatory).
class PaymentTransactionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  PaymentTransactionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Create a new payment transaction (append-only).
  ///
  /// REQUIREMENTS:
  /// - businessId must not be empty (mandatory for multi-tenant isolation)
  /// - amount must be positive
  /// - mode must be one of: "upi", "bank", "cash"
  /// - currency defaults to "INR"
  /// - createdAt is set by Firestore server timestamp (not client-side)
  /// - Only records the transaction; does NOT validate payment method existence
  ///
  /// Returns the created transaction with Firestore-generated ID.
  /// Throws if validation fails.
  Future<PaymentTransaction> createTransaction({
    required String businessId,
    required String tenantId,
    required String propertyId,
    required String paymentMethodId,
    required double amount,
    required String mode,
    String? referenceId,
    String? currency,
  }) async {
    // VALIDATION: businessId is mandatory
    if (businessId.isEmpty) {
      throw ArgumentError('businessId must not be empty');
    }

    if (tenantId.isEmpty) {
      throw ArgumentError('tenantId must not be empty');
    }

    if (propertyId.isEmpty) {
      throw ArgumentError('propertyId must not be empty');
    }

    if (paymentMethodId.isEmpty) {
      throw ArgumentError('paymentMethodId must not be empty');
    }

    if (amount <= 0) {
      throw ArgumentError('amount must be positive');
    }

    final validModes = ['upi', 'bank', 'cash'];
    if (!validModes.contains(mode)) {
      throw ArgumentError('mode must be one of: upi, bank, cash');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User must be authenticated to create transaction');
    }

    try {
      // Create new document with auto-generated ID
      final docRef = _firestore.collection('payment_transactions').doc();

      final transactionData = {
        'businessId': businessId,
        'tenantId': tenantId,
        'propertyId': propertyId,
        'paymentMethodId': paymentMethodId,
        'amount': amount,
        'currency': currency ?? 'INR',
        'mode': mode,
        'referenceId': referenceId,
        'createdAt': FieldValue.serverTimestamp(), // Server-side timestamp
        'createdBy': user.uid,
      };

      // Write to Firestore
      await docRef.set(transactionData);

      // Fetch the created document to get the server timestamp
      final createdDoc = await docRef.get();
      return PaymentTransaction.fromFirestore(createdDoc);
    } catch (e) {
      throw Exception('Failed to create payment transaction: $e');
    }
  }

  /// Get all transactions for a tenant in a business.
  /// Scoped to businessId for multi-tenant isolation.
  Future<List<PaymentTransaction>> getTransactionsForTenant(
    String businessId,
    String tenantId,
  ) async {
    if (businessId.isEmpty || tenantId.isEmpty) {
      throw ArgumentError('businessId and tenantId must not be empty');
    }

    try {
      final snapshot = await _firestore
          .collection('payment_transactions')
          .where('businessId', isEqualTo: businessId)
          .where('tenantId', isEqualTo: tenantId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PaymentTransaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch tenant transactions: $e');
    }
  }

  /// Get all transactions for a property in a business.
  /// Scoped to businessId for multi-tenant isolation.
  Future<List<PaymentTransaction>> getTransactionsForProperty(
    String businessId,
    String propertyId,
  ) async {
    if (businessId.isEmpty || propertyId.isEmpty) {
      throw ArgumentError('businessId and propertyId must not be empty');
    }

    try {
      final snapshot = await _firestore
          .collection('payment_transactions')
          .where('businessId', isEqualTo: businessId)
          .where('propertyId', isEqualTo: propertyId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PaymentTransaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch property transactions: $e');
    }
  }

  /// Stream transactions for a tenant (real-time updates).
  /// Useful for displaying transaction history as it updates.
  Stream<List<PaymentTransaction>> streamTransactionsForTenant(
    String businessId,
    String tenantId,
  ) {
    if (businessId.isEmpty || tenantId.isEmpty) {
      return Stream.empty();
    }

    return _firestore
        .collection('payment_transactions')
        .where('businessId', isEqualTo: businessId)
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentTransaction.fromFirestore(doc))
            .toList());
  }

  /// Stream transactions for a property (real-time updates).
  Stream<List<PaymentTransaction>> streamTransactionsForProperty(
    String businessId,
    String propertyId,
  ) {
    if (businessId.isEmpty || propertyId.isEmpty) {
      return Stream.empty();
    }

    return _firestore
        .collection('payment_transactions')
        .where('businessId', isEqualTo: businessId)
        .where('propertyId', isEqualTo: propertyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentTransaction.fromFirestore(doc))
            .toList());
  }
}
