import 'package:business/app/refresh_signals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each topic notifies only its own listeners', () {
    final signals = RefreshSignals();
    var properties = 0;
    var tenants = 0;
    signals.properties.addListener(() => properties++);
    signals.tenants.addListener(() => tenants++);

    signals.propertiesChanged();
    signals.propertiesChanged();
    signals.tenantsChanged();

    expect(properties, 2);
    expect(tenants, 1);
  });

  test('exposes a growing version so late listeners can compare', () {
    final signals = RefreshSignals();
    expect(signals.properties.value, 0);
    signals.propertiesChanged();
    expect(signals.properties.value, 1);
  });

  test('anyChanged fires for every topic', () {
    final signals = RefreshSignals();
    var any = 0;
    signals.anyChanged.addListener(() => any++);

    signals.propertiesChanged();
    signals.tenantsChanged();
    signals.paymentsChanged();

    expect(any, 3);
  });
}
