import 'package:provider/provider.dart';
import 'package:business/app/refresh_signals.dart';
import 'package:business/presentation/design/theme.dart';
import 'package:business/presentation/tenant_detail/tenant_detail_actions.dart';
import 'package:business/presentation/tenant_detail/tenant_detail_models.dart';
import 'package:business/presentation/tenant_detail/tenant_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/tenant_fakes.dart';

class FakeTenantActions implements TenantDetailActions {
  final calls = <String>[];
  Uri? opened;
  bool recorded = false;

  @override
  Future<void> call(BuildContext context, String phone) async => calls.add('call:$phone');

  @override
  Future<void> openUrl(BuildContext context, Uri uri) async {
    opened = uri;
    calls.add('url');
  }

  @override
  Future<void> copy(BuildContext context, String text, {String? message}) async =>
      calls.add('copy:$text');

  @override
  Future<bool> recordPayment(BuildContext context, TenantProfile tenant) async {
    calls.add('record:${tenant.id}');
    return recorded;
  }
}

void main() {
  late RefreshSignals signals;
  setUp(() => signals = RefreshSignals());
  tearDown(() => signals.dispose());

  late FakeTenantSource source;
  late FakeTenantActions actions;
  Object? popped = 'unset';

  setUp(() {
    source = FakeTenantSource();
    actions = FakeTenantActions();
    popped = 'unset';
  });

  tearDown(() => source.controller.close());

  Future<void> emitPayments(WidgetTester tester, List<TenantPayment> list) async {
    source.controller.add(list);
    await tester.pumpAndSettle();
  }

  /// Opens the screen on top of a launcher so pop results can be observed.
  Future<void> open(
    WidgetTester tester, {
    Map<String, dynamic>? tenant,
    bool canRemove = false,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<RefreshSignals>.value(
        value: signals,
        child: MaterialApp(
        theme: BizTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => TenantDetailScreen(
                        tenant: tenant ?? tenantMap(),
                        propertyName: 'Sunrise Boys PG',
                        businessId: 'BUS1',
                        canRemove: canRemove,
                        source: source,
                        actions: actions,
                      ),
                    ),
                  );
                },
                child: const Text('launch'),
              ),
            ),
          ),
        ),
      ),
      ),
    );
    await tester.tap(find.text('launch'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    if (settle) await emitPayments(tester, const []);
  }

  group('profile', () {
    testWidgets('shows who they are, where they live and what they pay', (tester) async {
      await open(tester);

      expect(find.text('Rohan Mehta'), findsOneWidget);
      expect(find.text('Sunrise Boys PG'), findsOneWidget);
      expect(find.text('TEN0000001'), findsOneWidget);
      expect(find.text('Room 101 · Bed 1'), findsOneWidget);
      expect(find.text('₹9,500'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('+919000000101'), findsOneWidget);
      expect(find.text('rohan@example.test'), findsOneWidget);
      expect(find.text('30 Mar 2026'), findsOneWidget);
    });

    testWidgets('missing details read as "Not provided", not as data', (tester) async {
      await open(tester, tenant: tenantMap(phone: 'Not provided', email: null, rent: 'N/A'));

      expect(find.text('Not provided'), findsNWidgets(2));
      expect(find.text('Rent not set'), findsOneWidget);
    });
  });

  group('actions', () {
    testWidgets('Call dials the tenant', (tester) async {
      await open(tester);

      await tester.tap(find.text('Call'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['call:+919000000101']);
    });

    testWidgets('Message opens a WhatsApp chat with the right number', (tester) async {
      await open(tester);

      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();

      expect(actions.opened?.host, 'wa.me');
      expect(actions.opened?.path, '/919000000101');
    });

    testWidgets('a local 10-digit number gets the India code', (tester) async {
      await open(tester, tenant: tenantMap(phone: '9811122233'));

      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();

      expect(actions.opened?.path, '/919811122233');
    });

    testWidgets('Call and Message do nothing without a phone number', (tester) async {
      await open(tester, tenant: tenantMap(phone: null));

      await tester.tap(find.text('Call'));
      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();

      expect(actions.calls, isEmpty);
    });

    testWidgets('the phone number can be copied', (tester) async {
      await open(tester);

      await tester.tap(find.byTooltip('Copy phone number'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['copy:+919000000101']);
    });

    testWidgets('Record payment opens the payment form', (tester) async {
      await open(tester);

      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['record:TEN0000001']);
    });
  });

  group('payment history', () {
    testWidgets('shows placeholders while it loads', (tester) async {
      await open(tester, settle: false);

      expect(find.text('No payments yet'), findsNothing);
      expect(source.listens, 1);
    });

    testWidgets('lists each payment with its status', (tester) async {
      await open(tester, settle: false);
      await emitPayments(tester, [
        TenantPayment.fromMap('a', {
          'month': 'October 2026',
          'amount': 9500,
          'method': 'UPI',
          'status': 'Paid',
          'date': DateTime(2026, 10, 3),
        }),
        TenantPayment.fromMap('b', {
          'month': 'September 2026',
          'amount': 9500,
          'method': 'Cash',
          'status': 'rejected',
          'rejectionReason': 'Amount does not match',
          'date': DateTime(2026, 9, 2),
        }),
      ]);

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('UPI · 3 Oct 2026'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Reason: Amount does not match'), findsOneWidget);
    });

    testWidgets('says so when there are none', (tester) async {
      await open(tester);

      expect(find.text('No payments yet'), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      await open(tester, settle: false);
      source.controller.addError(Exception('denied'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load payments."), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(source.listens, 2);
    });
  });

  group('edit details', () {
    Future<void> openEditor(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Edit details'));
      await tester.tap(find.text('Edit details'));
      await tester.pumpAndSettle();
    }

    testWidgets('starts with the current details', (tester) async {
      await open(tester);
      await openEditor(tester);

      expect(find.widgetWithText(TextFormField, 'Rohan Mehta'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '+919000000101'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'rohan@example.test'), findsOneWidget);
    });

    testWidgets('saves new details and shows them straight away', (tester) async {
      await open(tester);
      await openEditor(tester);

      await tester.enterText(find.byKey(const Key('edit-name')), 'Rohan M Mehta');
      await tester.enterText(find.byKey(const Key('edit-phone')), '9811122233');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(source.updates.single['name'], 'Rohan M Mehta');
      expect(source.updates.single['phone'], '9811122233');
      expect(find.text('Rohan M Mehta'), findsOneWidget);
      expect(find.text('9811122233'), findsOneWidget);
      expect(find.text('Save changes'), findsNothing, reason: 'sheet closed');
    });

    testWidgets('saving details tells the app a tenant changed', (tester) async {
      await open(tester);
      await openEditor(tester);

      await tester.enterText(find.byKey(const Key('edit-name')), 'Rohan M Mehta');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(signals.tenants.value, 1);
      expect(signals.properties.value, 0);
      expect(signals.anyChanged.value, 1);
    });

    testWidgets('keeps the sheet open and says what is wrong', (tester) async {
      await open(tester);
      await openEditor(tester);

      await tester.enterText(find.byKey(const Key('edit-phone')), '123');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid phone number.'), findsOneWidget);
      expect(source.updates, isEmpty);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('keeps the sheet open when the save fails', (tester) async {
      source.updateFailure = Exception('denied');
      await open(tester);
      await openEditor(tester);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't save the changes. Try again."), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    });
  });

  group('remove tenant', () {
    Future<void> tapRemove(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Remove tenant'));
      await tester.tap(find.text('Remove tenant'));
      await tester.pumpAndSettle();
    }

    testWidgets('is for people allowed to remove tenants only', (tester) async {
      await open(tester);

      expect(find.text('Remove tenant'), findsNothing);
    });

    testWidgets('asks first, then frees the bed and goes back', (tester) async {
      await open(tester, canRemove: true);
      await tapRemove(tester);

      expect(find.textContaining('free up the bed'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(source.vacated.single['bedId'], '1');
      expect(popped, true, reason: 'the property screen reloads on true');
      expect(find.text('launch'), findsOneWidget);
    });

    testWidgets('removing a tenant tells the app a bed is free and rent is no longer due', (tester) async {
      await open(tester, canRemove: true);
      await tapRemove(tester);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(signals.tenants.value, 1);
      expect(signals.properties.value, 1);
      expect(signals.payments.value, 1);
      expect(signals.anyChanged.value, 1);
    });

    testWidgets('a failed removal tells nobody', (tester) async {
      source.vacateFailure = Exception('boom');
      await open(tester, canRemove: true);
      await tapRemove(tester);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(signals.anyChanged.value, 0);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await open(tester, canRemove: true);
      await tapRemove(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(source.vacated, isEmpty);
      expect(find.text('Rohan Mehta'), findsOneWidget);
    });

    testWidgets('stays put and explains when it fails', (tester) async {
      source.vacateFailure = Exception('boom');
      await open(tester, canRemove: true);
      await tapRemove(tester);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't remove this tenant. Try again."), findsOneWidget);
      expect(find.text('Rohan Mehta'), findsOneWidget);
      expect(popped, 'unset');
    });

    testWidgets('a tenant who already left has nothing to remove', (tester) async {
      await open(tester, canRemove: true, tenant: tenantMap(status: 'inactive'));

      expect(find.text('Remove tenant'), findsNothing);
      expect(find.text('Inactive'), findsOneWidget);
    });
  });
}
