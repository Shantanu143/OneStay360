import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/tenant/tenant_request_model.dart';

void main() {
  group('TenantRequest.fromFirestore', () {
    test('reads what submitEnrollmentRequest writes', () {
      final r = TenantRequest.fromFirestore('R1', {
        'tenantName': 'Mohit Saxena',
        'tenantPhone': '+919000000501',
        'tenantEmail': 'mohit@example.test',
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime(2026, 10, 26, 9)),
        'moveInDate': Timestamp.fromDate(DateTime(2026, 11, 2)),
        'notes': 'Joining Flipkart, need a quiet room.',
        'sharingType': '2',
        'propertyId': 'P1',
        'businessId': 'B1',
      });

      expect(r.phone, '+919000000501');
      expect(r.email, 'mohit@example.test');
      expect(r.preferredMoveIn, DateTime(2026, 11, 2));
      expect(r.message, 'Joining Flipkart, need a quiet room.');
      expect(r.sharingType, '2');
    });

    test('still reads the older field names', () {
      final r = TenantRequest.fromFirestore('R2', {
        'tenantName': 'Old',
        'phone': '9000000000',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'preferredMoveIn': Timestamp.fromDate(DateTime(2026, 2, 1)),
        'message': 'Hello',
      });

      expect(r.phone, '9000000000');
      expect(r.preferredMoveIn, DateTime(2026, 2, 1));
      expect(r.message, 'Hello');
    });

    test('accepts ISO date strings and treats blank notes as none', () {
      final r = TenantRequest.fromFirestore('R3', {
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'moveInDate': '2026-03-04',
        'notes': '  ',
      });

      expect(r.preferredMoveIn, DateTime(2026, 3, 4));
      expect(r.message, isNull);
    });

    test('survives a server timestamp that has not arrived yet', () {
      final before = DateTime.now();
      final r = TenantRequest.fromFirestore('R4', {'createdAt': null});

      expect(r.createdAt.isBefore(before), isFalse);
    });
  });
}
