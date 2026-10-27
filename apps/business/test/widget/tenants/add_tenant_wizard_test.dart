import 'package:business/app/business_shell.dart';
import 'package:business/app/refresh_signals.dart';
import 'package:business/data/providers/business_state_provider.dart';
import 'package:business/presentation/design/components/biz_button.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/view_models/tenant_wizard/draft_store.dart';
import 'package:business/presentation/view_models/tenant_wizard/wizard_viewmodel.dart';
import 'package:business/presentation/views/tenants/add_tenant_wizard.dart';
import 'package:firebase_services/services/tenant_search_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/business/property/property_pricing_model.dart';
import 'package:provider/provider.dart';

import '../../support/property_fixtures.dart';
import '../../support/session_fixtures.dart';
import '../../support/wizard_fakes.dart';

void main() {
  late FakeAssignments data;
  late List<WizardSubmission> sent;
  late MemoryDraftStore drafts;
  late int finished;
  late RefreshSignals signals;
  late ShellController shell;
  Map<String, dynamic>? scanned;
  List<TenantSearchResult> searchResults = [];

  final sunrise = makeProperty(
    id: 'sun',
    name: 'Sunrise Boys PG',
    single: 9000,
    double: 6500,
    triple: 5000,
    deposit: 13000,
    maintenance: 500,
    sharingPrices: [SharingPricingEntry(sharing: 2, nonAc: 6500, ac: 8000)],
  );
  final lake = makeProperty(
    id: 'lake',
    name: 'Lake View',
    double: 7000,
    deposit: 7000,
  );

  setUp(() {
    sent = [];
    finished = 0;
    signals = RefreshSignals();
    shell = ShellController()..goTo(ShellTab.tenants);
    scanned = null;
    searchResults = [];
    drafts = MemoryDraftStore();
    data = FakeAssignments(
      props: [sunrise, lake],
      rooms: {
        'sun': [
          room('101', '1', 2),
          room('201', '2', 2, ac: true),
          room('301', '3', 3),
        ],
        'lake': [room('11', '1', 1)],
      },
      occupied: {
        'sun': {
          '101': {'1', '2'},
          '301': {'1'},
        },
      },
    );
  });

  tearDown(() {
    signals.dispose();
    shell.dispose();
  });

  Future<void> pumpWizard(WidgetTester tester, {String? error, bool defaultFinish = false}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = await readyProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BusinessStateProvider>.value(value: provider),
          ChangeNotifierProvider<ShellController>.value(value: shell),
          Provider<RefreshSignals>.value(value: signals),
        ],
        child: MaterialApp(
          theme: BizTheme.light(),
          home: Scaffold(
            body: AddTenantWizard(
              viewModelFactory: (_) => AddTenantWizardViewModel(
                assignments: data,
                submitter: (s) async {
                  sent.add(s);
                  return error;
                },
                drafts: drafts,
              ),
              searchTenants: (q) async => searchResults,
              openScanner: (_) async => scanned,
              onFinished: defaultFinish ? null : (_) => finished++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Finder cta(String label) => find.widgetWithText(BizButton, label);

  Future<void> pickBed(
    WidgetTester tester, {
    String floor = '3',
    String room = '301',
    String bed = '2',
  }) async {
    await tester.tap(find.byKey(ValueKey('floor-$floor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('bed-$room-$bed')));
    await tester.pumpAndSettle();
  }

  Future<void> fillTenantInfo(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('wizard-fullName')),
      'Amit Patel',
    );
    await tester.enterText(
      find.byKey(const ValueKey('wizard-phone')),
      '9876543210',
    );
    await tester.pump();
  }

  group('step 1: property, floor and bed', () {
    testWidgets('shows the header, the step pills and the property', (
      tester,
    ) async {
      await pumpWizard(tester);

      expect(find.text('Tenants'), findsOneWidget);
      expect(find.text('Add Tenant'), findsOneWidget);
      expect(find.text('Save draft'), findsOneWidget);
      for (final step in [
        'Property',
        'Tenant info',
        'Lease',
        'Bill',
        'Personal',
      ]) {
        expect(find.text(step), findsWidgets);
      }
      expect(find.text('Sunrise Boys PG'), findsOneWidget);
      expect(find.text('3 floors · 4 beds free'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('floor cards say how full each floor is', (tester) async {
      await pumpWizard(tester);

      expect(find.text('4 of 7 beds free'), findsOneWidget);
      expect(find.text('Full'), findsOneWidget); // floor 1
      expect(find.text('2 of 2 free'), findsOneWidget); // floor 2
      expect(find.text('2 of 3 free'), findsOneWidget); // floor 3
    });

    testWidgets('a floor with one bed left is flagged "Last bed"', (
      tester,
    ) async {
      data.occupied['sun'] = {
        '301': {'1', '2'},
      };
      await pumpWizard(tester);

      expect(find.text('Last bed'), findsOneWidget);
    });

    testWidgets('opens on the first floor with space and lists its beds', (
      tester,
    ) async {
      await pumpWizard(tester);

      expect(find.text('BED ON FLOOR 2'), findsOneWidget);
      expect(
        find.textContaining('Room 201'),
        findsNothing,
        reason: 'single-room floors stay uncluttered',
      );
      expect(find.text('B1'), findsOneWidget);
      expect(find.text('B2'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Occupied'), findsOneWidget);
      expect(find.text('Selected'), findsOneWidget);
    });

    testWidgets('choosing another floor swaps the beds', (tester) async {
      await pumpWizard(tester);

      await tester.tap(find.byKey(const ValueKey('floor-3')));
      await tester.pumpAndSettle();

      expect(find.text('BED ON FLOOR 3'), findsOneWidget);
      expect(find.text('B3'), findsOneWidget);
    });

    testWidgets('a floor with several rooms names each room', (tester) async {
      data.rooms['sun'] = [room('201', '2', 2, ac: true), room('202', '2', 3)];
      await pumpWizard(tester);

      expect(find.text('Room 201 · 2-sharing · AC'), findsOneWidget);
      expect(find.text('Room 202 · 3-sharing'), findsOneWidget);
    });

    testWidgets('continuing without a bed explains what to do', (tester) async {
      await pumpWizard(tester);

      await tester.tap(cta('Continue to tenant info'));
      await tester.pumpAndSettle();

      expect(find.text('Pick a free bed to continue'), findsOneWidget);
      expect(find.text('Add Tenant'), findsOneWidget);
      expect(find.text('Full name'), findsNothing, reason: 'still on step 1');
    });

    testWidgets('an occupied bed cannot be picked', (tester) async {
      await pumpWizard(tester);
      await tester.tap(find.byKey(const ValueKey('floor-3')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('bed-301-1'))); // occupied
      await tester.pumpAndSettle();
      await tester.tap(cta('Continue to tenant info'));
      await tester.pumpAndSettle();

      expect(find.text('Pick a free bed to continue'), findsOneWidget);
    });

    testWidgets('Change switches property', (tester) async {
      await pumpWizard(tester);

      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lake View').last);
      await tester.pumpAndSettle();

      expect(find.text('Lake View'), findsOneWidget);
      expect(find.text('Sunrise Boys PG'), findsNothing);
      expect(find.text('BED ON FLOOR 1'), findsOneWidget);
    });

    testWidgets('a business with no property is pointed to adding one', (
      tester,
    ) async {
      data = FakeAssignments(props: const [], rooms: const {});
      await pumpWizard(tester);

      expect(find.text('Add a property first'), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      data.failure = Exception('offline');
      await pumpWizard(tester);
      expect(find.text('Try again'), findsOneWidget);

      data.failure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Sunrise Boys PG'), findsOneWidget);
    });
  });

  group('step 2: who is moving in', () {
    Future<void> toTenantInfo(WidgetTester tester) async {
      await pumpWizard(tester);
      await pickBed(tester);
      await tester.tap(cta('Continue to tenant info'));
      await tester.pumpAndSettle();
    }

    testWidgets('moves on and marks the property step done', (tester) async {
      await toTenantInfo(tester);

      expect(find.text('Full name'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(cta('Continue to lease'), findsOneWidget);
    });

    testWidgets('shows errors only after trying to continue', (tester) async {
      await toTenantInfo(tester);
      expect(find.text("Enter the tenant's name"), findsNothing);

      await tester.tap(cta('Continue to lease'));
      await tester.pumpAndSettle();

      expect(find.text("Enter the tenant's name"), findsOneWidget);
      expect(find.text('Enter a valid 10-digit phone number'), findsOneWidget);
    });

    testWidgets('valid details unlock the next step', (tester) async {
      await toTenantInfo(tester);
      await fillTenantInfo(tester);

      await tester.tap(cta('Continue to lease'));
      await tester.pumpAndSettle();

      expect(find.text('Move-in date'), findsOneWidget);
    });

    testWidgets('an earlier step can be revisited from the pills', (
      tester,
    ) async {
      await toTenantInfo(tester);

      await tester.tap(find.text('Property').first);
      await tester.pumpAndSettle();

      expect(find.text('BED ON FLOOR 3'), findsOneWidget);
    });

    testWidgets('searching for an existing tenant fills the step', (
      tester,
    ) async {
      searchResults = [
        TenantSearchResult(
          tenantId: 'TEN1',
          name: 'Karan Singh',
          phone: '9000000103',
        ),
      ];
      await toTenantInfo(tester);

      await tester.tap(find.text('Search tenant'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'kar');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Karan Singh'));
      await tester.pumpAndSettle();
      await tester.tap(cta('Continue to lease'));
      await tester.pumpAndSettle();

      expect(find.text('Move-in date'), findsOneWidget);
    });

    testWidgets('scanning a tenant QR fills the manual form', (tester) async {
      scanned = {
        'name': 'Neha Verma',
        'phone': '9811122233',
        'gender': 'Female',
      };
      await toTenantInfo(tester);

      await tester.tap(find.text('Scan QR'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add manually'));
      await tester.pumpAndSettle();
      expect(find.text('Neha Verma'), findsOneWidget);
    });
  });

  group('the whole flow', () {
    Future<void> pickMoveIn(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('wizard-moveIn')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    testWidgets('sends the invitation and confirms it', (tester) async {
      await pumpWizard(tester);
      await pickBed(
        tester,
      ); // floor 3, room 301, bed B2 -> rent 5000, deposit 13000
      await tester.tap(cta('Continue to tenant info'));
      await tester.pumpAndSettle();

      await fillTenantInfo(tester);
      await tester.tap(cta('Continue to lease'));
      await tester.pumpAndSettle();

      expect(
        find.text('5000'),
        findsOneWidget,
        reason: 'rent prefilled from the property',
      );
      await pickMoveIn(tester);
      await tester.tap(cta('Continue to bill'));
      await tester.pumpAndSettle();

      expect(find.text('Total due now'), findsOneWidget);
      await tester.tap(cta('Continue to personal details'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('wizard-idNumber')),
        'XXXX 1234',
      );
      await tester.enterText(
        find.byKey(const ValueKey('wizard-idAddress')),
        '88 Civil Lines',
      );
      await tester.pump();
      await tester.tap(cta('Send invitation'));
      await tester.pumpAndSettle();

      expect(sent, hasLength(1));
      expect(sent.single.propertyId, 'sun');
      expect(sent.single.roomNumber, '301');
      expect(sent.single.bedNumber, '2');
      expect(sent.single.monthlyRent, 5000);
      expect(sent.single.tenantData['name'], 'Amit Patel');
      expect(find.text('Invitation sent'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(finished, 1);
    });

    testWidgets('finishing sends the owner home and tells the app a tenant, a bed and rent changed', (tester) async {
      await pumpWizard(tester, defaultFinish: true);
      await pickBed(tester);
      await tester.tap(cta('Continue to tenant info'));
      await tester.pumpAndSettle();
      await fillTenantInfo(tester);
      await tester.tap(cta('Continue to lease'));
      await tester.pumpAndSettle();
      await pickMoveIn(tester);
      await tester.tap(cta('Continue to bill'));
      await tester.pumpAndSettle();
      await tester.tap(cta('Continue to personal details'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('wizard-idNumber')), 'XXXX 1234');
      await tester.enterText(find.byKey(const ValueKey('wizard-idAddress')), '88 Civil Lines');
      await tester.pump();
      await tester.tap(cta('Send invitation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(shell.current, ShellTab.home);
      expect(signals.tenants.value, 1);
      expect(signals.properties.value, 1);
      expect(signals.payments.value, 1);
      expect(signals.anyChanged.value, 1);
    });

    testWidgets('shows the reason when the invitation is refused', (
      tester,
    ) async {
      await pumpWizard(tester, error: 'Room is already assigned to females.');
      await pickBed(tester);
      await tester.tap(cta('Continue to tenant info'));
      await tester.pumpAndSettle();
      await fillTenantInfo(tester);
      await tester.tap(cta('Continue to lease'));
      await tester.pumpAndSettle();
      await pickMoveIn(tester);
      await tester.tap(cta('Continue to bill'));
      await tester.pumpAndSettle();
      await tester.tap(cta('Continue to personal details'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('wizard-idNumber')),
        'XXXX 1234',
      );
      await tester.enterText(
        find.byKey(const ValueKey('wizard-idAddress')),
        '88 Civil Lines',
      );
      await tester.pump();
      await tester.tap(cta('Send invitation'));
      await tester.pumpAndSettle();

      expect(find.text('Room is already assigned to females.'), findsOneWidget);
      expect(find.text('Invitation sent'), findsNothing);
    });
  });

  group('drafts', () {
    testWidgets('Save draft keeps the work and a fresh wizard offers it back', (
      tester,
    ) async {
      await pumpWizard(tester);
      await pickBed(tester);
      await tester.tap(cta('Continue to tenant info'));
      await tester.pumpAndSettle();
      await fillTenantInfo(tester);

      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(find.text('Draft saved'), findsOneWidget);
      expect(await drafts.read(), isNotNull);

      await tester.pumpWidget(const SizedBox()); // close the app
      await pumpWizard(tester); // ...and open it again
      expect(find.text('You have an unfinished tenant'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('wizard-fullName')), findsOneWidget);
      expect(find.text('Amit Patel'), findsOneWidget);
    });

    testWidgets('Discard throws the draft away', (tester) async {
      await drafts.write({'step': 0});
      await pumpWizard(tester);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('You have an unfinished tenant'), findsNothing);
      expect(await drafts.read(), isNull);
    });
  });
}
