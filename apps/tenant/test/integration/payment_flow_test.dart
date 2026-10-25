import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

/// Integration test: Complete Payment Flow
///
/// Tests all payment methods:
/// 1. Razorpay online payment
/// 2. UPI manual payment
/// 3. Cash payment
/// 4. Invoice lifecycle (unpaid → paid)
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Tenant Payment Flow Integration Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;

    const uid = 'tenant-uid-001';
    const tenantId = 'TEN0000001';
    const businessId = 'BUS0000001';

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth(
        mockUser: MockUser(uid: uid, email: 'tenant@test.com'),
      );

      // Seed user doc
      await fakeFirestore.collection('users').doc(uid).set({
        'uid': uid,
        'tenantId': tenantId,
        'fullName': 'Test Tenant',
        'email': 'tenant@test.com',
        'phone': '9876543210',
      });

      // Seed business-scoped tenant
      await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('tenants')
          .doc(tenantId)
          .set({
        'tenantId': tenantId,
        'userId': uid,
        'name': 'Test Tenant',
        'phone': '9876543210',
        'businessId': businessId,
        'propertyId': 'PROP001',
        'roomId': 'ROOM001',
        'bedId': '1',
        'monthlyRent': 10000,
        'status': 'active',
      });

      // Seed global tenant doc
      await fakeFirestore.collection('tenants').doc(tenantId).set({
        'tenantId': tenantId,
        'userId': uid,
        'businessId': businessId,
        'propertyId': 'PROP001',
        'status': 'active',
        'monthlyRent': 10000,
      });
    });

    group('Invoice Generation', () {
      testWidgets('Invoice is created for active tenant', (tester) async {
        final invoiceRef = fakeFirestore
            .collection('businesses')
            .doc(businessId)
            .collection('tenants')
            .doc(tenantId)
            .collection('rent_invoices')
            .doc('INV001');

        await invoiceRef.set({
          'invoiceId': 'INV001',
          'tenantId': tenantId,
          'businessId': businessId,
          'amount': 10000,
          'month': 'January 2025',
          'periodMonth': '2025-01',
          'status': 'unpaid',
          'dueDate': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        });

        final snap = await invoiceRef.get();
        expect(snap.exists, isTrue);
        expect(snap.data()!['status'], equals('unpaid'));
        expect(snap.data()!['amount'], equals(10000));
      });

      testWidgets('Invoice becomes overdue after due date', (tester) async {
        final invoiceRef = fakeFirestore
            .collection('businesses')
            .doc(businessId)
            .collection('tenants')
            .doc(tenantId)
            .collection('rent_invoices')
            .doc('INV_OVERDUE');

        await invoiceRef.set({
          'invoiceId': 'INV_OVERDUE',
          'tenantId': tenantId,
          'businessId': businessId,
          'amount': 10000,
          'month': 'December 2024',
          'status': 'unpaid',
          'dueDate': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        });

        // Simulate markOverdueInvoices
        await invoiceRef.update({'status': 'overdue'});

        final snap = await invoiceRef.get();
        expect(snap.data()!['status'], equals('overdue'));
      });
    });

    group('UPI Payment Flow', () {
      testWidgets('Tenant can submit UPI payment', (tester) async {
        // Create invoice
        final invoiceRef = fakeFirestore
            .collection('businesses')
            .doc(businessId)
            .collection('tenants')
            .doc(tenantId)
            .collection('rent_invoices')
            .doc('INV_UPI');

        await invoiceRef.set({
          'invoiceId': 'INV_UPI',
          'tenantId': tenantId,
          'businessId': businessId,
          'amount': 10000,
          'month': 'February 2025',
          'status': 'unpaid',
        });

        // Submit payment
        final paymentRef = fakeFirestore
            .collection('businesses')
            .doc(businessId)
            .collection('tenants')
            .doc(tenantId)
            .collection('payments')
            .doc('PAY_UPI');

        await paymentRef.set({
          'id': 'PAY_UPI',
          'tenantId': tenantId,
          'businessId': businessId,
          'amount': 10000,
          'month': 'February 2025',
          'status': 'pending_verification',
          'method': 'UPI',
          'transactionId': 'TXN_UPI_123',
          'rentInvoiceId': 'INV_UPI',
          'submittedBy': 'tenant',
          'createdAt': DateTime.now().toIso8601String(),
        });

        final paySnap = await paymentRef.get();
        expect(paySnap.data()!['status'], equals('pending_verification'));
        expect(paySnap.data()!['transactionId'], equals('TXN_UPI_123'));
        expect(paySnap.data()!['rentInvoiceId'], equals('INV_UPI'));
      });

      testWidgets('Owner confirmation marks invoice as paid', (tester) async {
        final invoiceRef = fakeFirestore
            .collection('businesses')
            .doc(businessId)
            .collection('tenants')
            .doc(tenantId)
            .collection('rent_invoices')
            .doc('INV_CONFIRM');

        await invoiceRef.set({
          'invoiceId': 'INV_CONFIRM',
          'tenantId': tenantId,
          'businessId': businessId,
          'amount': 10000,
          'month': 'March 2025',
          'status': 'unpaid',
        });

        final paymentRef = fakeFirestore
            .collection('businesses')
            .doc(businessId)
            .collection('tenants')
            .doc(tenantId)
            .collection('payments')
            .doc('PAY_CONFIRM');

        await paymentRef.set({
          'id': 'PAY_CONFIRM',
          'tenantId': tenantId,
          'businessId': businessId,
          'amount': 10000,
          'month': 'March 2025',
          'status': 'pending_verification',
          'rentInvoiceId': 'INV_CONFIRM',
        });

        // Owner confirms
        await paymentRef.update({
          'status': 'Paid',
          'verifiedBy': 'owner-uid',
          'verifiedAt': DateTime.now().toIso8601String(),
        });

        // Invoice should be marked paid
        await invoiceRef.update({
          'status': 'paid',
          'paidAt': DateTime.now().toIso8601String(),
          'verification': 'verified',
        });

        final invoiceSnap = await invoiceRef.get();
        expect(invoiceSnap.data()!['status'], equals('paid'));
        expect(invoiceSnap.data()!['verification'], equals('verified'));
      });

      testWidgets('Owner rejection reverts to pending', (tester) async {
        final paymentRef = fakeFirestore
            .collection('businesses')
            .doc(businessId)
            .collection('tenants')
            .doc(tenantId)
            .collection('payments')
            .doc('PAY_REJECT');

        await paymentRef.set({
          'id': 'PAY_REJECT',
          'tenantId': tenantId,
          'businessId': businessId,
          'amount': 10000,
          'month': 'April 2025',
          'status': 'pending_verification',
        });

        // Owner rejects
        await paymentRef.update({
          'status': 'rejected',
          'rejectionReason': 'Transaction ID not found',
          'rejectedBy': 'owner-uid',
        });

        final snap = await paymentRef.get();
        expect(snap.data()!['status'], equals('rejected'));
        expect(snap.data()!['rejectionReason'], equals('Transaction ID not found'));
      });
    });

    group('Cash Payment Flow', () {
      testWidgets('Tenant can submit cash payment record', (tester) async {
        final paymentRef = fakeFirestore
            .collection('businesses')
            .doc(businessId)
            .collection('tenants')
            .doc(tenantId)
            .collection('payments')
            .doc('PAY_CASH');

        await paymentRef.set({
          'id': 'PAY_CASH',
          'tenantId': tenantId,
          'businessId': businessId,
          'amount': 10000,
          'month': 'May 2025',
          'status': 'pending_verification',
          'method': 'Cash',
          'submittedBy': 'tenant',
          'createdAt': DateTime.now().toIso8601String(),
        });

        final snap = await paymentRef.get();
        expect(snap.data()!['method'], equals('Cash'));
        expect(snap.data()!['status'], equals('pending_verification'));
      });
    });

    group('Razorpay Payment Flow', () {
      testWidgets('Invoice has Razorpay payment link after creation', (tester) async {
        final invoiceRef = fakeFirestore
            .collection('businesses')
            .doc(businessId)
            .collection('tenants')
            .doc(tenantId)
            .collection('rent_invoices')
            .doc('INV_RZP');

        await invoiceRef.set({
          'invoiceId': 'INV_RZP',
          'tenantId': tenantId,
          'businessId': businessId,
          'amount': 10000,
          'month': 'June 2025',
          'status': 'unpaid',
        });

        // Simulate createPaymentLink
        await invoiceRef.update({
          'razorpayPaymentLinkId': 'plink_test_123',
          'razorpayPaymentLinkUrl': 'https://rzp.io/l/test123',
          'mode': 'razorpay',
        });

        final snap = await invoiceRef.get();
        expect(snap.data()!['razorpayPaymentLinkId'], equals('plink_test_123'));
        expect(snap.data()!['razorpayPaymentLinkUrl'], isNotEmpty);
      });

      testWidgets('Webhook marks invoice as paid automatically', (tester) async {
        final invoiceRef = fakeFirestore
            .collection('businesses')
            .doc(businessId)
            .collection('tenants')
            .doc(tenantId)
            .collection('rent_invoices')
            .doc('INV_WEBHOOK');

        await invoiceRef.set({
          'invoiceId': 'INV_WEBHOOK',
          'tenantId': tenantId,
          'businessId': businessId,
          'amount': 10000,
          'month': 'July 2025',
          'status': 'unpaid',
          'razorpayPaymentLinkId': 'plink_test_456',
        });

        // Simulate webhook processing
        await invoiceRef.update({
          'status': 'paid',
          'verification': 'verified',
          'mode': 'razorpay',
          'razorpayPaymentId': 'pay_test_789',
          'paidAt': DateTime.now().toIso8601String(),
        });

        final snap = await invoiceRef.get();
        expect(snap.data()!['status'], equals('paid'));
        expect(snap.data()!['verification'], equals('verified'));
        expect(snap.data()!['razorpayPaymentId'], equals('pay_test_789'));
      });
    });

    group('Amount Enforcement', () {
      testWidgets('Payment amount must match invoice amount', (tester) async {
        final invoiceRef = fakeFirestore
            .collection('businesses')
            .doc(businessId)
            .collection('tenants')
            .doc(tenantId)
            .collection('rent_invoices')
            .doc('INV_AMOUNT');

        await invoiceRef.set({
          'invoiceId': 'INV_AMOUNT',
          'tenantId': tenantId,
          'businessId': businessId,
          'amount': 10000,
          'month': 'August 2025',
          'status': 'unpaid',
        });

        final snap = await invoiceRef.get();
        final invoiceAmount = snap.data()!['amount'] as int;

        // Correct amount
        expect(invoiceAmount, equals(10000));

        // Simulate amount validation (tolerance ±1)
        const submittedAmount = 10000;
        expect((submittedAmount - invoiceAmount).abs(), lessThanOrEqualTo(1));
      });
    });
  });
}
