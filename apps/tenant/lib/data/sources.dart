// lib/data/sources.dart
//
// What the tenant screens ask of the backend. Firestore and Cloud Functions
// implementations live in firestore_sources.dart; tests use fakes.
import 'package:models/business/property/property_model.dart';

import 'models.dart';

/// A backend problem with a message fit to show as it is.
class TenantFailure implements Exception {
  const TenantFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The signed-in tenant: their account, current stay and unread count.
abstract class SessionSource {
  Stream<TenantAccount?> watchAccount(String uid);

  /// The active stay under `tenants/{tenantId}/stays`, or null.
  Stream<Stay?> watchActiveStay(String tenantId);

  Stream<int> watchUnreadCount(String tenantId);
}

/// Everything about where the tenant lives and what they owe.
abstract class StaySource {
  Stream<PropertyContact?> watchProperty(String businessId, String propertyId);

  Future<RoomInfo?> loadRoom(String businessId, String propertyId, String roomId);

  /// All rent invoices, newest period first.
  Stream<List<RentInvoice>> watchInvoices(String businessId, String tenantId);

  /// All payments, newest first.
  Stream<List<RentPayment>> watchPayments(String businessId, String tenantId);
}

class EnrollmentDraft {
  const EnrollmentDraft({
    required this.propertyId,
    required this.businessId,
    required this.propertyName,
    required this.name,
    required this.phone,
    required this.moveIn,
    this.sharing,
    this.notes,
  });

  final String propertyId;
  final String businessId;
  final String propertyName;
  final String name;
  final String phone;
  final DateTime moveIn;
  final String? sharing;
  final String? notes;
}

abstract class EnrollmentSource {
  /// The caller's requests, newest first.
  Stream<List<EnrollmentRequest>> watchMyRequests(String uid);

  Stream<EnrollmentRequest?> watchRequest(String requestId);

  /// Sends a request to join a PG. Returns its id.
  Future<String> submitEnrollment(EnrollmentDraft draft);

  /// Tells the owner the first bill was paid.
  Future<void> submitBillPayment(String requestId, {required String uid, required String reference});

  /// Takes back a request the owner has not answered yet.
  Future<void> withdraw(String requestId);
}

class RentSubmission {
  const RentSubmission({
    required this.businessId,
    required this.amount,
    required this.month,
    required this.mode,
    this.reference,
    this.invoiceId,
  });

  final String businessId;
  final double amount;
  final String month;

  /// 'UPI' | 'Cash', as submitRentPayment expects.
  final String mode;
  final String? reference;
  final String? invoiceId;
}

abstract class RentSource {
  Future<PaymentSettings> loadSettings(String businessId);

  /// A Razorpay link for [invoiceId] (createPaymentLink).
  Future<String> createPaymentLink({
    required String businessId,
    required String tenantId,
    required String invoiceId,
  });

  /// Reports a UPI or cash payment for the owner to confirm.
  Future<void> submitRentPayment(RentSubmission submission);
}

abstract class NotificationSource {
  Stream<List<TenantNotification>> watchNotifications(String tenantId);

  Future<void> markRead(String tenantId, Iterable<String> ids);
}

abstract class InvitationSource {
  Future<List<PendingInvitation>> listInvitations();

  Future<PendingInvitation> loadInvitation(String invitationId);

  Future<void> acceptInvitation(String invitationId);

  Future<void> declineInvitation(String invitationId, {String? reason});
}

class PinDraft {
  const PinDraft({
    required this.propertyId,
    required this.authorId,
    required this.authorName,
    required this.authorPhone,
    required this.category,
    required this.content,
  });

  final String propertyId;
  final String authorId;
  final String authorName;
  final String authorPhone;
  final PinCategory category;
  final String content;
}

abstract class PinboardSource {
  /// Notes for [propertyId] that have not expired, soonest to expire first.
  Stream<List<PinNote>> watchPins(String propertyId);

  Future<void> addPin(PinDraft draft);

  Future<void> deletePin(String noteId);
}

class MaintenanceDraft {
  const MaintenanceDraft({
    required this.uid,
    required this.tenantId,
    required this.tenantName,
    required this.tenantPhone,
    required this.stay,
    required this.category,
    required this.title,
    required this.description,
    required this.urgent,
  });

  final String uid;
  final String? tenantId;
  final String tenantName;
  final String tenantPhone;
  final Stay stay;
  final MaintenanceCategory category;
  final String title;
  final String description;
  final bool urgent;
}

abstract class MaintenanceSource {
  /// The caller's requests, newest first.
  Stream<List<MaintenanceRequest>> watchMyMaintenance(String uid);

  Future<void> raiseMaintenance(MaintenanceDraft draft);

  Future<void> cancelMaintenance(String requestId);
}

class PropertyPage {
  const PropertyPage(this.properties, {this.cursor, this.hasMore = false});

  final List<Property> properties;

  /// Pass back to load the next page.
  final Object? cursor;
  final bool hasMore;
}

abstract class ExploreSource {
  Future<PropertyPage> loadCity(String city, {Object? cursor, int pageSize = 10});

  Future<Property?> loadProperty(String propertyId, {String? businessId});

  Future<void> setFavorite(String uid, String propertyId, bool favorite);
}

/// Everything at once: what the app provides to its screens.
abstract class TenantBackend
    implements
        SessionSource,
        StaySource,
        EnrollmentSource,
        RentSource,
        NotificationSource,
        InvitationSource,
        PinboardSource,
        MaintenanceSource,
        ExploreSource {}
