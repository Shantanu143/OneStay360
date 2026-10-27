import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/business/business_notification_model.dart';

void main() {
  group('BusinessNotification.fromMap', () {
    test('reads the standard fields', () {
      final n = BusinessNotification.fromMap('n1', {
        'businessId': 'B1',
        'title': 'Rent received',
        'message': '₹9,500 received',
        'type': 'rent_received',
        'read': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 26)),
        'requestId': 'R1',
        'propertyId': 'P1',
      });

      expect(n.businessId, 'B1');
      expect(n.message, '₹9,500 received');
      expect(n.requestId, 'R1');
      expect(n.read, isTrue);
    });

    test('understands the payment-submitted notification, which uses other names', () {
      final n = BusinessNotification.fromMap('n2', {
        'type': 'payment_submitted',
        'title': 'Payment Confirmation Required',
        'body': 'Mohit paid ₹19,500. Transaction ID: UTR1',
        'enrollmentRequestId': 'req_1',
        'propertyId': 'P1',
        'read': false,
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 26)),
      });

      expect(n.message, 'Mohit paid ₹19,500. Transaction ID: UTR1');
      expect(n.requestId, 'req_1');
      expect(n.type, BusinessNotificationType.payment);
    });

    test('falls back to the request named in routing', () {
      final n = BusinessNotification.fromMap('n3', {
        'type': 'payment_submitted',
        'routing': {'target': 'pending_payments', 'requestId': 'req_9', 'propertyId': 'P2'},
      });

      expect(n.requestId, 'req_9');
    });

    test('prefers message over body', () {
      final n = BusinessNotification.fromMap('n4', {'message': 'new', 'body': 'old'});

      expect(n.message, 'new');
    });
  });

  test('fromDocument takes the business from where the notification is stored', () async {
    final fs = FakeFirebaseFirestore();
    await fs.collection('businesses').doc('BUS7').collection('notifications').doc('n1').set({
      'type': 'payment_submitted',
      'title': 'Payment',
      'body': 'Someone paid',
      'createdAt': Timestamp.fromDate(DateTime(2026, 10, 26)),
    });

    final doc = await fs.collection('businesses').doc('BUS7').collection('notifications').doc('n1').get();
    final n = BusinessNotification.fromDocument(doc);

    expect(n.businessId, 'BUS7');
    expect(n.message, 'Someone paid');
  });
}
