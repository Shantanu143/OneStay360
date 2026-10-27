import 'package:business/models/payment_method_model.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/payment_methods/method_form_viewmodel.dart';
import 'package:business/presentation/payment_methods/payment_methods_screen.dart';
import 'package:business/services/payment_method_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeService implements PaymentMethodService {
  FakeService(this.methods);

  List<PaymentMethod> methods;
  Object? loadFailure;
  final calls = <String>[];

  @override
  Future<List<PaymentMethod>> getPaymentMethods(String businessId) async {
    if (loadFailure != null) throw loadFailure!;
    return methods;
  }

  @override
  Future<void> updatePaymentMethod(PaymentMethod m) async {
    calls.add('update:${m.id}:${m.isActive}');
    methods = [for (final x in methods) x.id == m.id ? m : x];
  }

  @override
  Future<void> setPreferredPaymentMethod(String businessId, String methodId) async {
    calls.add('preferred:$methodId');
    methods = [for (final x in methods) x.copyWith(isPreferred: x.id == methodId)];
  }

  @override
  Future<void> deletePaymentMethod(String businessId, String methodId) async {
    calls.add('delete:$methodId');
    methods = [for (final x in methods) if (x.id != methodId) x];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRazorpay implements RazorpayGateway {
  RazorpayStatus current = const RazorpayStatus.notSet();
  Object? verifyFailure;
  int verifies = 0;

  @override
  Future<void> saveCredentials(String businessId,
      {required String keyId, required String keySecret, required String webhookSecret}) async {}

  @override
  Future<RazorpayStatus> status(String businessId) async => current;

  @override
  Future<void> verify(String businessId) async {
    verifies++;
    if (verifyFailure != null) throw verifyFailure!;
  }
}

PaymentMethod upi({bool preferred = false, bool active = true}) => PaymentMethod(
      id: 'u1',
      businessId: 'BUS1',
      type: 'upi',
      upiId: 'sunrise@okhdfcbank',
      isActive: active,
      isPreferred: preferred,
      createdAt: DateTime(2026, 1, 1),
    );

PaymentMethod bank() => PaymentMethod(
      id: 'b1',
      businessId: 'BUS1',
      type: 'bank',
      bankName: 'HDFC Bank',
      accountHolderName: 'Rajesh Sharma',
      accountNumber: '1234567890',
      ifscCode: 'HDFC0001234',
      isActive: true,
      isPreferred: false,
      createdAt: DateTime(2026, 1, 2),
    );

PaymentMethod cash() => PaymentMethod(
      id: 'c1',
      businessId: 'BUS1',
      type: 'cash',
      isActive: true,
      isPreferred: false,
      createdAt: DateTime(2026, 1, 3),
    );

PaymentMethod razorpayMethod() => PaymentMethod(
      id: 'r1',
      businessId: 'BUS1',
      type: 'razorpay',
      isActive: true,
      isPreferred: false,
      createdAt: DateTime(2026, 1, 4),
    );

void main() {
  late FakeService service;
  late FakeRazorpay razorpay;
  late List<String> opened;

  setUp(() {
    service = FakeService([upi(preferred: true), bank(), cash()]);
    razorpay = FakeRazorpay();
    opened = [];
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: BizTheme.light(),
        home: PaymentMethodsScreen(
          businessId: 'BUS1',
          service: service,
          razorpay: razorpay,
          openForm: (context, {PaymentMethod? method, MethodType? type}) async {
            opened.add('${method?.id ?? 'new'}:${type?.key ?? method?.type}');
            return false;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('lists each way of getting paid', (tester) async {
    await open(tester);

    expect(find.text('sunrise@okhdfcbank'), findsOneWidget);
    expect(find.text('HDFC Bank · •••• 7890'), findsOneWidget);
    expect(find.text('Cash'), findsWidgets);
    expect(find.text('Preferred'), findsOneWidget);
  });

  testWidgets('says so when there are none', (tester) async {
    service.methods = [];
    await open(tester);

    expect(find.text('No payment methods yet'), findsOneWidget);
  });

  testWidgets('a failed load can be retried', (tester) async {
    service.loadFailure = Exception('denied');
    await open(tester);
    expect(find.text("Couldn't load your payment methods."), findsOneWidget);

    service.loadFailure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('sunrise@okhdfcbank'), findsOneWidget);
  });

  testWidgets('a method can be switched off and on', (tester) async {
    await open(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(service.calls, ['update:u1:false']);
  });

  testWidgets('another method can be made the preferred one', (tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('More for HDFC Bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make preferred'));
    await tester.pumpAndSettle();

    expect(service.calls, ['preferred:b1']);
  });

  testWidgets('delete asks first', (tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('More for HDFC Bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining("can't be undone"), findsOneWidget);

    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(service.calls, ['delete:b1']);
  });

  testWidgets('edit opens the form on that method', (tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('More for HDFC Bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(opened, ['b1:bank']);
  });

  testWidgets('"Add payment method" opens the form', (tester) async {
    await open(tester);

    await tester.tap(find.text('Add payment method'));
    await tester.pumpAndSettle();

    expect(opened, ['new:null']);
  });

  group('Razorpay', () {
    testWidgets('invites setting it up when it is not', (tester) async {
      await open(tester);

      expect(find.text('Not set'), findsOneWidget);
      await tester.tap(find.text('Set up Razorpay'));
      await tester.pumpAndSettle();

      expect(opened, ['new:razorpay']);
    });

    testWidgets('shows its status once set up and can verify it', (tester) async {
      service.methods = [upi(), razorpayMethod()];
      razorpay.current = const RazorpayStatus(configured: true, enabled: true, verified: true);
      await open(tester);

      expect(find.text('Verified'), findsOneWidget);
      await tester.tap(find.text('Verify setup'));
      await tester.pumpAndSettle();

      expect(razorpay.verifies, 1);
      expect(find.text('Razorpay setup verified.'), findsOneWidget);
    });

    testWidgets('is shown as set up when only its settings exist', (tester) async {
      // Tenants pay through the settings, so that is what the card reports.
      razorpay.current = const RazorpayStatus(configured: true, enabled: true, verified: true);
      await open(tester);

      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Set up Razorpay'), findsNothing);

      await tester.tap(find.text('Edit setup'));
      await tester.pumpAndSettle();

      expect(opened, ['new:razorpay'], reason: 'opens the Razorpay form, not the default UPI one');
    });

    testWidgets('a failed verification says so', (tester) async {
      service.methods = [razorpayMethod()];
      razorpay.current = const RazorpayStatus(configured: true, enabled: true);
      razorpay.verifyFailure = Exception('bad keys');
      await open(tester);

      await tester.tap(find.text('Verify setup'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't verify Razorpay. Check your keys and try again."), findsOneWidget);
    });

    testWidgets('editing it opens the form', (tester) async {
      service.methods = [razorpayMethod()];
      razorpay.current = const RazorpayStatus(configured: true, enabled: true);
      await open(tester);

      await tester.tap(find.text('Edit setup'));
      await tester.pumpAndSettle();

      expect(opened, ['r1:razorpay']);
    });
  });
}
