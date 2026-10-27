import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/views/checkout_screen.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/business/property/property_model.dart';
import 'package:provider/provider.dart';

import '../../support/property_fixtures.dart';

class FakeCheckoutRepository implements PropertyRepository {
  FakeCheckoutRepository(this.property);

  final Property property;
  final quotes = <String?>[];
  final orders = <int?>[];

  @override
  Future<Property> getPropertyById(String propertyId) async => property;

  @override
  Future<Map<String, dynamic>> createCheckoutQuote({
    required String businessId,
    required String propertyId,
    required String purpose,
    String? promoCode,
    String? invoiceId,
  }) async {
    quotes.add(promoCode);
    final discount = promoCode == 'HALF' ? 135 : 0;
    return {
      'baseAmount': 270,
      'discountAmount': discount,
      'finalAmount': 270 - discount,
      'plan': {'name': 'Standard', 'pricePerBedInr': 30},
    };
  }

  @override
  Future<Map<String, dynamic>> createActivationOrder({
    required String businessId,
    required String propertyId,
    required String purpose,
    String? promoCode,
    int? clientFinalAmount,
    String? invoiceId,
  }) async {
    orders.add(clientFinalAmount);
    // No key: the screen reports it instead of opening Razorpay.
    return {'orderId': 'order_1'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('shows the price, applies a promo and starts the payment', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1100 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final repo = FakeCheckoutRepository(makeProperty(id: 'P1', name: 'Green Nest', beds: 9));
    await tester.pumpWidget(Provider<PropertyRepository>.value(
      value: repo,
      child: MaterialApp(
        theme: BizTheme.light(),
        home: const CheckoutScreen(propertyId: 'P1', purpose: 'activation'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Go live'), findsOneWidget);
    expect(find.text('₹270'), findsWidgets);
    expect(find.text('Pay & go live · ₹270'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('checkout-promo')), 'HALF');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(repo.quotes.last, 'HALF');
    expect(find.text('− ₹135'), findsOneWidget);
    expect(find.text('Pay & go live · ₹135'), findsOneWidget);

    await tester.tap(find.text('Pay & go live · ₹135'));
    await tester.pumpAndSettle();
    expect(repo.orders, [135]);
    expect(find.text('Missing payment details, please retry'), findsOneWidget);
  });
}
