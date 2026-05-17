import 'package:flutter/foundation.dart';
import '../../models/payment_method_model.dart';
import '../../services/payment_method_service.dart';

class PaymentMethodsViewModel extends ChangeNotifier {
  final PaymentMethodService _service = PaymentMethodService();

  List<PaymentMethod> _paymentMethods = [];
  bool _isLoading = false;
  String _error = '';

  List<PaymentMethod> get paymentMethods => _paymentMethods;
  bool get isLoading => _isLoading;
  String get error => _error;

  // Load payment methods for a business
  Future<void> loadPaymentMethods(String businessId) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      _paymentMethods = await _service.getPaymentMethods(businessId);
      debugPrint('✅ Loaded ${_paymentMethods.length} payment methods');
    } catch (e) {
      _error = 'Failed to load payment methods: $e';
      debugPrint('❌ Error: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new payment method
  Future<bool> addPaymentMethod(String businessId, PaymentMethod method) async {
    try {
      if (method.type.toLowerCase() == 'razorpay') {
        final alreadyExists = _paymentMethods.any((m) => m.type.toLowerCase() == 'razorpay');
        if (alreadyExists) {
          _error = 'Razorpay is already configured for this business.';
          notifyListeners();
          return false;
        }
      }

      final newMethod = PaymentMethod(
        id: '', // Will be set by service
        businessId: businessId,
        type: method.type,
        upiId: method.upiId,
        phoneNumber: method.phoneNumber,
        accountHolderName: method.accountHolderName,
        accountNumber: method.accountNumber,
        ifscCode: method.ifscCode,
        bankName: method.bankName,
        accountType: method.accountType,
        isActive: true,
        isPreferred: _paymentMethods.isEmpty, // First method is preferred
        createdAt: DateTime.now(),
      );

      await _service.addPaymentMethod(newMethod);
      await loadPaymentMethods(businessId);
      return true;
    } catch (e) {
      _error = 'Failed to add payment method: $e';
      debugPrint('❌ Error: $_error');
      notifyListeners();
      return false;
    }
  }

  // Update payment method
  Future<bool> updatePaymentMethod(PaymentMethod method) async {
    try {
      await _service.updatePaymentMethod(method);
      await loadPaymentMethods(method.businessId);
      return true;
    } catch (e) {
      _error = 'Failed to update payment method: $e';
      debugPrint('❌ Error: $_error');
      notifyListeners();
      return false;
    }
  }

  // Delete payment method
  Future<bool> deletePaymentMethod(String businessId, String methodId) async {
    try {
      await _service.deletePaymentMethod(businessId, methodId);
      await loadPaymentMethods(businessId);
      return true;
    } catch (e) {
      _error = 'Failed to delete payment method: $e';
      debugPrint('❌ Error: $_error');
      notifyListeners();
      return false;
    }
  }

  // Set preferred payment method
  Future<bool> setPreferredPaymentMethod(
      String businessId, String methodId) async {
    try {
      await _service.setPreferredPaymentMethod(businessId, methodId);
      await loadPaymentMethods(businessId);
      return true;
    } catch (e) {
      _error = 'Failed to set preferred payment method: $e';
      debugPrint('❌ Error: $_error');
      notifyListeners();
      return false;
    }
  }

  // Toggle payment method active status
  Future<bool> togglePaymentMethodStatus(
      PaymentMethod method, bool isActive) async {
    try {
      final updated = method.copyWith(isActive: isActive);
      await _service.updatePaymentMethod(updated);
      await loadPaymentMethods(method.businessId);
      return true;
    } catch (e) {
      _error = 'Failed to update payment method status: $e';
      debugPrint('❌ Error: $_error');
      notifyListeners();
      return false;
    }
  }

  // Get active payment methods only
  Future<List<PaymentMethod>> getActiveMethods(String businessId) async {
    try {
      return await _service.getActivePaymentMethods(businessId);
    } catch (e) {
      debugPrint('❌ Error getting active methods: $e');
      return [];
    }
  }

  // Clear error
  void clearError() {
    _error = '';
    notifyListeners();
  }
}
