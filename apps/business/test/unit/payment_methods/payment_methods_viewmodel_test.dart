import 'package:business/models/payment_method_model.dart';
import 'package:business/presentation/view_models/payment_methods_viewmodel.dart';
import 'package:business/services/payment_method_service.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryService implements PaymentMethodService {
  MemoryService(this.stored);

  final List<PaymentMethod> stored;
  bool failReads = false;

  @override
  Future<List<PaymentMethod>> getPaymentMethods(String businessId) async {
    if (failReads) throw Exception('offline');
    return [...stored];
  }

  @override
  Future<String> addPaymentMethod(PaymentMethod m) async {
    stored.add(PaymentMethod(
      id: 'new${stored.length}',
      businessId: m.businessId,
      type: m.type,
      upiId: m.upiId,
      isActive: m.isActive,
      isPreferred: m.isPreferred,
      createdAt: m.createdAt,
    ));
    return 'new${stored.length}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PaymentMethod saved(String id, String type, {bool preferred = false}) => PaymentMethod(
      id: id,
      businessId: 'BUS1',
      type: type,
      upiId: type == 'upi' ? '$id@bank' : null,
      isActive: true,
      isPreferred: preferred,
      createdAt: DateTime(2026, 1, 1),
    );

PaymentMethod draft(String type) => PaymentMethod(
      id: '',
      businessId: 'BUS1',
      type: type,
      upiId: type == 'upi' ? 'new@bank' : null,
      isActive: true,
      isPreferred: false,
      createdAt: DateTime(2026, 2, 1),
    );

void main() {
  // The form screen adds through a view model that never loaded the list, so
  // adding has to look at what is really saved, not at what was cached.
  group('adding to a view model that has not loaded the list', () {
    test('is not made preferred when something already is', () async {
      final service = MemoryService([saved('a', 'upi', preferred: true)]);
      final vm = PaymentMethodsViewModel(service: service);

      expect(await vm.addPaymentMethod('BUS1', draft('upi')), isTrue);

      expect(service.stored.where((m) => m.isPreferred), hasLength(1));
      expect(service.stored.last.isPreferred, isFalse);
    });

    test('the first method ever is preferred', () async {
      final service = MemoryService([]);
      final vm = PaymentMethodsViewModel(service: service);

      await vm.addPaymentMethod('BUS1', draft('upi'));

      expect(service.stored.single.isPreferred, isTrue);
    });

    test('refuses a second Razorpay', () async {
      final service = MemoryService([saved('rz', 'razorpay', preferred: true)]);
      final vm = PaymentMethodsViewModel(service: service);

      expect(await vm.addPaymentMethod('BUS1', draft('razorpay')), isFalse);

      expect(vm.error, contains('already configured'));
      expect(service.stored, hasLength(1));
    });

    test('does not guess when the saved list cannot be read', () async {
      final service = MemoryService([saved('a', 'upi', preferred: true)])..failReads = true;
      final vm = PaymentMethodsViewModel(service: service);

      expect(await vm.addPaymentMethod('BUS1', draft('upi')), isFalse);

      expect(service.stored, hasLength(1), reason: 'nothing was written');
      expect(vm.error, isNotEmpty);
    });
  });
}
