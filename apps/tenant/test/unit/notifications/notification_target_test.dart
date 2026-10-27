import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/data/models.dart';
import 'package:tenant/presentation/notifications/notification_target.dart';

void main() {
  group('pushTarget', () {
    test('a bill opens its request (both spellings the backend uses)', () {
      expect(pushTarget({'type': 'bill_received', 'requestId': 'E1'}), const RequestTarget('E1'));
      expect(pushTarget({'type': 'bill_sent', 'enrollmentRequestId': 'E2'}), const RequestTarget('E2'));
    });

    test('approval and rejection open the request', () {
      expect(pushTarget({'type': 'enrollment_approved', 'requestId': 'E1'}), const RequestTarget('E1'));
      expect(pushTarget({'type': 'enrollment_rejected', 'requestId': 'E1'}), const RequestTarget('E1'));
    });

    test('rent and payment news open My stay', () {
      for (final type in ['rent_due', 'rent_overdue', 'rent_payment_update', 'rent_payment_verified', 'tenant_linked']) {
        expect(pushTarget({'type': type}), const StayTarget(), reason: type);
      }
    });

    test('an invitation opens it', () {
      expect(pushTarget({'type': 'tenant_invitation', 'invitationId': 'I1'}), const InvitationTarget('I1'));
    });

    test('maintenance updates open the requests list', () {
      expect(pushTarget({'type': 'maintenance_update'}), const MaintenanceTarget());
    });

    test('nothing to open without the id it needs, or for unknown types', () {
      expect(pushTarget({'type': 'bill_received'}), const NoTarget());
      expect(pushTarget({'type': 'tenant_invitation'}), const NoTarget());
      expect(pushTarget({'type': 'something_new'}), const NoTarget());
      expect(pushTarget({}), const NoTarget());
    });
  });

  test('in-app notifications use the same routing', () {
    const n = TenantNotification(id: 'n', type: 'tenant_invitation', title: 't', invitationId: 'I9');
    expect(notificationTarget(n), const InvitationTarget('I9'));
    const bill = TenantNotification(id: 'n', type: 'bill_received', title: 't', enrollmentRequestId: 'E9');
    expect(notificationTarget(bill), const RequestTarget('E9'));
  });
}
