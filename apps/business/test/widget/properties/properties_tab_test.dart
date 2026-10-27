import 'package:business/app/refresh_signals.dart';
import 'package:business/data/providers/business_state_provider.dart';
import 'package:business/presentation/design/components/biz_chips.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/views/properties/properties_tab.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:models/business/property/property_model.dart';
import 'package:provider/provider.dart';

import '../../support/property_fixtures.dart';
import '../../support/session_fixtures.dart';
import '../../unit/view_models/business_dashboard_viewmodel_test.mocks.dart';

void main() {
  late MockPropertyRepository repo;
  late RefreshSignals signals;
  late List<String> calls;

  setUp(() {
    repo = MockPropertyRepository();
    signals = RefreshSignals();
    calls = [];
  });

  tearDown(() => signals.dispose());

  final greenValley = makeProperty(
    id: 'green',
    name: 'Green Valley Co-living',
    status: 'draft',
    single: 12000,
    double: 8000,
    triple: 6500,
    beds: 9,
    rooms: 3,
    updatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
  );
  final sunrise = makeProperty(
    id: 'sunrise',
    name: 'Sunrise Boys PG',
    address: 'Kothrud',
    status: 'active',
    beds: 20,
    availableBeds: 1,
    rooms: 8,
    updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
  );
  final lake = makeProperty(
    id: 'lake',
    name: 'Lake View',
    address: 'Powai',
    city: 'Mumbai',
    status: 'vacant',
    updatedAt: DateTime.now().subtract(const Duration(days: 3)),
  );

  void stub(List<Property> list) => when(
    repo.getPropertiesByBusiness('BUS1'),
  ).thenAnswer((_) async => List.of(list));

  Future<void> pumpTab(
    WidgetTester tester, {
    String role = 'owner',
    bool settle = true,
    Future<Map<String, int>> Function(String businessId)? occupancyLoader,
    Set<String>? scope,
  }) async {
    // Property cards are ~400px tall: use a tall screen so every card is built.
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final provider = await readyProvider(role: role, scope: scope);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BusinessStateProvider>.value(value: provider),
          Provider<PropertyRepository>.value(value: repo),
          Provider<RefreshSignals>.value(value: signals),
        ],
        child: MaterialApp(
          theme: BizTheme.light(),
          home: Scaffold(
            body: PropertiesTab(
              occupancyLoader: occupancyLoader,
              imageBuilder: (context, url) =>
                  const ColoredBox(color: Colors.teal),
              onOpenProperty: (_, p) => calls.add('open:${p.id}'),
              onEditProperty: (_, p) => calls.add('edit:${p.id}'),
              onAddProperty: (_) async => calls.add('add'),
              onProfile: (_) => calls.add('profile'),
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pump();
      await tester.pumpAndSettle();
    }
  }

  testWidgets('shows the summary, title and a card per property', (
    tester,
  ) async {
    stub([greenValley, sunrise, lake]);
    await pumpTab(tester);

    expect(find.text('3 properties · 2 cities'), findsOneWidget);
    expect(find.text('Properties'), findsOneWidget);
    expect(find.text('Green Valley Co-living'), findsOneWidget);
    expect(find.text('Sunrise Boys PG'), findsOneWidget);
    expect(find.text('₹6.5K–12K'), findsWidgets);
  });

  testWidgets('shows occupancy from the tenants living there, not the stored counter', (tester) async {
    // The stored counter says 1 of 20 beds is free (95%); only 5 people live there.
    stub([sunrise]);
    await pumpTab(tester, occupancyLoader: (_) async => {'sunrise': 5});

    expect(find.text('25%'), findsOneWidget);
    expect(find.text('95%'), findsNothing);
  });

  testWidgets('a manager sees only the properties they were given', (tester) async {
    stub([greenValley, sunrise, lake]);
    await pumpTab(tester, role: 'manager', scope: {'sunrise'});

    expect(find.text('Sunrise Boys PG'), findsOneWidget);
    expect(find.text('Green Valley Co-living'), findsNothing);
    expect(find.text('Lake View'), findsNothing);
    expect(find.text('1 property · Pune'), findsOneWidget);
    expect(find.textContaining('still a draft'), findsNothing, reason: 'the draft is not theirs');
  });

  testWidgets('shows loading placeholders until the first load completes', (
    tester,
  ) async {
    stub([greenValley]);
    await pumpTab(tester, settle: false);

    expect(find.text('Green Valley Co-living'), findsNothing);

    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Green Valley Co-living'), findsOneWidget);
  });

  testWidgets('a draft banner leads to the drafts', (tester) async {
    stub([greenValley, sunrise, lake]);
    await pumpTab(tester);

    expect(find.text('1 property is still a draft'), findsOneWidget);
    await tester.tap(find.text('1 property is still a draft'));
    await tester.pumpAndSettle();

    expect(find.text('Green Valley Co-living'), findsOneWidget);
    expect(find.text('Sunrise Boys PG'), findsNothing);
    expect(
      find.text('1 property is still a draft'),
      findsNothing,
      reason: 'banner steps aside once you are looking at drafts',
    );
  });

  testWidgets('no banner without drafts', (tester) async {
    stub([sunrise, lake]);
    await pumpTab(tester);

    expect(find.textContaining('still a draft'), findsNothing);
  });

  testWidgets('status chips filter the list and All shows the total', (
    tester,
  ) async {
    stub([greenValley, sunrise, lake]);
    await pumpTab(tester);

    expect(find.text('3'), findsWidgets); // All 3
    await tester.tap(
      find.descendant(
        of: find.byType(BizFilterChips),
        matching: find.text('Vacant'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lake View'), findsOneWidget);
    expect(find.text('Sunrise Boys PG'), findsNothing);
  });

  testWidgets('search filters after a pause and explains an empty result', (
    tester,
  ) async {
    stub([greenValley, sunrise, lake]);
    await pumpTab(tester);

    await tester.enterText(find.byType(TextField), 'powai');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Lake View'), findsOneWidget);
    expect(find.text('Sunrise Boys PG'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz nothing');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('No properties match'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Sunrise Boys PG'), findsOneWidget);
  });

  testWidgets('owners with no properties are invited to add one', (
    tester,
  ) async {
    stub([]);
    await pumpTab(tester);

    expect(find.text('No properties yet'), findsWidgets);
    await tester.tap(find.text('Add property'));
    await tester.pumpAndSettle();
    expect(calls, ['add']);
  });

  testWidgets('managers with no properties are not offered "Add property"', (
    tester,
  ) async {
    stub([]);
    await pumpTab(tester, role: 'manager');

    expect(find.text('Add property'), findsNothing);
    expect(find.textContaining('assigned'), findsOneWidget);
  });

  testWidgets('a failed load shows an error and retry recovers', (
    tester,
  ) async {
    when(repo.getPropertiesByBusiness('BUS1')).thenThrow(Exception('offline'));
    await pumpTab(tester);

    expect(find.text('Try again'), findsOneWidget);

    stub([sunrise]);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Sunrise Boys PG'), findsOneWidget);
  });

  testWidgets('cards open and edit their property', (tester) async {
    stub([greenValley, sunrise]);
    await pumpTab(tester);

    await tester.tap(find.text('Finish setup')); // draft -> edit
    await tester.tap(find.text('Manage')); // active -> open
    await tester.tap(find.text('Sunrise Boys PG'));
    await tester.pumpAndSettle();

    expect(calls, ['edit:green', 'open:sunrise', 'open:sunrise']);
  });

  testWidgets('only owners can edit', (tester) async {
    stub([sunrise]);
    await pumpTab(tester, role: 'manager');

    expect(find.text('Edit'), findsNothing);
    expect(find.text('Manage'), findsOneWidget);
  });

  testWidgets('sort sheet reorders the list', (tester) async {
    stub([greenValley, sunrise, lake]); // default: most recently updated
    await pumpTab(tester);

    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('Green Valley Co-living'), lessThan(top('Sunrise Boys PG')));

    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Most occupied'));
    await tester.pumpAndSettle();

    // Sunrise is 95% full, the others far less.
    expect(find.text('Sunrise Boys PG'), findsOneWidget);
    final cards = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .toList();
    expect(
      cards.indexOf('Sunrise Boys PG'),
      lessThan(cards.indexOf('Green Valley Co-living')),
    );
  });

  testWidgets('reloads when another screen reports a property change', (
    tester,
  ) async {
    stub([sunrise]);
    await pumpTab(tester);
    verify(repo.getPropertiesByBusiness('BUS1')).called(1);

    stub([sunrise, lake]);
    signals.propertiesChanged();
    await tester.pumpAndSettle();

    verify(repo.getPropertiesByBusiness('BUS1')).called(1);
    expect(find.text('Lake View'), findsOneWidget);
  });

  testWidgets('the avatar opens the profile', (tester) async {
    stub([sunrise]);
    await pumpTab(tester);

    await tester.tap(find.text('RS'));
    await tester.pumpAndSettle();

    expect(calls, ['profile']);
  });
}
