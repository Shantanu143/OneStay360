// Renders screens to PNG for visual comparison with the design mock-ups.
//
//   RENDER_DIR=/tmp/renders flutter test test/preview --update-goldens
//
// Skipped (and harmless) in a normal `flutter test` run.
import 'package:business/app/refresh_signals.dart';
import 'package:business/data/providers/business_state_provider.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/design/tokens.dart';
import 'package:business/presentation/views/properties/properties_tab.dart';
import 'package:business/presentation/views/widgets/floating_nav_bar.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../support/property_fixtures.dart';
import '../support/render.dart';
import '../support/session_fixtures.dart';
import '../support/wizard_fakes.dart';
import 'package:business/app/business_shell.dart';
import 'package:business/presentation/view_models/tenant_wizard/wizard_viewmodel.dart';
import 'package:business/presentation/views/tenants/add_tenant_wizard.dart';
import 'package:models/business/property/property_room_model.dart';
import '../unit/view_models/business_dashboard_viewmodel_test.mocks.dart';

void main() {
  final enabled = renderDir != null;

  setUpAll(() async {
    if (enabled) await loadDesignFonts();
  });

  Widget nav({int selected = 1, bool fab = true}) => FloatingNavBar(
    selectedIndex: selected,
    items: const [
      FloatingNavItem(icon: Icons.home_outlined, label: 'Home'),
      FloatingNavItem(icon: Icons.apartment_outlined, label: 'Properties'),
      FloatingNavItem(icon: Icons.people_outline, label: 'Tenants'),
      FloatingNavItem(
        icon: Icons.stacked_line_chart_outlined,
        label: 'Reports',
      ),
    ],
    onSelected: (_) {},
    onQuickAdd: fab ? () async {} : null,
  );

  testWidgets('properties', (tester) async {
    useIphoneView(tester);
    final repo = MockPropertyRepository();
    when(repo.getPropertiesByBusiness('BUS1')).thenAnswer(
      (_) async => [
        makeProperty(
          id: 'green',
          name: 'Green Valley Co-living',
          address: 'Baner-Pashan Link Rd, Baner',
          status: 'draft',
          single: 12000,
          double: 8000,
          triple: 6500,
          beds: 9,
          rooms: 3,
          availableBeds: 9,
          images: const ['a', 'b', 'c'],
          updatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
        ),
        makeProperty(id: 'b', name: 'Sunrise Boys PG', status: 'active'),
        makeProperty(id: 'c', name: 'Lake View', status: 'vacant'),
        makeProperty(id: 'd', name: 'Hill Top', status: 'active'),
      ],
    );
    final provider = await readyProvider();
    final signals = RefreshSignals();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BusinessStateProvider>.value(value: provider),
          Provider<PropertyRepository>.value(value: repo),
          Provider<RefreshSignals>.value(value: signals),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BizTheme.light(),
          home: Scaffold(
            extendBody: true,
            backgroundColor: BizColors.page,
            body: PropertiesTab(
              imageBuilder: (c, u) => const ColoredBox(color: BizColors.photo),
            ),
            bottomNavigationBar: nav(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await snapshot(tester, 'properties');
  }, skip: !enabled);

  testWidgets('add tenant step 1', (tester) async {
    useIphoneView(tester);
    final provider = await readyProvider();
    final data = FakeAssignments(
      props: [makeProperty(id: 'sun', name: 'Sunrise Boys PG', double: 6500)],
      rooms: {
        'sun': [
          room('101', '1', 3),
          room('102', '1', 4),
          room('201', '2', 3),
          room('202', '2', 4),
          room('301', '3', 5),
        ],
      },
      occupied: {
        'sun': {
          '101': {'1', '2', '3'},
          '102': {'1', '2', '3', '4'},
          '201': {'1', '2', '3'},
          '202': {'1', '2', '3'},
          '301': {'1'},
        },
      },
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BusinessStateProvider>.value(value: provider),
          ChangeNotifierProvider<ShellController>(
            create: (_) => ShellController(),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BizTheme.light(),
          home: Scaffold(
            extendBody: true,
            backgroundColor: BizColors.page,
            body: AddTenantWizard(
              viewModelFactory: (_) => AddTenantWizardViewModel(
                assignments: data,
                submitter: (_) async => null,
              ),
            ),
            bottomNavigationBar: nav(selected: 2, fab: false),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    // pick B2 on floor 3 like the mock-up
    await tester.tap(find.byKey(const ValueKey('floor-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bed-301-2')));
    await tester.pumpAndSettle();
    await snapshot(tester, 'add_tenant_1');
  }, skip: !enabled);
}
