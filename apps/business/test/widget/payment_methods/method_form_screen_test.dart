import 'package:business/models/payment_method_model.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/payment_methods/method_form_screen.dart';
import 'package:business/presentation/payment_methods/method_form_viewmodel.dart';
import 'package:business/services/payment_method_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeService implements PaymentMethodService {
  final added = <PaymentMethod>[];
  final updated = <PaymentMethod>[];
  Object? addFailure;

  @override
  Future<String> addPaymentMethod(PaymentMethod m) async {
    if (addFailure != null) throw addFailure!;
    added.add(m);
    return 'new1';
  }

  @override
  Future<void> updatePaymentMethod(PaymentMethod m) async => updated.add(m);

  @override
  Future<List<PaymentMethod>> getPaymentMethods(String businessId) async => [...added];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRazorpay implements RazorpayGateway {
  final saved = <String>[];

  @override
  Future<void> saveCredentials(String businessId,
      {required String keyId, required String keySecret, required String webhookSecret}) async {
    saved.add('$keyId:$keySecret:$webhookSecret');
  }

  @override
  Future<RazorpayStatus> status(String businessId) async => const RazorpayStatus.notSet();

  @override
  Future<void> verify(String businessId) async {}
}

void main() {
  late FakeService service;
  late FakeRazorpay razorpay;
  Object? popped = 'unset';

  setUp(() {
    service = FakeService();
    razorpay = FakeRazorpay();
    popped = 'unset';
  });

  Future<void> open(WidgetTester tester, {PaymentMethod? method, MethodType? type}) async {
    tester.view.physicalSize = const Size(400, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: BizTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => PaymentMethodFormScreen(
                      businessId: 'BUS1',
                      method: method,
                      type: type,
                      service: service,
                      razorpay: razorpay,
                    ),
                  ),
                );
              },
              child: const Text('launch'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('launch'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(Key(key)), text);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  group('adding', () {
    testWidgets('a UPI id', (tester) async {
      await open(tester);

      await type(tester, 'upiId', 'sunrise@okhdfcbank');
      await save(tester);

      expect(service.added.single.type, 'upi');
      expect(service.added.single.upiId, 'sunrise@okhdfcbank');
      expect(popped, true);
    });

    testWidgets('says what is wrong with a UPI id', (tester) async {
      await open(tester);

      await type(tester, 'upiId', 'nobank');
      await save(tester);

      expect(find.text('Enter a valid UPI ID, like name@bank.'), findsOneWidget);
      expect(service.added, isEmpty);
      expect(popped, 'unset');
    });

    testWidgets('the form changes with the type', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('upiId')), findsOneWidget);

      await tester.tap(find.text('Bank'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('upiId')), findsNothing);
      expect(find.byKey(const Key('accountNumber')), findsOneWidget);
    });

    testWidgets('a bank account, with the bank picked from suggestions', (tester) async {
      await open(tester, type: MethodType.bank);

      await type(tester, 'bankName', 'hdf');
      await tester.tap(find.text('HDFC Bank'));
      await tester.pumpAndSettle();
      await type(tester, 'holder', 'Rajesh Sharma');
      await type(tester, 'accountNumber', '1234567890');
      await type(tester, 'confirmAccount', '1234567890');
      await type(tester, 'ifsc', 'hdfc0001234');
      await save(tester);

      final m = service.added.single;
      expect(m.type, 'bank');
      expect(m.bankName, 'HDFC Bank');
      expect(m.ifscCode, 'HDFC0001234');
      expect(popped, true);
    });

    testWidgets('cash needs nothing', (tester) async {
      await open(tester, type: MethodType.cash);

      await save(tester);

      expect(service.added.single.type, 'cash');
      expect(popped, true);
    });

    testWidgets('a failed save stays open and says so', (tester) async {
      service.addFailure = Exception('denied');
      await open(tester);

      await type(tester, 'upiId', 'sunrise@okhdfcbank');
      await save(tester);

      expect(find.text("Couldn't save this payment method. Try again."), findsOneWidget);
      expect(popped, 'unset');
    });
  });

  group('Razorpay', () {
    testWidgets('warns about fees first, then stores the keys', (tester) async {
      await open(tester, type: MethodType.razorpay);

      await type(tester, 'rzKeyId', 'rzp_test_AbC123');
      await type(tester, 'rzSecret', 'shhh');
      await save(tester);
      expect(find.text('Before you switch on Razorpay'), findsOneWidget);
      expect(razorpay.saved, isEmpty, reason: 'nothing is stored until they agree');

      await tester.tap(find.text('I understand'));
      await tester.pumpAndSettle();

      expect(razorpay.saved.single, 'rzp_test_AbC123:shhh:');
      expect(service.added.single.type, 'razorpay');
      expect(popped, true);
    });

    testWidgets('declining the warning changes nothing', (tester) async {
      await open(tester, type: MethodType.razorpay);

      await type(tester, 'rzKeyId', 'rzp_test_AbC123');
      await type(tester, 'rzSecret', 'shhh');
      await save(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(razorpay.saved, isEmpty);
      expect(popped, 'unset');
    });
  });

  group('editing', () {
    PaymentMethod existing() => PaymentMethod(
          id: 'm1',
          businessId: 'BUS1',
          type: 'upi',
          upiId: 'old@bank',
          isActive: true,
          isPreferred: true,
          createdAt: DateTime(2026, 1, 1),
        );

    testWidgets('starts from what is saved and cannot change the type', (tester) async {
      await open(tester, method: existing());

      expect(tester.widget<TextFormField>(find.byKey(const Key('upiId'))).controller!.text, 'old@bank');
      expect(find.text('Bank'), findsNothing);
      expect(find.text('Edit UPI'), findsOneWidget);
    });

    testWidgets('saves the change in place', (tester) async {
      await open(tester, method: existing());

      await type(tester, 'upiId', 'new@bank');
      await save(tester);

      expect(service.updated.single.id, 'm1');
      expect(service.updated.single.upiId, 'new@bank');
      expect(service.updated.single.isPreferred, isTrue);
      expect(service.added, isEmpty);
      expect(popped, true);
    });
  });
}
