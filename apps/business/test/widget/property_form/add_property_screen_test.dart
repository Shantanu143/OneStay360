import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/view_models/add_property_viewmodel.dart';
import 'package:business/presentation/views/add_property_screen.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:firebase_services/services/image_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/business/property/property_model.dart';
import 'package:provider/provider.dart';

/// `implements` so the real constructor (which reaches for Firebase Storage)
/// never runs.
class FakeImageService implements ImageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRepository implements PropertyRepository {
  Property? added;

  @override
  Future<String> generatePropertyId(String businessId, String cityCode) async => '${businessId}PNR001';

  @override
  Future<void> addProperty(Property property) async => added = property;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeRepository repo;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    repo = FakeRepository();
    await tester.pumpWidget(MaterialApp(
      theme: BizTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) => AddPropertyViewModel(imageService: FakeImageService(), propertyRepository: repo),
                  child: const AddPropertyScreen(
                    businessId: 'BUS0000001',
                    businessName: 'Apex Living',
                    businessPhone: '9811100001',
                  ),
                ),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  testWidgets('walks through every step and saves the property', (tester) async {
    await pump(tester);
    expect(find.text('Add property'), findsOneWidget);

    // Basics: nothing filled yet.
    await next(tester);
    expect(find.text('Enter the property name.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('property-name')), 'Green Nest');
    await tester.tap(find.text('Pune'));
    await tester.enterText(find.byKey(const Key('property-address')), '12 Baner Road');
    await tester.enterText(find.byKey(const Key('property-pincode')), '411045');
    await tester.enterText(find.byKey(const Key('property-floors')), '1');
    await next(tester);

    // Photos are optional.
    expect(find.text('Add photos'), findsOneWidget);
    await next(tester);

    // Pricing.
    await next(tester);
    expect(find.text('Choose up to how many people share a room.'), findsOneWidget);
    await tester.tap(find.text('Up to 2'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('price-2-nonac')), '8000');
    await next(tester);

    // Rooms.
    await next(tester);
    expect(find.text('Add at least one room.'), findsOneWidget);
    await tester.tap(find.text('Add your first room'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('room-0-number')), '101');
    await tester.tap(find.text('Ground').last);
    await tester.pumpAndSettle();
    await next(tester);

    // Amenities.
    await tester.tap(find.text('Wi-Fi'));
    await tester.pumpAndSettle();
    await next(tester);

    // Rules.
    await tester.tap(find.text('Add property').last);
    await tester.pumpAndSettle();
    expect(find.text('Choose who can stay.'), findsOneWidget);
    await tester.tap(find.text('Co-ed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add property').last);
    await tester.pumpAndSettle();

    final p = repo.added!;
    expect(p.name, 'Green Nest');
    expect(p.city, 'Pune');
    expect(p.pincode, '411045');
    expect(p.amenities.wifi, isTrue);
    expect(p.rules.genderAllowed, 'Co-ed');
    expect(find.text('open'), findsOneWidget, reason: 'popped back after saving');
  });

  testWidgets('back on the first step asks before discarding', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this property?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });
}
