import 'package:flutter_test/flutter_test.dart';

import 'package:models/models.dart';

void main() {
  test('public barrel exports property pricing models', () {
    final pricing = PropertyPricing(
      single: 8000,
      double: 6000,
      triple: 5000,
      securityDeposit: 10000,
      oneTimeMaintenance: 1500,
      maintenanceDeductedFromDeposit: false,
    );

    expect(pricing.toMap()['single'], 8000);
    expect(pricing.securityDeposit, 10000);
  });
}
