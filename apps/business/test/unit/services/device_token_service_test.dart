import 'dart:async';

import 'package:business/app/deep_links.dart';
import 'package:business/services/device_token_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePush implements PushGateway {
  String? token = 'tok-1';
  Object? tokenFailure;
  Map<String, dynamic>? initial;
  int permissionRequests = 0;
  int tokenReads = 0;

  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<Map<String, dynamic>>.broadcast();
  final opened = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Future<void> requestPermission() async => permissionRequests++;

  @override
  Future<String?> getToken() async {
    tokenReads++;
    if (tokenFailure != null) throw tokenFailure!;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => foreground.stream;
  @override
  Stream<Map<String, dynamic>> get onOpenedFromBackground => opened.stream;
  @override
  Future<Map<String, dynamic>?> initialMessageData() async => initial;
}

void main() {
  late FakeFirebaseFirestore firestore;
  late _FakePush push;
  late StreamController<User?> auth;
  late List<AppLink> links;
  late DeviceTokenService service;

  final alice = MockUser(uid: 'alice', email: 'a@x.in');
  final bob = MockUser(uid: 'bob', email: 'b@x.in');

  setUp(() {
    firestore = FakeFirebaseFirestore();
    push = _FakePush();
    auth = StreamController<User?>.broadcast();
    links = [];
    service = DeviceTokenService(
      gateway: push,
      authChanges: auth.stream,
      firestore: firestore,
      onLink: links.add,
    );
  });

  tearDown(() async {
    await service.dispose();
    await auth.close();
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  Future<Map<String, dynamic>?> tokenDoc(String uid, String token) async {
    final snap = await firestore
        .collection('users')
        .doc(uid)
        .collection('deviceTokens')
        .doc(token)
        .get();
    return snap.data();
  }

  group('registration', () {
    test(
      'registers the token when the user signs in AFTER the app started',
      () async {
        service.start();
        await settle();
        expect(await tokenDoc('alice', 'tok-1'), isNull);

        auth.add(alice);
        await settle();

        final doc = await tokenDoc('alice', 'tok-1');
        expect(doc, isNotNull);
        expect(doc!['active'], isTrue);
        expect(doc['token'], 'tok-1');
        expect(push.permissionRequests, 1);
      },
    );

    test('registers for a user who is already signed in at start', () async {
      service.start();
      auth.add(alice);
      await settle();

      expect(await tokenDoc('alice', 'tok-1'), isNotNull);
    });

    test('re-registers when FCM rotates the token', () async {
      service.start();
      auth.add(alice);
      await settle();

      push.refresh.add('tok-2');
      await settle();

      expect(await tokenDoc('alice', 'tok-2'), isNotNull);
    });

    test('ignores token refreshes while signed out', () async {
      service.start();
      auth.add(null);
      await settle();

      push.refresh.add('tok-9');
      await settle();

      expect((await firestore.collection('users').get()).docs, isEmpty);
    });

    test(
      'deactivates the token on sign-out so the next user is not notified',
      () async {
        service.start();
        auth.add(alice);
        await settle();

        auth.add(null);
        await settle();

        expect((await tokenDoc('alice', 'tok-1'))!['active'], isFalse);
      },
    );

    test('moves the device to the new user on an account switch', () async {
      service.start();
      auth.add(alice);
      await settle();

      auth.add(bob);
      await settle();

      expect((await tokenDoc('alice', 'tok-1'))!['active'], isFalse);
      expect((await tokenDoc('bob', 'tok-1'))!['active'], isTrue);
    });

    test(
      'deactivateCurrentToken works before sign-out and is safe to repeat',
      () async {
        service.start();
        auth.add(alice);
        await settle();

        await service.deactivateCurrentToken();
        await service.deactivateCurrentToken();

        expect((await tokenDoc('alice', 'tok-1'))!['active'], isFalse);
      },
    );

    test('start() is idempotent', () async {
      service
        ..start()
        ..start();
      auth.add(alice);
      await settle();

      expect(push.tokenReads, 1);
    });

    test(
      'survives a failing gateway and retries on the next sign-in',
      () async {
        push.tokenFailure = Exception('no play services');
        service.start();
        auth.add(alice);
        await settle();
        expect(await tokenDoc('alice', 'tok-1'), isNull);

        push.tokenFailure = null;
        auth.add(null);
        auth.add(alice);
        await settle();

        expect(await tokenDoc('alice', 'tok-1'), isNotNull);
      },
    );
  });

  group('notification taps', () {
    test('a tap from the background opens the matching link', () async {
      service.start();

      push.opened.add({'type': 'enrollment_request', 'propertyId': 'P1'});
      await settle();

      expect(links, hasLength(1));
      expect((links.single as PropertyTabLink).propertyId, 'P1');
    });

    test('the notification that launched the app is handled once', () async {
      push.initial = {'type': 'payment_submitted', 'businessId': 'B1'};

      service.start();
      await settle();

      expect(links.whereType<PendingPaymentsLink>(), hasLength(1));
    });

    test('foreground messages never navigate the user away', () async {
      service.start();

      push.foreground.add({'type': 'enrollment_request', 'propertyId': 'P1'});
      await settle();

      expect(links, isEmpty);
    });

    test('unknown payloads are ignored', () async {
      service.start();

      push.opened.add({'type': 'something_else'});
      await settle();

      expect(links, isEmpty);
    });
  });
}
