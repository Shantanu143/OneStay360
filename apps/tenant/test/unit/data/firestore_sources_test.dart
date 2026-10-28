import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/data/firestore_sources.dart';
import 'package:tenant/data/models.dart';
import 'package:tenant/data/sources.dart';

class CallLog {
  final calls = <(String, Map<String, dynamic>)>[];
  Object? error;
  Map<String, dynamic> reply = {};

  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data) async {
    calls.add((name, data));
    if (error != null) throw error!;
    return reply;
  }
}

void main() {
  late FakeFirebaseFirestore fs;
  late CallLog fn;
  late FirestoreTenantBackend backend;

  setUp(() {
    fs = FakeFirebaseFirestore();
    fn = CallLog();
    backend = FirestoreTenantBackend(firestore: fs, call: fn.call);
  });

  group('session', () {
    test('reads the account and only the active stay', () async {
      await fs.doc('users/u1').set({'tenantId': 'TEN1', 'fullName': 'Asha'});
      await fs.collection('tenants/TEN1/stays').add({'status': 'ended', 'propertyId': 'OLD', 'businessId': 'B'});
      await fs.collection('tenants/TEN1/stays').add({'status': 'active', 'propertyId': 'P1', 'businessId': 'B1'});

      final account = await backend.watchAccount('u1').first;
      final stay = await backend.watchActiveStay('TEN1').first;

      expect(account!.tenantId, 'TEN1');
      expect(stay!.propertyId, 'P1');
    });

    test('has no account or stay when nothing exists', () async {
      expect(await backend.watchAccount('nobody').first, isNull);
      expect(await backend.watchActiveStay('TEN9').first, isNull);
    });

    test('counts unread notifications', () async {
      await fs.collection('tenants/TEN1/notifications').add({'read': false});
      await fs.collection('tenants/TEN1/notifications').add({'read': true});
      await fs.collection('tenants/TEN1/notifications').add({'read': false});
      expect(await backend.watchUnreadCount('TEN1').first, 2);
    });
  });

  group('stay', () {
    test('reads the property contact and amenities', () async {
      await fs.doc('businesses/B1/properties/P1').set({
        'address': '12 MG Road',
        'city': 'Pune',
        'businessPhone': '9811100001',
        'businessName': 'Nest Stays',
        'amenities': {'wifi': true, 'ac': false, 'laundry': true},
      });
      final p = await backend.watchProperty('B1', 'P1').first;
      expect(p!.location, '12 MG Road, Pune');
      expect(p.phone, '9811100001');
      expect(p.amenities, unorderedEquals(['wifi', 'laundry']));
    });

    test('reads the room, by id or by number', () async {
      await fs.doc('businesses/B1/properties/P1/rooms/R1').set({'sharingType': 2, 'hasAC': true});
      await fs.collection('businesses/B1/properties/P1/rooms').add({'roomNumber': '201', 'sharingType': 3});

      expect((await backend.loadRoom('B1', 'P1', 'R1'))!.sharingLabel, 'Double sharing');
      expect((await backend.loadRoom('B1', 'P1', '201'))!.sharing, 3);
      expect(await backend.loadRoom('B1', 'P1', 'nope'), isNull);
    });

    test('lists invoices newest period first and payments newest first', () async {
      final inv = fs.collection('businesses/B1/tenants/TEN1/rent_invoices');
      await inv.add({'periodMonth': '2026-02', 'status': 'paid'});
      await inv.add({'periodMonth': '2026-03', 'status': 'unpaid'});
      final pay = fs.collection('businesses/B1/tenants/TEN1/payments');
      await pay.add({'amount': 1, 'date': Timestamp.fromDate(DateTime(2026, 1, 1))});
      await pay.add({'amount': 2, 'date': Timestamp.fromDate(DateTime(2026, 3, 1))});

      final invoices = await backend.watchInvoices('B1', 'TEN1').first;
      final payments = await backend.watchPayments('B1', 'TEN1').first;

      expect(invoices.map((i) => i.periodMonth), ['2026-03', '2026-02']);
      expect(payments.map((p) => p.amount), [2, 1]);
    });
  });

  group('enrollment', () {
    test("lists the caller's requests, newest first", () async {
      await fs.collection('enrollmentRequests').add({
        'tenantId': 'u1',
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });
      await fs.collection('enrollmentRequests').add({
        'tenantId': 'u1',
        'status': 'bill_sent',
        'createdAt': Timestamp.fromDate(DateTime(2026, 2, 1)),
      });
      await fs.collection('enrollmentRequests').add({'tenantId': 'other', 'status': 'pending'});

      final mine = await backend.watchMyRequests('u1').first;
      expect(mine.map((r) => r.stage), [EnrollmentStage.billSent, EnrollmentStage.pending]);
    });

    test('submits through the callable', () async {
      fn.reply = {'requestId': 'E9'};
      final id = await backend.submitEnrollment(EnrollmentDraft(
        propertyId: 'P1',
        businessId: 'B1',
        propertyName: 'Green Nest',
        name: 'Asha',
        phone: '+919811100001',
        moveIn: DateTime(2026, 4, 1),
        sharing: 'Double',
        notes: 'Near window',
      ));
      expect(id, 'E9');
      final (name, data) = fn.calls.single;
      expect(name, 'submitEnrollmentRequest');
      expect(data, containsPair('propertyId', 'P1'));
      expect(data, containsPair('tenantName', 'Asha'));
      expect(data, containsPair('sharingType', 'Double'));
      expect(data['moveInDate'], DateTime(2026, 4, 1).toIso8601String());
    });

    test('marks the bill paid with the reference', () async {
      await fs.doc('enrollmentRequests/E1').set({'tenantId': 'u1', 'status': 'bill_sent'});
      await backend.submitBillPayment('E1', uid: 'u1', reference: 'UTR123456');
      final d = (await fs.doc('enrollmentRequests/E1').get()).data()!;
      expect(d['status'], 'payment_submitted');
      expect(d['transactionId'], 'UTR123456');
      expect(d['paymentSubmittedBy'], 'u1');
    });

    test('withdraws by deleting', () async {
      await fs.doc('enrollmentRequests/E1').set({'tenantId': 'u1', 'status': 'pending'});
      await backend.withdraw('E1');
      expect((await fs.doc('enrollmentRequests/E1').get()).exists, isFalse);
    });
  });

  group('rent', () {
    test('reads payment settings', () async {
      await fs.doc('businesses/B1/settings/razorpay').set({'paymentsEnabled': true, 'upiId': ' owner@upi '});
      final s = await backend.loadSettings('B1');
      expect(s.onlineEnabled, isTrue);
      expect(s.upiId, 'owner@upi');
      final none = await backend.loadSettings('B2');
      expect(none.onlineEnabled, isFalse);
      expect(none.upiId, isNull);
    });

    test('creates a payment link', () async {
      fn.reply = {'paymentLinkUrl': 'https://rzp.io/x'};
      final url = await backend.createPaymentLink(businessId: 'B1', tenantId: 'TEN1', invoiceId: 'I1');
      expect(url, 'https://rzp.io/x');
      expect(fn.calls.single.$1, 'createPaymentLink');
      expect(fn.calls.single.$2, {'businessId': 'B1', 'tenantId': 'TEN1', 'rentInvoiceId': 'I1'});
    });

    test('fails clearly without a link', () async {
      fn.reply = {};
      expect(
        () => backend.createPaymentLink(businessId: 'B1', tenantId: 'TEN1', invoiceId: 'I1'),
        throwsA(isA<TenantFailure>()),
      );
    });

    test('submits a manual payment', () async {
      await backend.submitRentPayment(const RentSubmission(
        businessId: 'B1',
        amount: 9000,
        month: 'March 2026',
        mode: 'UPI',
        reference: 'UTR1',
        invoiceId: 'I1',
      ));
      expect(fn.calls.single.$1, 'submitRentPayment');
      expect(fn.calls.single.$2, {
        'businessId': 'B1',
        'amount': 9000.0,
        'month': 'March 2026',
        'paymentMode': 'UPI',
        'transactionId': 'UTR1',
        'rentInvoiceId': 'I1',
      });
    });
  });

  group('notifications', () {
    test('lists newest first and marks read', () async {
      final col = fs.collection('tenants/TEN1/notifications');
      final a = await col.add({'title': 'Old', 'read': false, 'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1))});
      await col.add({'title': 'New', 'read': false, 'createdAt': Timestamp.fromDate(DateTime(2026, 2, 1))});

      final list = await backend.watchNotifications('TEN1').first;
      expect(list.map((n) => n.title), ['New', 'Old']);

      await backend.markRead('TEN1', [a.id]);
      expect((await a.get()).data()!['read'], isTrue);
    });
  });

  group('invitations', () {
    test('lists, loads, accepts and declines through callables', () async {
      fn.reply = {
        'invitations': [
          {'id': 'I1', 'propertyName': 'Green Nest', 'businessId': 'B', 'propertyId': 'P', 'status': 'pending'},
        ],
      };
      final list = await backend.listInvitations();
      expect(list.single.propertyName, 'Green Nest');

      fn.reply = {'invitation': {'id': 'I1', 'status': 'accepted', 'businessId': 'B', 'propertyId': 'P'}};
      expect((await backend.loadInvitation('I1')).status, 'accepted');

      fn.reply = {'success': true};
      await backend.acceptInvitation('I1');
      await backend.declineInvitation('I1', reason: 'Found another place');

      expect(fn.calls.map((c) => c.$1), [
        'listMyTenantInvitations',
        'getMyTenantInvitation',
        'approveInvitation',
        'rejectTenantInvitation',
      ]);
      expect(fn.calls.last.$2, {'invitationId': 'I1', 'reason': 'Found another place'});
    });
  });

  group('pinboard', () {
    test('adds a 48h note and lists live ones', () async {
      await backend.addPin(const PinDraft(
        propertyId: 'P1',
        authorId: 'u1',
        authorName: 'Asha',
        authorPhone: '98',
        category: PinCategory.lostFound,
        content: 'Lost keys',
      ));
      await fs.collection('pinboard').add({
        'propertyId': 'P1',
        'content': 'Expired',
        'expiresAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 1))),
      });

      final notes = await backend.watchPins('P1').first;
      expect(notes.map((n) => n.content), ['Lost keys']);
      expect(notes.single.category, PinCategory.lostFound);
      final raw = (await fs.collection('pinboard').doc(notes.single.id).get()).data()!;
      expect(raw['noteId'], notes.single.id);
      expect(raw['category'], 'lost_found');
      final ttl = readDate(raw['expiresAt'])!.difference(DateTime.now());
      expect(ttl.inHours, inInclusiveRange(47, 48));

      await backend.deletePin(notes.single.id);
      expect(await backend.watchPins('P1').first, isEmpty);
    });
  });

  group('maintenance', () {
    const stay = Stay(
      id: 'S1',
      businessId: 'B1',
      propertyId: 'P1',
      propertyName: 'Green Nest',
      roomNumber: '101',
      bedNumber: '2',
    );

    test('raises a request the rules accept, and cancels it', () async {
      await backend.raiseMaintenance(const MaintenanceDraft(
        uid: 'u1',
        tenantId: 'TEN1',
        tenantName: 'Asha',
        tenantPhone: '98',
        stay: stay,
        category: MaintenanceCategory.plumbing,
        title: 'Leaking tap',
        description: 'Bathroom',
        urgent: true,
      ));

      final mine = await backend.watchMyMaintenance('u1').first;
      expect(mine.single.title, 'Leaking tap');
      final raw = (await fs.collection('maintenanceRequests').doc(mine.single.id).get()).data()!;
      expect(raw, containsPair('tenantUid', 'u1'));
      expect(raw, containsPair('businessId', 'B1'));
      expect(raw, containsPair('propertyId', 'P1'));
      expect(raw, containsPair('status', 'open'));
      expect(raw, containsPair('category', 'plumbing'));
      expect(raw, containsPair('priority', 'urgent'));
      expect(raw, containsPair('roomNumber', '101'));

      await backend.cancelMaintenance(mine.single.id);
      final after = (await fs.collection('maintenanceRequests').doc(mine.single.id).get()).data()!;
      expect(after['status'], 'cancelled');
      expect(after.keys.toSet().difference(raw.keys.toSet()), isEmpty);
    });
  });

  group('explore', () {
    test('pages through a city', () async {
      final col = fs.collection('properties_by_city/Pune/properties');
      for (var i = 0; i < 3; i++) {
        await col.doc('P$i').set({
          'name': 'PG $i',
          'status': 'active',
          'updatedAt': Timestamp.fromDate(DateTime(2026, 1, i + 1)),
        });
      }
      final first = await backend.loadCity('Pune', pageSize: 2);
      expect(first.properties.map((p) => p.name), ['PG 2', 'PG 1']);
      expect(first.hasMore, isTrue);
      final next = await backend.loadCity('Pune', cursor: first.cursor, pageSize: 2);
      expect(next.properties.map((p) => p.name), ['PG 0']);
      expect(next.hasMore, isFalse);
    });

    test('loads a property from its business, else from the city index', () async {
      await fs.doc('businesses/BUS0000001/properties/BUS0000001PNR001').set({'name': 'Source of truth'});
      await fs.doc('properties_by_city/Pune/properties/X1').set({'name': 'Index only', 'city': 'Pune'});

      expect((await backend.loadProperty('BUS0000001PNR001'))!.name, 'Source of truth');
      expect((await backend.loadProperty('X1'))!.name, 'Index only');
      expect(await backend.loadProperty('missing'), isNull);
    });

    test('saves favourites on the user doc', () async {
      await fs.doc('users/u1').set({'fullName': 'A'});
      await backend.setFavorite('u1', 'P1', true);
      await backend.setFavorite('u1', 'P2', true);
      await backend.setFavorite('u1', 'P1', false);
      expect((await fs.doc('users/u1').get()).data()!['favoritePropertyIds'], ['P2']);
    });
  });
}
