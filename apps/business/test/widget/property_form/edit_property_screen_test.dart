import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/view_models/add_property_viewmodel.dart';
import 'package:business/presentation/views/edit_property_screen.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:firebase_services/services/image_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/business/property/property_model.dart';
import 'package:provider/provider.dart';

import '../../unit/property_form/edit_property_draft_test.dart' show listed;

class _Images implements ImageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements PropertyRepository {
  @override
  Future<Property> getPropertyById(String propertyId) async => listed();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final calls = <Map<String, dynamic>>[];
  Object? failWith;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1200 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    calls.clear();
    final repo = _Repo();
    await tester.pumpWidget(MultiProvider(
      providers: [Provider<PropertyRepository>.value(value: repo)],
      child: MaterialApp(
        theme: BizTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider(
                    create: (_) => AddPropertyViewModel(
                      imageService: _Images(),
                      propertyRepository: repo,
                      updateDetails: (b, p, d) async {
                        if (failWith != null) throw failWith!;
                        calls.add({'b': b, 'p': p, ...d});
                      },
                    ),
                    child: const EditPropertyScreen(businessId: 'BUS0000001', propertyId: 'BUS0000001PNR001'),
                  ),
                )),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('loads the property, edits it and saves through the callable', (tester) async {
    failWith = null;
    await pump(tester);
    expect(find.text('Edit property'), findsOneWidget);
    expect(find.text('Rooms'), findsNothing, reason: 'rooms are managed on the property');
    expect(find.text("City (can't be changed)"), findsOneWidget);

    await tester.enterText(find.byKey(const Key('property-name')), 'Green Nest Annexe');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.single['b'], 'BUS0000001');
    expect(calls.single['p'], 'BUS0000001PNR001');
    expect(calls.single['name'], 'Green Nest Annexe');
    expect(calls.single['images'], ['https://x/a.jpg', 'https://x/b.jpg']);
    expect(find.text('open'), findsOneWidget, reason: 'popped back after saving');
  });

  testWidgets('a problem on an earlier step jumps back to it', (tester) async {
    failWith = null;
    await pump(tester);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Save changes'), findsOneWidget);
    tester.element(find.byType(EditPropertyScreen)).read<AddPropertyViewModel>().pincodeController.text = '41';
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(calls, isEmpty);
    expect(find.text('PIN codes have 6 digits.'), findsOneWidget);
    expect(find.byKey(const Key('property-pincode')), findsOneWidget);
  });

  testWidgets('a server refusal stays on screen', (tester) async {
    failWith = Exception('Add a rent for at least one sharing type.');
    await pump(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Add a rent for at least one sharing type.'), findsOneWidget);
    expect(find.text('Edit property'), findsOneWidget);
  });
}
