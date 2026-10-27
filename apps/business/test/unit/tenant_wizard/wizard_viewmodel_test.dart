import 'package:business/presentation/view_models/tenant_wizard/assignment_data_source.dart';
import 'package:business/presentation/view_models/tenant_wizard/draft_store.dart';
import 'package:business/presentation/view_models/tenant_wizard/wizard_viewmodel.dart';
import 'package:firebase_services/services/tenant_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/business/property/property_model.dart';
import 'package:models/business/property/property_pricing_model.dart';

import '../../support/property_fixtures.dart';
import '../../support/wizard_fakes.dart';

void main() {
  late FakeAssignments data;
  late List<WizardSubmission> submitted;
  String? submitError;
  late MemoryDraftStore drafts;
  late AddTenantWizardViewModel vm;

  final sunrise = makeProperty(
    id: 'sun',
    name: 'Sunrise Boys PG',
    single: 9000,
    double: 6500,
    triple: 5000,
    deposit: 13000,
    maintenance: 500,
    maintenanceDeducted: true,
    sharingPrices: [SharingPricingEntry(sharing: 2, nonAc: 6500, ac: 8000)],
  );
  final lake = makeProperty(
    id: 'lake',
    name: 'Lake View',
    double: 7000,
    deposit: 7000,
  );

  setUp(() {
    submitted = [];
    submitError = null;
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
          '101': {'1', '2'}, // floor 1 full
          '301': {'1'},
        },
      },
    );
    vm = AddTenantWizardViewModel(
      assignments: data,
      submitter: (s) async {
        submitted.add(s);
        return submitError;
      },
      drafts: drafts,
      clock: () => DateTime(2026, 10, 26),
    );
  });

  tearDown(() => vm.dispose());

  Future<void> loadAndPickBed({String floor = '3', String bed = '2'}) async {
    await vm.load('BUS1');
    vm.selectFloor(floor);
    final room = vm.floor!.rooms.first;
    vm.selectBed(room, room.beds.firstWhere((b) => b.number == bed));
  }

  group('loading', () {
    test('loads properties and selects the first one', () async {
      await vm.load('BUS1');

      expect(vm.loading, isFalse);
      expect(vm.properties.map((p) => p.id), ['sun', 'lake']);
      expect(vm.property?.id, 'sun');
      expect(vm.floors.map((f) => f.floor), ['1', '2', '3']);
    });

    test('honours a pre-selected property', () async {
      await vm.load('BUS1', propertyId: 'lake');
      expect(vm.property?.id, 'lake');
    });

    test('opens on the first floor that still has beds', () async {
      await vm.load('BUS1');
      expect(vm.selectedFloor, '2', reason: 'floor 1 is full');
    });

    test('reports totals across the property', () async {
      await vm.load('BUS1');
      expect(vm.totalBeds, 7);
      expect(vm.freeBeds, 4);
    });

    test('a failure is reported and can be retried', () async {
      data.failure = Exception('offline');
      await vm.load('BUS1');
      expect(vm.loadError, isNotNull);

      data.failure = null;
      await vm.load('BUS1');
      expect(vm.loadError, isNull);
      expect(vm.properties, hasLength(2));
    });

    test('a business with no properties loads cleanly', () async {
      data = FakeAssignments(props: const [], rooms: const {});
      vm = AddTenantWizardViewModel(
        assignments: data,
        submitter: (_) async => null,
      );
      await vm.load('BUS1');
      expect(vm.property, isNull);
      expect(vm.floors, isEmpty);
      expect(vm.loadError, isNull);
    });
  });

  group('choosing a bed', () {
    test('selecting a free bed records the room, floor and bed', () async {
      await loadAndPickBed(floor: '3', bed: '2');

      expect(vm.selectedBed?.number, '2');
      expect(vm.selectedRoom?.number, '301');
      expect(vm.selectedFloor, '3');
    });

    test('an occupied bed cannot be chosen', () async {
      await vm.load('BUS1');
      vm.selectFloor('3');
      final room = vm.floor!.rooms.single;

      final ok = vm.selectBed(
        room,
        room.beds.firstWhere((b) => b.number == '1'),
      );

      expect(ok, isFalse);
      expect(vm.selectedBed, isNull);
    });

    test('changing floor clears the bed', () async {
      await loadAndPickBed();
      vm.selectFloor('2');
      expect(vm.selectedBed, isNull);
    });

    test('changing property resets the whole selection', () async {
      await loadAndPickBed();
      await vm.selectProperty(lake);

      expect(vm.property?.id, 'lake');
      expect(vm.selectedBed, isNull);
      expect(vm.floors.single.floor, '1');
    });

    test('picking the same bed again keeps it selected', () async {
      await loadAndPickBed();
      final room = vm.selectedRoom!;
      vm.selectBed(room, vm.selectedBed!);
      expect(vm.selectedBed?.number, '2');
    });
  });

  group('prefilling the lease from the property pricing', () {
    test('uses the room\'s sharing + AC price', () async {
      await vm.load('BUS1');
      vm.selectFloor('2'); // AC double
      vm.selectBed(vm.floor!.rooms.single, vm.floor!.rooms.single.beds.first);

      expect(vm.text(WizardField.rent), '8000');
      expect(vm.text(WizardField.deposit), '13000');
      expect(vm.text(WizardField.maintenance), '500');
    });

    test('falls back to the legacy single/double/triple price', () async {
      await vm.load('BUS1');
      vm.selectFloor('3'); // triple, no sharing entry for 3
      vm.selectBed(vm.floor!.rooms.single, vm.floor!.rooms.single.beds[1]);

      expect(vm.text(WizardField.rent), '5000');
    });

    test('never overwrites what the owner typed', () async {
      await vm.load('BUS1');
      vm.selectFloor('2');
      vm.selectBed(vm.floor!.rooms.single, vm.floor!.rooms.single.beds.first);
      vm.setText(WizardField.rent, '7777');

      vm.selectFloor('3');
      vm.selectBed(vm.floor!.rooms.single, vm.floor!.rooms.single.beds[1]);

      expect(vm.text(WizardField.rent), '7777');
    });

    test('follows the bed while the owner has not edited the rent', () async {
      await vm.load('BUS1');
      vm.selectFloor('2');
      vm.selectBed(vm.floor!.rooms.single, vm.floor!.rooms.single.beds.first);
      expect(vm.text(WizardField.rent), '8000');

      vm.selectFloor('3');
      vm.selectBed(vm.floor!.rooms.single, vm.floor!.rooms.single.beds[1]);
      expect(vm.text(WizardField.rent), '5000');
    });

    test('bumps prefillVersion so bound fields can refresh', () async {
      await vm.load('BUS1');
      final before = vm.prefillVersion;
      vm.selectFloor('3');
      vm.selectBed(vm.floor!.rooms.single, vm.floor!.rooms.single.beds[1]);
      expect(vm.prefillVersion, greaterThan(before));
    });
  });

  group('steps', () {
    test('starts on Property and cannot continue without a bed', () async {
      await vm.load('BUS1');
      expect(vm.step, 0);
      expect(vm.canContinue, isFalse);
      expect(vm.next(), isFalse);
      expect(vm.showErrors, isTrue);
      expect(vm.step, 0);
    });

    test('continues once a bed is picked and clears the error flag', () async {
      await loadAndPickBed();
      expect(vm.canContinue, isTrue);
      expect(vm.next(), isTrue);
      expect(vm.step, 1);
      expect(vm.showErrors, isFalse);
    });

    test('tenant info needs a name and a 10-digit phone', () async {
      await loadAndPickBed();
      vm.next();

      expect(vm.canContinue, isFalse);
      vm.setText(WizardField.fullName, 'Amit Patel');
      vm.setText(WizardField.phone, '98765');
      expect(vm.errors[WizardField.phone], isNotNull);

      vm.setText(WizardField.phone, '+91 98765 43210');
      expect(vm.errors, isEmpty);
      expect(vm.canContinue, isTrue);
    });

    test('an email, if given, must look like one', () async {
      await loadAndPickBed();
      vm.next();
      vm.setText(WizardField.fullName, 'Amit');
      vm.setText(WizardField.phone, '9876543210');

      vm.setText(WizardField.email, 'not-an-email');
      expect(vm.errors[WizardField.email], isNotNull);
      vm.setText(WizardField.email, 'amit@example.com');
      expect(vm.errors[WizardField.email], isNull);
    });

    test(
      'searching for an existing tenant replaces the manual fields',
      () async {
        await loadAndPickBed();
        vm.next();
        vm.setMode(TenantEntryMode.search);
        expect(vm.canContinue, isFalse);

        vm.selectTenant(
          TenantSearchResult(
            tenantId: 'TEN1',
            name: 'Karan',
            phone: '9000000103',
          ),
        );
        expect(vm.canContinue, isTrue);
      },
    );

    test('lease needs a move-in date, rent, deposit and duration', () async {
      await loadAndPickBed();
      vm.next();
      vm.setText(WizardField.fullName, 'Amit');
      vm.setText(WizardField.phone, '9876543210');
      vm.next();

      expect(vm.step, 2);
      expect(vm.canContinue, isFalse);
      vm.setMoveIn(DateTime(2026, 11, 3));
      expect(
        vm.canContinue,
        isTrue,
        reason: 'rent/deposit/duration are prefilled',
      );

      vm.setText(WizardField.rent, '');
      expect(vm.errors[WizardField.rent], isNotNull);
      vm.setText(WizardField.rent, '5000');
      vm.setText(WizardField.duration, '0');
      expect(vm.errors[WizardField.duration], isNotNull);
    });

    test('move-out must be after move-in', () async {
      await loadAndPickBed();
      vm.setMoveIn(DateTime(2026, 11, 10));
      vm.setMoveOut(DateTime(2026, 11, 1));

      expect(vm.errorsFor(2)[WizardField.moveOut], isNotNull);
    });

    test(
      'personal details need an ID number and address for new tenants',
      () async {
        await loadAndPickBed();
        expect(vm.errorsFor(4)[WizardField.idNumber], isNotNull);
        expect(vm.errorsFor(4)[WizardField.idAddress], isNotNull);

        vm.setText(WizardField.idNumber, 'XXXX 1234');
        vm.setText(WizardField.idAddress, '88 Civil Lines');
        expect(vm.errorsFor(4), isEmpty);
      },
    );

    test('an existing tenant skips the personal details checks', () async {
      await loadAndPickBed();
      vm.setMode(TenantEntryMode.search);
      expect(vm.errorsFor(4), isEmpty);
    });

    test('only finished steps can be revisited', () async {
      await loadAndPickBed();
      vm.next();
      expect(vm.goTo(0), isTrue);
      expect(vm.step, 0);
      expect(vm.goTo(3), isFalse);
      expect(vm.step, 0);
    });

    test('back never goes below the first step', () async {
      await vm.load('BUS1');
      vm.back();
      expect(vm.step, 0);
    });
  });

  group('bill', () {
    Future<void> toBill() async {
      await loadAndPickBed(floor: '3', bed: '2'); // rent 5000, deposit 13000
      vm.setMoveIn(DateTime(2026, 11, 20)); // 16th or later: half month
    }

    test('half a month for a late move-in plus the deposit', () async {
      await toBill();

      expect(vm.bill.proratedRent, 2500);
      expect(vm.bill.total, 2500 + 13000);
    });

    test('food excluded deducts before prorating', () async {
      await toBill();
      vm.setFoodIncluded(false);
      vm.setText(WizardField.foodDeduction, '1000');

      expect(vm.bill.adjustedMonthlyRent, 4000);
      expect(vm.bill.proratedRent, 2000);
    });

    test('the owner can override the prorated rent, and revert', () async {
      await toBill();
      vm.setText(WizardField.prorated, '3100');
      expect(vm.bill.proratedRent, 3100);

      vm.setText(WizardField.prorated, '');
      expect(vm.bill.proratedRent, 2500);
    });

    test('a bad prorated amount is flagged', () async {
      await toBill();
      vm.setText(WizardField.prorated, 'abc');
      expect(vm.errorsFor(3)[WizardField.prorated], isNotNull);
    });

    test('deposit can be deferred', () async {
      await toBill();
      vm.setDepositNow(false);
      expect(vm.bill.total, 2500);
    });

    test('uses the property flag for how maintenance is refunded', () async {
      await toBill();
      expect(vm.bill.maintenanceDeductedFromDeposit, isTrue);
    });
  });

  group('submitting', () {
    Future<void> fillEverything() async {
      await loadAndPickBed(floor: '3', bed: '2');
      vm.setText(WizardField.fullName, 'Amit Patel');
      vm.setText(WizardField.phone, '9876543210');
      vm.setText(WizardField.email, 'amit@example.com');
      vm.setMoveIn(DateTime(2026, 11, 3));
      vm.setText(WizardField.idNumber, 'XXXX 1234');
      vm.setText(WizardField.idAddress, '88 Civil Lines');
      vm.setFoodPreference('Veg');
    }

    test('sends a complete submission', () async {
      await fillEverything();
      final ok = await vm.submit();

      expect(ok, isTrue);
      expect(vm.submitted, isTrue);
      final s = submitted.single;
      expect(s.propertyId, 'sun');
      expect(s.propertyName, 'Sunrise Boys PG');
      expect(s.floor, '3');
      expect(s.roomNumber, '301');
      expect(s.bedNumber, '2');
      expect(s.bedIndex, 1);
      expect(s.monthlyRent, 5000);
      expect(s.deposit, 13000);
      expect(s.maintenance, 500);
      expect(s.maintenanceDeductedFromDeposit, isTrue);
      expect(
        s.proratedRent,
        5000,
        reason: 'move-in on the 3rd pays a full month',
      );
      expect(s.moveIn, DateTime(2026, 11, 3));
      expect(s.billingDay, 3, reason: 'defaults to the move-in day');
      expect(s.foodPreference, 'Veg');
      expect(s.tenantData['name'], 'Amit Patel');
      expect(s.tenantData['phone'], '9876543210');
      expect(s.tenantData['idNumber'], 'XXXX 1234');
      expect(s.mode, TenantEntryMode.manual);
    });

    test('a search-mode submission carries the existing tenant', () async {
      await loadAndPickBed();
      vm.setMode(TenantEntryMode.search);
      vm.selectTenant(
        TenantSearchResult(
          tenantId: 'TEN1',
          name: 'Karan',
          phone: '9000000103',
        ),
      );
      vm.setMoveIn(DateTime(2026, 11, 3));

      await vm.submit();

      expect(submitted.single.tenant?.tenantId, 'TEN1');
      expect(submitted.single.mode, TenantEntryMode.search);
    });

    test('jumps to the first incomplete step instead of submitting', () async {
      await loadAndPickBed();
      final ok = await vm.submit();

      expect(ok, isFalse);
      expect(submitted, isEmpty);
      expect(vm.step, 1);
      expect(vm.showErrors, isTrue);
    });

    test('shows the server\'s reason when the submission is refused', () async {
      await fillEverything();
      submitError = 'Room is already assigned to females.';

      final ok = await vm.submit();

      expect(ok, isFalse);
      expect(vm.submitError, 'Room is already assigned to females.');
      expect(vm.submitted, isFalse);
      expect(vm.submitting, isFalse);
    });

    test('cannot be submitted twice at once', () async {
      await fillEverything();
      final a = vm.submit();
      final b = vm.submit();
      await Future.wait([a, b]);

      expect(submitted, hasLength(1));
    });

    test('a successful submission clears the saved draft', () async {
      await fillEverything();
      await vm.saveDraft();
      expect(await drafts.read(), isNotNull);

      await vm.submit();

      expect(await drafts.read(), isNull);
    });

    test('a QR scan fills the form and switches to manual entry', () async {
      await vm.load('BUS1');
      vm.applyScannedTenant({
        'tenantId': 'TEN9',
        'name': 'Neha Verma',
        'phone': '9811122233',
        'email': 'neha@x.in',
        'gender': 'Female',
        'idType': 'aadhar card',
        'idNumber': 'XXXX 9999',
      });

      expect(vm.mode, TenantEntryMode.manual);
      expect(vm.text(WizardField.fullName), 'Neha Verma');
      expect(vm.gender, 'Female');
      expect(vm.idType, 'Aadhaar');
      expect(vm.text(WizardField.idNumber), 'XXXX 9999');
    });
  });

  group('drafts', () {
    test('saves and restores fields, step and bed', () async {
      await loadAndPickBed(floor: '3', bed: '2');
      vm.setText(WizardField.fullName, 'Amit Patel');
      vm.setText(WizardField.phone, '9876543210');
      vm.setMoveIn(DateTime(2026, 11, 3));
      vm.next();
      await vm.saveDraft();

      final fresh = AddTenantWizardViewModel(
        assignments: data,
        submitter: (_) async => null,
        drafts: drafts,
      );
      addTearDown(fresh.dispose);
      await fresh.load('BUS1');
      expect(fresh.draftAvailable, isTrue);

      await fresh.restoreDraft();

      expect(fresh.property?.id, 'sun');
      expect(fresh.selectedBed?.number, '2');
      expect(fresh.selectedRoom?.number, '301');
      expect(fresh.text(WizardField.fullName), 'Amit Patel');
      expect(fresh.moveIn, DateTime(2026, 11, 3));
      expect(fresh.step, 1);
    });

    test('drops a bed that has been taken since the draft was saved', () async {
      await loadAndPickBed(floor: '3', bed: '2');
      await vm.saveDraft();

      data.occupied['sun'] = {
        '301': {'1', '2'},
      };
      final fresh = AddTenantWizardViewModel(
        assignments: data,
        submitter: (_) async => null,
        drafts: drafts,
      );
      addTearDown(fresh.dispose);
      await fresh.load('BUS1');
      await fresh.restoreDraft();

      expect(fresh.selectedBed, isNull);
      expect(fresh.property?.id, 'sun');
    });

    test('no draft means nothing to resume', () async {
      await vm.load('BUS1');
      expect(vm.draftAvailable, isFalse);
    });

    test('discarding removes the draft', () async {
      await loadAndPickBed();
      await vm.saveDraft();
      await vm.discardDraft();
      expect(await drafts.read(), isNull);
    });

    test('a corrupt draft is ignored, not a crash', () async {
      await drafts.write({'step': 'banana', 'fields': 12});
      await vm.load('BUS1');
      await vm.restoreDraft();
      expect(vm.step, 0);
    });
  });
}
