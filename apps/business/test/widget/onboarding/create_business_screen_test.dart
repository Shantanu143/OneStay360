import 'package:business/presentation/design/components/biz_button.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/onboarding/create_business_screen.dart';
import 'package:business/presentation/onboarding/create_business_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCreator implements BusinessCreator {
  final created = <String>[];
  Object? failure;

  @override
  Future<String> create(String name) async {
    created.add(name);
    if (failure != null) throw failure!;
    return 'BUS0000042';
  }
}

void main() {
  late FakeCreator creator;
  var reloads = 0;
  Object? popped = 'unset';

  setUp(() {
    creator = FakeCreator();
    reloads = 0;
    popped = 'unset';
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: BizTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute(
                    builder: (_) => CreateBusinessScreen(creator: creator, reloadSession: () async => reloads++),
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

  testWidgets('asks one question', (tester) async {
    await open(tester);

    expect(find.text('Set up your business'), findsOneWidget);
    expect(find.byKey(const Key('business-name')), findsOneWidget);
    expect(find.text('Create business'), findsOneWidget);
  });

  testWidgets('wants a name', (tester) async {
    await open(tester);

    await tester.tap(find.widgetWithText(BizButton, 'Create business'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your business name.'), findsOneWidget);
    expect(creator.created, isEmpty);
  });

  testWidgets('creates the business, reloads the session and goes back', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const Key('business-name')), 'Sunrise Stays');
    await tester.tap(find.widgetWithText(BizButton, 'Create business'));
    await tester.pumpAndSettle();

    expect(creator.created, ['Sunrise Stays']);
    expect(reloads, 1);
    expect(find.text('launch'), findsOneWidget);
    expect(popped, isNull);
  });

  testWidgets('shows why it could not be created and stays', (tester) async {
    creator.failure = Exception('A business already exists for this account.');
    await open(tester);

    await tester.enterText(find.byKey(const Key('business-name')), 'Sunrise Stays');
    await tester.tap(find.widgetWithText(BizButton, 'Create business'));
    await tester.pumpAndSettle();

    expect(find.text('A business already exists for this account.'), findsOneWidget);
    expect(find.text('Set up your business'), findsOneWidget);
    expect(popped, 'unset');
  });
}
