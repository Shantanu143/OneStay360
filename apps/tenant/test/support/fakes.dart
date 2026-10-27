import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import 'package:models/business/property/property_model.dart';
import 'package:tenant/data/models.dart';
import 'package:tenant/data/sources.dart';

/// A value that streams: new listeners get the current value first.
class Live<T> {
  final _controller = StreamController<T>.broadcast();
  late T _value;
  bool _has = false;
  int listens = 0;

  T get value => _value;
  bool get hasValue => _has;

  void set(T v) {
    _value = v;
    _has = true;
    _controller.add(v);
  }

  void fail(Object error) => _controller.addError(error);

  Stream<T> get stream {
    listens++;
    late StreamController<T> out;
    StreamSubscription<T>? sub;
    out = StreamController<T>(
      onListen: () {
        if (_has) out.add(_value);
        sub = _controller.stream.listen(out.add, onError: out.addError);
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }
}

/// Every tenant source in memory. Records what was asked of it; set [failure]
/// to make the next writes throw it.
class FakeBackend implements TenantBackend {
  final calls = <String>[];
  Object? failure;

  // Session
  final account = Live<TenantAccount?>();
  final stay = Live<Stay?>();
  final unread = Live<int>();
  final watchedStaysFor = <String>[];

  // Stay
  final property = Live<PropertyContact?>();
  RoomInfo? room;
  final invoices = Live<List<RentInvoice>>();
  final payments = Live<List<RentPayment>>();

  // Enrollment
  final requests = Live<List<EnrollmentRequest>>();
  final request = Live<EnrollmentRequest?>();
  EnrollmentDraft? lastEnrollment;
  String? lastBillReference;

  // Rent
  PaymentSettings settings = const PaymentSettings();
  String linkUrl = 'https://rzp.io/test';
  RentSubmission? lastRent;

  // Notifications
  final notifications = Live<List<TenantNotification>>();
  final markedRead = <String>[];

  // Invitations
  List<PendingInvitation> invitations = [];
  PendingInvitation? invitation;
  Object? listFailure;

  // Pinboard
  final pins = Live<List<PinNote>>();
  PinDraft? lastPin;

  // Maintenance
  final maintenance = Live<List<MaintenanceRequest>>();
  MaintenanceDraft? lastMaintenance;

  // Explore
  final pages = <String, List<PropertyPage>>{};
  final properties = <String, Property>{};
  final favorites = <String>{};

  Completer<void>? gate;

  Future<void> _write(String call) async {
    calls.add(call);
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
  }

  @override
  Stream<TenantAccount?> watchAccount(String uid) => account.stream;

  @override
  Stream<Stay?> watchActiveStay(String tenantId) {
    watchedStaysFor.add(tenantId);
    return stay.stream;
  }

  @override
  Stream<int> watchUnreadCount(String tenantId) => unread.stream;

  @override
  Stream<PropertyContact?> watchProperty(String businessId, String propertyId) => property.stream;

  @override
  Future<RoomInfo?> loadRoom(String businessId, String propertyId, String roomId) async => room;

  @override
  Stream<List<RentInvoice>> watchInvoices(String businessId, String tenantId) => invoices.stream;

  @override
  Stream<List<RentPayment>> watchPayments(String businessId, String tenantId) => payments.stream;

  @override
  Stream<List<EnrollmentRequest>> watchMyRequests(String uid) => requests.stream;

  @override
  Stream<EnrollmentRequest?> watchRequest(String requestId) => request.stream;

  @override
  Future<String> submitEnrollment(EnrollmentDraft draft) async {
    await _write('submitEnrollment');
    lastEnrollment = draft;
    return 'E-new';
  }

  @override
  Future<void> submitBillPayment(String requestId, {required String uid, required String reference}) async {
    await _write('submitBillPayment:$requestId');
    lastBillReference = reference;
  }

  @override
  Future<void> withdraw(String requestId) => _write('withdraw:$requestId');

  @override
  Future<PaymentSettings> loadSettings(String businessId) async {
    calls.add('loadSettings:$businessId');
    return settings;
  }

  @override
  Future<String> createPaymentLink({
    required String businessId,
    required String tenantId,
    required String invoiceId,
  }) async {
    await _write('createPaymentLink:$invoiceId');
    return linkUrl;
  }

  @override
  Future<void> submitRentPayment(RentSubmission submission) async {
    await _write('submitRentPayment');
    lastRent = submission;
  }

  @override
  Stream<List<TenantNotification>> watchNotifications(String tenantId) => notifications.stream;

  @override
  Future<void> markRead(String tenantId, Iterable<String> ids) async {
    await _write('markRead');
    markedRead.addAll(ids);
  }

  @override
  Future<List<PendingInvitation>> listInvitations() async {
    calls.add('listInvitations');
    if (listFailure != null) throw listFailure!;
    return invitations;
  }

  @override
  Future<PendingInvitation> loadInvitation(String invitationId) async {
    calls.add('loadInvitation:$invitationId');
    if (failure != null) throw failure!;
    return invitation!;
  }

  @override
  Future<void> acceptInvitation(String invitationId) => _write('accept:$invitationId');

  @override
  Future<void> declineInvitation(String invitationId, {String? reason}) =>
      _write('decline:$invitationId:${reason ?? ''}');

  @override
  Stream<List<PinNote>> watchPins(String propertyId) => pins.stream;

  @override
  Future<void> addPin(PinDraft draft) async {
    await _write('addPin');
    lastPin = draft;
  }

  @override
  Future<void> deletePin(String noteId) => _write('deletePin:$noteId');

  @override
  Stream<List<MaintenanceRequest>> watchMyMaintenance(String uid) => maintenance.stream;

  @override
  Future<void> raiseMaintenance(MaintenanceDraft draft) async {
    await _write('raiseMaintenance');
    lastMaintenance = draft;
  }

  @override
  Future<void> cancelMaintenance(String requestId) => _write('cancelMaintenance:$requestId');

  @override
  Future<PropertyPage> loadCity(String city, {Object? cursor, int pageSize = 10}) async {
    calls.add('loadCity:$city:${cursor ?? ''}');
    if (failure != null) throw failure!;
    final list = pages[city] ?? const [];
    final index = cursor is int ? cursor : 0;
    if (index >= list.length) return const PropertyPage([]);
    final page = list[index];
    return PropertyPage(page.properties, cursor: index + 1, hasMore: index + 1 < list.length);
  }

  @override
  Future<Property?> loadProperty(String propertyId, {String? businessId}) async {
    calls.add('loadProperty:$propertyId');
    if (failure != null) throw failure!;
    return properties[propertyId];
  }

  @override
  Future<void> setFavorite(String uid, String propertyId, bool favorite) async {
    await _write('setFavorite:$propertyId:$favorite');
    favorite ? favorites.add(propertyId) : favorites.remove(propertyId);
  }
}

const testStay = Stay(
  id: 'S1',
  businessId: 'B1',
  propertyId: 'P1',
  propertyName: 'Green Nest',
  roomId: 'R101',
  roomNumber: '101',
  bedId: '2',
  bedNumber: '2',
  monthlyRent: 9000,
);

TenantAccount testAccount({String? tenantId = 'TEN1', bool complete = true, Set<String> favorites = const {}}) =>
    TenantAccount(
      uid: 'u1',
      tenantId: tenantId,
      name: 'Asha Rao',
      email: 'asha@example.test',
      phone: '+919811100001',
      profileComplete: complete,
      favorites: favorites,
    );

Property testProperty({
  String id = 'BUS0000001PNR001',
  String name = 'Green Nest',
  int single = 12000,
  int double = 9000,
  String gender = 'female',
  bool featured = false,
  double rating = 4.5,
  int availableBeds = 3,
  DateTime? updatedAt,
}) {
  return Property.fromMap({
    'name': name,
    'address': '12 MG Road',
    'city': 'Pune',
    'cityCode': 'PNR',
    'description': 'Calm and clean.',
    'landmarks': 'Near metro',
    'businessId': 'BUS0000001',
    'businessName': 'Nest Stays',
    'businessPhone': '9811100001',
    'status': 'active',
    'featured': featured,
    'pricing': {'single': single, 'double': double, 'triple': 0, 'securityDeposit': 10000},
    'rules': {'genderAllowed': gender, 'noticePeriodDays': 30},
    'amenities': {'wifi': true, 'ac': true},
    'totals': {'rooms': 5, 'beds': 10, 'availableBeds': availableBeds},
    'rating': {'average': rating, 'count': 12},
    'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime(2026, 1, 1)),
    'createdAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
  }, id);
}
