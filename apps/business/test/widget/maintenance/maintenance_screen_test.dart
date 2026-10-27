import 'package:business/data/providers/business_state_provider.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/maintenance/maintenance_models.dart';
import 'package:business/presentation/maintenance/maintenance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/session_fixtures.dart';
import '../../unit/maintenance/maintenance_viewmodel_test.dart' show FakeMaintenanceSource;

void main() {
  late FakeMaintenanceSource source;

  Future<void> pump(WidgetTester tester, {Set<String>? scope, String role = 'owner'}) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final provider = await tester.runAsync(() => readyProvider(role: role, scope: scope));
    source = FakeMaintenanceSource();
    await tester.pumpWidget(
      ChangeNotifierProvider<BusinessStateProvider>.value(
        value: provider!,
        child: MaterialApp(
          theme: BizTheme.light(),
          home: MaintenanceScreen(source: source, uid: 'owner1', clock: () => DateTime(2026, 3, 10, 12)),
        ),
      ),
    );
  }

  MaintenanceItem item(String id, MaintenanceState s, {String property = 'P1', bool urgent = false}) => MaintenanceItem(
        id: id,
        title: 'Fan $id',
        status: s,
        propertyId: property,
        propertyName: 'Green Nest',
        roomNumber: '101',
        tenantName: 'Asha',
        tenantPhone: '9811100001',
        urgent: urgent,
        createdAt: DateTime(2026, 3, 10, 9),
      );

  testWidgets('lists what to fix and starts work', (tester) async {
    await pump(tester);
    source.controller.add([item('a', MaintenanceState.open, urgent: true), item('b', MaintenanceState.resolved)]);
    await tester.pumpAndSettle();

    expect(find.text('Fan a'), findsOneWidget);
    expect(find.text('Fan b'), findsNothing);
    expect(find.text('Electrical · Urgent · 3h ago'), findsNothing, reason: 'category falls back to Other');
    expect(find.text('Other · Urgent · 3h ago'), findsOneWidget);
    expect(find.text('Asha · Green Nest · Room 101'), findsOneWidget);

    await tester.tap(find.text('Start work'));
    await tester.pumpAndSettle();
    expect(source.updates, ['a:in_progress::owner1']);
  });

  testWidgets('marking fixed asks for an optional note', (tester) async {
    await pump(tester);
    source.controller.add([item('a', MaintenanceState.inProgress)]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark fixed'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Replaced it');
    await tester.tap(find.text('Mark fixed').last);
    await tester.pumpAndSettle();

    expect(source.updates, ['a:resolved:Replaced it:owner1']);
  });

  testWidgets('done requests sit under Done', (tester) async {
    await pump(tester);
    source.controller.add([item('b', MaintenanceState.resolved)]);
    await tester.pumpAndSettle();
    expect(find.text('Nothing to fix'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Fan b'), findsOneWidget);
    expect(find.text('Start work'), findsNothing);
  });

  testWidgets('staff see only their properties', (tester) async {
    await pump(tester, role: 'staff', scope: {'P2'});
    source.controller.add([item('a', MaintenanceState.open), item('c', MaintenanceState.open, property: 'P2')]);
    await tester.pumpAndSettle();
    expect(find.text('Fan a'), findsNothing);
    expect(find.text('Fan c'), findsOneWidget);
  });
}
