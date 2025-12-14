import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_method_model.dart';

class PaymentMethodService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a new payment method
  Future<String> addPaymentMethod(PaymentMethod paymentMethod) async {
    try {
      final docRef = _firestore
          .collection('businesses')
          .doc(paymentMethod.businessId)
          .collection('paymentMethods')
          .doc();

      final newMethod = paymentMethod.copyWith(id: docRef.id);
      await docRef.set(newMethod.toFirestore());

      print('✅ Payment method added: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error adding payment method: $e');
      rethrow;
    }
  }

  // Update payment method
  Future<void> updatePaymentMethod(PaymentMethod paymentMethod) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(paymentMethod.businessId)
          .collection('paymentMethods')
          .doc(paymentMethod.id)
          .update({
        ...paymentMethod.toFirestore(),
        'updatedAt': DateTime.now(),
      });

      print('✅ Payment method updated: ${paymentMethod.id}');
    } catch (e) {
      print('❌ Error updating payment method: $e');
      rethrow;
    }
  }

  // Delete payment method
  Future<void> deletePaymentMethod(String businessId, String methodId) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('paymentMethods')
          .doc(methodId)
          .delete();

      print('✅ Payment method deleted: $methodId');
    } catch (e) {
      print('❌ Error deleting payment method: $e');
      rethrow;
    }
  }

  // Get all payment methods for a business
  Future<List<PaymentMethod>> getPaymentMethods(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('paymentMethods')
          .get();

      final methods = snapshot.docs
          .map((doc) => PaymentMethod.fromFirestore(doc.data()))
          .toList();

      // Sort in memory: preferred first, then by created date
      methods.sort((a, b) {
        if (a.isPreferred != b.isPreferred) {
          return a.isPreferred ? -1 : 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

      print('✅ Loaded ${methods.length} payment methods for business: $businessId');
      return methods;
    } catch (e) {
      print('❌ Error loading payment methods: $e');
      rethrow;
    }
  }

  // Get active payment methods
  Future<List<PaymentMethod>> getActivePaymentMethods(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('paymentMethods')
          .where('isActive', isEqualTo: true)
          .get();

      final methods = snapshot.docs
          .map((doc) => PaymentMethod.fromFirestore(doc.data()))
          .toList();

      // Sort in memory: preferred first
      methods.sort((a, b) => a.isPreferred ? -1 : 1);

      return methods;
    } catch (e) {
      print('❌ Error loading active payment methods: $e');
      rethrow;
    }
  }

  // Set preferred payment method
  Future<void> setPreferredPaymentMethod(
      String businessId, String methodId) async {
    try {
      // First, unset all preferred methods
      final batch = _firestore.batch();

      final allMethods = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('paymentMethods')
          .where('isPreferred', isEqualTo: true)
          .get();

      for (var doc in allMethods.docs) {
        batch.update(doc.reference, {'isPreferred': false});
      }

      // Set the new preferred method
      batch.update(
        _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('paymentMethods')
            .doc(methodId),
        {'isPreferred': true},
      );

      await batch.commit();
      print('✅ Preferred payment method set to: $methodId');
    } catch (e) {
      print('❌ Error setting preferred payment method: $e');
      rethrow;
    }
  }

  // Get preferred payment method
  Future<PaymentMethod?> getPreferredPaymentMethod(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('paymentMethods')
          .where('isPreferred', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return PaymentMethod.fromFirestore(snapshot.docs.first.data());
    } catch (e) {
      print('❌ Error getting preferred payment method: $e');
      return null;
    }
  }

  // Stream payment methods
  Stream<List<PaymentMethod>> streamPaymentMethods(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('paymentMethods')
        .orderBy('isPreferred', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentMethod.fromFirestore(doc.data()))
            .toList());
  }
}
