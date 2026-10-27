import 'package:business/presentation/design/components/biz_button.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/profile/my_details_screen.dart';
import 'package:business/presentation/profile/my_details_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSource implements MyDetailsSource {
  final saved = <String>[];
  Object? failure;

  @override
  Future<void> save({
    required String businessId,
    required String uid,
    required String name,
    String? email,
    String? phone,
  }) async {
    if (failure != null) throw failure!;
    saved.add('$name|$email|$phone');
  }
}

void main() {
  late FakeSource source;
  var reloads = 0;
  Object? popped = 'unset';

  setUp(() {
    source = FakeSource();
    reloads = 0;
    popped = 'unset';
  });

  Future<void> open(WidgetTester tester, {String name = 'Priya Nair', String role = 'manager'}) async {
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
                    builder: (_) => MyDetailsScreen(
                      businessId: 'B1',
                      uid: 'u1',
                      role: role,
                      name: name,
                      email: 'priya@example.test',
                      phone: '+919000000002',
                      source: source,
                      reloadSession: () async => reloads++,
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

  VoidCallback? onSave(WidgetTester tester) => tester.widget<BizButton>(find.widgetWithText(BizButton, 'Save changes')).onPressed;

  testWidgets('shows what is known, and who they are on the team', (tester) async {
    await open(tester);

    expect(find.text('My details'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Priya Nair'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'priya@example.test'), findsOneWidget);
    expect(find.widgetWithText(TextField, '+919000000002'), findsOneWidget);
  });

  testWidgets('Save is off until something changes', (tester) async {
    await open(tester);
    expect(onSave(tester), isNull);

    await tester.enterText(find.byKey(const Key('my-name')), 'Priya N');
    await tester.pump();

    expect(onSave(tester), isNotNull);
  });

  testWidgets('saves, reloads the session and goes back', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const Key('my-name')), 'Priya N');
    await tester.pump();
    await tester.tap(find.widgetWithText(BizButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(source.saved, ['Priya N|priya@example.test|+919000000002']);
    expect(reloads, 1);
    expect(popped, true);
  });

  testWidgets('an empty name is refused with a reason', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const Key('my-name')), '');
    await tester.pump();
    await tester.tap(find.widgetWithText(BizButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your name.'), findsOneWidget);
    expect(source.saved, isEmpty);
  });

  testWidgets('a bad phone number says what is wrong', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const Key('my-phone')), '12345');
    await tester.pump();
    await tester.tap(find.widgetWithText(BizButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a 10-digit mobile number, or leave it blank.'), findsOneWidget);
  });

  testWidgets('a failed save stays open and says so', (tester) async {
    source.failure = Exception('denied');
    await open(tester);

    await tester.enterText(find.byKey(const Key('my-name')), 'Priya N');
    await tester.pump();
    await tester.tap(find.widgetWithText(BizButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't save your details. Try again."), findsOneWidget);
    expect(popped, 'unset');
  });

  testWidgets('the owner sees "Owner"', (tester) async {
    await open(tester, role: 'owner');

    expect(find.text('Owner'), findsOneWidget);
  });
}
