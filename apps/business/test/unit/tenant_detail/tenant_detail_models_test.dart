import 'package:business/presentation/tenant_detail/tenant_detail_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/tenant_fakes.dart';

void main() {
  group('TenantProfile.fromMap', () {
    TenantProfile parse(Map<String, dynamic> m) =>
        TenantProfile.fromMap(m, propertyName: 'Sunrise Boys PG', businessId: 'BUS1');

    test('reads the fields the property screen provides', () {
      final p = parse(tenantMap());

      expect(p.id, 'TEN0000001');
      expect(p.name, 'Rohan Mehta');
      expect(p.phone, '+919000000101');
      expect(p.email, 'rohan@example.test');
      expect(p.room, '101');
      expect(p.bed, '1');
      expect(p.rent, 9500);
      expect(p.joinDate, DateTime(2026, 3, 30));
      expect(p.statusLabel, 'Active');
      expect(p.propertyName, 'Sunrise Boys PG');
      expect(p.location, 'Room 101 · Bed 1');
    });

    test('treats placeholder text as missing', () {
      final p = parse(tenantMap(
        phone: 'Not provided',
        email: 'Not provided',
        rent: 'N/A',
        joinDate: 'Not recorded',
      ));

      expect(p.phone, isNull);
      expect(p.email, isNull);
      expect(p.rent, isNull);
      expect(p.joinDate, isNull);
    });

    test('accepts Firestore timestamps, ISO strings and numeric strings', () {
      expect(
        parse(tenantMap(joinDate: Timestamp.fromDate(DateTime(2026, 1, 5)))).joinDate,
        DateTime(2026, 1, 5),
      );
      expect(parse(tenantMap(joinDate: '2026-02-03')).joinDate, DateTime(2026, 2, 3));
      expect(parse(tenantMap(rent: '7500.5')).rent, 7500.5);
    });

    test('falls back to the other keys older callers use', () {
      final p = parse({
        'tenantId': 'TEN9',
        'name': 'Asha',
        'roomNumber': '12',
        'bedNumber': '2',
        'monthlyRent': 6000,
      });

      expect(p.id, 'TEN9');
      expect(p.room, '12');
      expect(p.bed, '2');
      expect(p.rent, 6000);
    });

    test('shortens opaque ids but keeps TEN ids whole', () {
      expect(parse(tenantMap(id: 'BUS1_ABCDEFGHIJKLMNOPQRSTUV')).displayId, 'ABCDEFGH…');
      expect(parse(tenantMap(id: 'BUS1_TEN0000042')).displayId, 'TEN0000042');
      expect(parse(tenantMap(id: 'TEN0000001')).displayId, 'TEN0000001');
    });

    test('names the tenant when the record has no name', () {
      final p = parse({'tenantId': 'T1', 'name': '  '});

      expect(p.displayName, 'Unnamed tenant');
      expect(p.initials, '?');
    });

    test('knows when the tenant is no longer active', () {
      expect(parse(tenantMap(status: 'inactive')).isActive, isFalse);
      expect(parse(tenantMap(status: 'Active')).isActive, isTrue);
    });
  });

  group('TenantPayment', () {
    test('reads a payment document', () {
      final p = TenantPayment.fromMap('pay1', {
        'month': 'October 2026',
        'amount': 9500,
        'method': 'UPI',
        'status': 'Paid',
        'date': Timestamp.fromDate(DateTime(2026, 10, 3)),
      });

      expect(p.month, 'October 2026');
      expect(p.amount, 9500);
      expect(p.method, 'UPI');
      expect(p.date, DateTime(2026, 10, 3));
      expect(p.view.label, 'Paid');
      expect(p.view.tone, PaymentTone.success);
    });

    test('maps every status the backend writes', () {
      PaymentView of(String s) => TenantPayment.fromMap('x', {'status': s}).view;

      expect(of('paid').label, 'Paid');
      expect(of('pending_verification').label, 'Awaiting check');
      expect(of('pending_verification').tone, PaymentTone.warning);
      expect(of('rejected').tone, PaymentTone.danger);
      expect(of('mystery').label, 'Mystery');
      expect(TenantPayment.fromMap('x', {}).view.label, 'Unknown');
    });

    test('keeps the rejection reason for the owner to see', () {
      final p = TenantPayment.fromMap('x', {'status': 'rejected', 'rejectionReason': 'Wrong amount'});

      expect(p.rejectionReason, 'Wrong amount');
    });

    test('copes with missing amount and month', () {
      final p = TenantPayment.fromMap('x', {});

      expect(p.amount, 0);
      expect(p.month, 'Payment');
    });
  });
}
