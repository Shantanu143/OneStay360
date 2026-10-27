import 'package:business/presentation/notifications/notification_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/business/business_notification_model.dart';

BusinessNotification note(
  BusinessNotificationType type, {
  String businessId = 'BUS1',
  String? propertyId,
  String? requestId,
}) =>
    BusinessNotification(
      id: 'n1',
      businessId: businessId,
      title: 'Title',
      message: 'Message',
      type: type,
      read: false,
      createdAt: DateTime(2026, 10, 26),
      propertyId: propertyId,
      requestId: requestId,
    );

void main() {
  group('enrollment requests', () {
    test("open the property's Requests tab", () {
      final t = targetFor(note(BusinessNotificationType.enrollmentRequest, propertyId: 'P1'));

      expect(t, isA<PropertyTarget>());
      expect((t as PropertyTarget).propertyId, 'P1');
      expect(t.tab, PropertyTarget.requestsTab);
    });

    test('look the property up from the request when only that is known', () {
      final t = targetFor(note(BusinessNotificationType.enrollmentRequest, requestId: 'R9'));

      expect(t, isA<RequestLookupTarget>());
      expect((t as RequestLookupTarget).requestId, 'R9');
    });

    test('fall back to the requests list when nothing identifies the request', () {
      final t = targetFor(note(BusinessNotificationType.enrollmentRequest));

      expect(t, isA<RequestsListTarget>());
    });

    test('empty ids count as missing', () {
      final t = targetFor(
        note(BusinessNotificationType.enrollmentRequest, propertyId: '', requestId: ''),
      );

      expect(t, isA<RequestsListTarget>());
    });
  });

  group('payments', () {
    test('open pending payments, scoped to the property when there is one', () {
      final t = targetFor(note(BusinessNotificationType.payment, propertyId: 'P1'));

      expect(t, isA<PendingPaymentsTarget>());
      expect((t as PendingPaymentsTarget).businessId, 'BUS1');
      expect(t.propertyId, 'P1');
    });

    test('say so when the business is unknown', () {
      final t = targetFor(note(BusinessNotificationType.payment, businessId: ''));

      expect(t, isA<MissingTarget>());
      expect((t as MissingTarget).reason, 'Business information missing');
    });
  });

  group('billing', () {
    test("open the property's Payments tab", () {
      final t = targetFor(note(BusinessNotificationType.billing, propertyId: 'P2'));

      expect((t as PropertyTarget).tab, PropertyTarget.billingTab);
    });

    test('say so when the property is unknown', () {
      final t = targetFor(note(BusinessNotificationType.billing));

      expect((t as MissingTarget).reason, 'Property information missing');
    });
  });

  test('tenant events and general notices open nothing', () {
    expect(targetFor(note(BusinessNotificationType.tenantEvent)), isA<NoTarget>());
    expect(targetFor(note(BusinessNotificationType.general)), isA<NoTarget>());
  });

  group('maintenance requests', () {
    test('open the maintenance list', () {
      expect(targetFor(note(BusinessNotificationType.maintenance)), isA<MaintenanceListTarget>());
    });

    test('are read from the type the trigger writes', () {
      final n = BusinessNotification.fromMap('n', {'type': 'maintenance_request', 'title': 't'});
      expect(n.type, BusinessNotificationType.maintenance);
    });

    test('tenant answers to invitations count as tenant events', () {
      for (final type in ['tenant_joined', 'tenant_invitation_declined']) {
        expect(BusinessNotification.fromMap('n', {'type': type}).type, BusinessNotificationType.tenantEvent, reason: type);
      }
    });
  });
}
