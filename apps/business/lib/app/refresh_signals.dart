// lib/app/refresh_signals.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Tells screens that stay alive in the shell (Home, Properties...) that data
/// changed somewhere else (a property was added, a payment confirmed), so
/// they reload instead of showing stale numbers.
///
/// Each topic is a version counter: bump it with `xChanged()` after a write.
class RefreshSignals {
  final ValueNotifier<int> properties = ValueNotifier(0);
  final ValueNotifier<int> tenants = ValueNotifier(0);
  final ValueNotifier<int> payments = ValueNotifier(0);
  final ValueNotifier<int> _any = ValueNotifier(0);

  /// Fires whenever any topic changes (Home refreshes on this).
  ValueListenable<int> get anyChanged => _any;

  /// Several topics changed at once (a confirmed enrolment adds a tenant,
  /// fills a bed and takes money). Listeners of [anyChanged] hear it once.
  void changed({bool properties = false, bool tenants = false, bool payments = false}) {
    if (!properties && !tenants && !payments) return;
    if (properties) this.properties.value++;
    if (tenants) this.tenants.value++;
    if (payments) this.payments.value++;
    _any.value++;
  }

  /// [changed] on the signals in scope. Screens built on their own (tests)
  /// have none, and then this does nothing.
  static void raise(
    BuildContext context, {
    bool properties = false,
    bool tenants = false,
    bool payments = false,
  }) {
    try {
      Provider.of<RefreshSignals>(context, listen: false)
          .changed(properties: properties, tenants: tenants, payments: payments);
    } on ProviderNotFoundException {
      // No signals in scope.
    }
  }

  void propertiesChanged() => _bump(properties);
  void tenantsChanged() => _bump(tenants);
  void paymentsChanged() => _bump(payments);

  void _bump(ValueNotifier<int> topic) {
    topic.value++;
    _any.value++;
  }

  void dispose() {
    properties.dispose();
    tenants.dispose();
    payments.dispose();
    _any.dispose();
  }
}
