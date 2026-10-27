import 'package:business/app/refresh_signals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late RefreshSignals signals;

  setUp(() => signals = RefreshSignals());
  tearDown(() => signals.dispose());

  group('changed', () {
    test('bumps only the topics named', () {
      signals.changed(payments: true);

      expect(signals.payments.value, 1);
      expect(signals.tenants.value, 0);
      expect(signals.properties.value, 0);
    });

    test('tells "anything changed" listeners once, however many topics moved', () {
      var heard = 0;
      signals.anyChanged.addListener(() => heard++);

      signals.changed(payments: true, tenants: true, properties: true);

      expect(heard, 1);
      expect(signals.payments.value, 1);
      expect(signals.tenants.value, 1);
      expect(signals.properties.value, 1);
    });

    test('naming nothing tells nobody', () {
      var heard = 0;
      signals.anyChanged.addListener(() => heard++);

      signals.changed();

      expect(heard, 0);
    });

    test('the single-topic helpers still work', () {
      signals.paymentsChanged();
      signals.tenantsChanged();
      signals.propertiesChanged();

      expect(signals.anyChanged.value, 3);
    });
  });

  group('raise', () {
    testWidgets('reaches the signals in scope', (tester) async {
      await tester.pumpWidget(
        Provider<RefreshSignals>.value(
          value: signals,
          child: Builder(builder: (context) {
            RefreshSignals.raise(context, tenants: true);
            return const SizedBox();
          }),
        ),
      );

      expect(signals.tenants.value, 1);
    });

    testWidgets('does nothing, and does not throw, when there are none', (tester) async {
      await tester.pumpWidget(
        Builder(builder: (context) {
          RefreshSignals.raise(context, payments: true);
          return const SizedBox();
        }),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
