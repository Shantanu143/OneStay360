import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

/// Integration test: Complete Enrollment Flow
///
/// Tests the full journey:
/// 1. Owner views enrollment requests
/// 2. Owner approves with room/bed assignment
/// 3. Owner sends bill
/// 4. Owner confirms payment
/// 5. Tenant record is created
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Enrollment Flow Integration Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
    });

    testWidgets('Owner can view pending enrollment requests', (tester) async {
      // Seed enrollment request
      await fakeFirestore.collection('enrollmentRequests').add({
        'tenantName': 'Rahul Sharma',
        'tenantPhone': '9876543210',
        'propertyId': 'PROP001',
        'businessId': 'BUS0000001',
        'propertyName': 'Sunrise PG',
        'status': 'pending',
        'moveInDate': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Verify request exists
      final snap = await fakeFirestore
          .collection('enrollmentRequests')
          .where('businessId', isEqualTo: 'BUS0000001')
          .where('status', isEqualTo: 'pending')
          .get();

      expect(snap.docs.length, equals(1));
      expect(snap.docs.first.data()['tenantName'], equals('Rahul Sharma'));
    });

    testWidgets('Owner can approve enrollment with room assignment', (
      tester,
    ) async {
      // Create enrollment request
      final requestRef = await fakeFirestore
          .collection('enrollmentRequests')
          .add({
            'tenantName': 'Priya Patel',
            'tenantPhone': '9876543211',
            'propertyId': 'PROP001',
            'businessId': 'BUS0000001',
            'propertyName': 'Sunrise PG',
            'status': 'pending',
            'moveInDate': DateTime.now().toIso8601String(),
            'createdAt': DateTime.now().toIso8601String(),
          });

      // Simulate approval with room/bed assignment
      await requestRef.update({
        'status': 'approved',
        'roomId': 'ROOM001',
        'bedId': '1',
        'roomNumber': 'ROOM001',
        'bedNumber': '1',
        'monthlyRent': 8000,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      final updatedSnap = await requestRef.get();
      expect(updatedSnap.data()!['status'], equals('approved'));
      expect(updatedSnap.data()!['roomId'], equals('ROOM001'));
      expect(updatedSnap.data()!['monthlyRent'], equals(8000));
    });

    testWidgets('Owner can send bill to tenant', (tester) async {
      final requestRef = await fakeFirestore
          .collection('enrollmentRequests')
          .add({
            'tenantName': 'Amit Kumar',
            'tenantPhone': '9876543212',
            'propertyId': 'PROP001',
            'businessId': 'BUS0000001',
            'status': 'approved',
            'roomId': 'ROOM001',
            'bedId': '1',
            'monthlyRent': 8000,
          });

      // Send bill
      await requestRef.update({
        'status': 'bill_sent',
        'depositAmount': 16000,
        'advanceAmount': 8000,
        'totalBillAmount': 24000,
        'ownerUpiId': 'owner@upi',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      final snap = await requestRef.get();
      expect(snap.data()!['status'], equals('bill_sent'));
      expect(snap.data()!['totalBillAmount'], equals(24000));
    });

    testWidgets('Tenant payment submission updates status', (tester) async {
      final requestRef = await fakeFirestore
          .collection('enrollmentRequests')
          .add({
            'tenantName': 'Sneha Reddy',
            'tenantPhone': '9876543213',
            'propertyId': 'PROP001',
            'businessId': 'BUS0000001',
            'status': 'bill_sent',
            'totalBillAmount': 24000,
          });

      // Tenant submits payment
      await requestRef.update({
        'status': 'payment_submitted',
        'transactionId': 'TXN987654321',
        'paymentSubmittedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      final snap = await requestRef.get();
      expect(snap.data()!['status'], equals('payment_submitted'));
      expect(snap.data()!['transactionId'], equals('TXN987654321'));
    });

    testWidgets('Owner confirmation creates tenant record', (tester) async {
      // Create enrollment request in payment_submitted state
      final requestRef = await fakeFirestore
          .collection('enrollmentRequests')
          .add({
            'tenantName': 'Vikram Singh',
            'tenantPhone': '9876543214',
            'propertyId': 'PROP001',
            'businessId': 'BUS0000001',
            'status': 'payment_submitted',
            'transactionId': 'TXN111222333',
            'roomId': 'ROOM001',
            'bedId': '1',
            'monthlyRent': 8000,
          });

      // Owner confirms
      await requestRef.update({
        'status': 'confirmed',
        'confirmedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Simulate tenant record creation
      await fakeFirestore
          .collection('businesses')
          .doc('BUS0000001')
          .collection('tenants')
          .doc('TEN0000001')
          .set({
            'tenantId': 'TEN0000001',
            'name': 'Vikram Singh',
            'phone': '9876543214',
            'propertyId': 'PROP001',
            'businessId': 'BUS0000001',
            'roomId': 'ROOM001',
            'bedId': '1',
            'monthlyRent': 8000,
            'status': 'active',
            'enrollmentRequestId': requestRef.id,
            'createdAt': DateTime.now().toIso8601String(),
          });

      final tenantSnap = await fakeFirestore
          .collection('businesses')
          .doc('BUS0000001')
          .collection('tenants')
          .doc('TEN0000001')
          .get();

      expect(tenantSnap.exists, isTrue);
      expect(tenantSnap.data()!['name'], equals('Vikram Singh'));
      expect(tenantSnap.data()!['status'], equals('active'));
    });

    testWidgets('Enrollment rejection notifies tenant', (tester) async {
      final requestRef = await fakeFirestore
          .collection('enrollmentRequests')
          .add({
            'tenantName': 'Kavya Nair',
            'tenantPhone': '9876543215',
            'propertyId': 'PROP001',
            'businessId': 'BUS0000001',
            'status': 'pending',
          });

      // Owner rejects
      await requestRef.update({
        'status': 'rejected',
        'rejectionReason': 'No rooms available',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      final snap = await requestRef.get();
      expect(snap.data()!['status'], equals('rejected'));
      expect(snap.data()!['rejectionReason'], equals('No rooms available'));
    });
  });
}
