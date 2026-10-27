import 'package:business/presentation/profile/billing_overview_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:models/business/property/property_model.dart';

import '../../support/property_fixtures.dart';
import '../view_models/business_dashboard_viewmodel_test.mocks.dart';

Property prop(
  String id,
  String name,
  String billing, {
  String status = 'active',
  int billed = 10,
  int price = 30,
  DateTime? next,
}) =>
    makeProperty(id: id, name: name, status: status).copyWith(
      billingStatus: billing,
      billedBedCount: billed,
      pricePerBed: price,
      nextBillingDate: next ?? DateTime(2026, 11, 14),
    );

void main() {
  late MockPropertyRepository repo;
  late BillingOverviewViewModel vm;

  setUp(() {
    repo = MockPropertyRepository();
    vm = BillingOverviewViewModel(repository: repo, businessId: 'BUS1');
  });

  tearDown(() => vm.dispose());

  test('prices each property by the beds it is billed for', () async {
    when(repo.getPropertiesByBusiness('BUS1')).thenAnswer((_) async => [
          prop('a', 'Sunrise', 'paid', billed: 19, price: 30),
        ]);

    await vm.load();

    expect(vm.loading, isFalse);
    expect(vm.rows.single.monthly, 570);
    expect(vm.rows.single.status.label, 'Billing active');
  });

  test('puts what needs paying first, then A to Z', () async {
    when(repo.getPropertiesByBusiness('BUS1')).thenAnswer((_) async => [
          prop('a', 'Zen', 'paid'),
          prop('b', 'Alpha', 'paid'),
          prop('c', 'Lotus', 'due'),
          prop('d', 'Green', 'payment_due', status: 'draft'),
        ]);

    await vm.load();

    expect(vm.rows.map((r) => r.property.name), ['Green', 'Lotus', 'Alpha', 'Zen']);
  });

  test('adds up the monthly cost of properties that are billing', () async {
    when(repo.getPropertiesByBusiness('BUS1')).thenAnswer((_) async => [
          prop('a', 'A', 'paid', billed: 10, price: 30),
          prop('b', 'B', 'due', billed: 20, price: 30),
          prop('c', 'C', 'payment_due', status: 'draft', billed: 5, price: 30),
        ]);

    await vm.load();

    expect(vm.monthlyTotal, 900, reason: 'the draft one is not billing yet');
    expect(vm.needAttention, 2, reason: 'one due, one waiting for activation');
  });

  test('falls back to total beds when no billed count is stored', () async {
    when(repo.getPropertiesByBusiness('BUS1')).thenAnswer((_) async => [
          prop('a', 'A', 'paid', billed: 0, price: 30).copyWith(totalBeds: 12),
        ]);

    await vm.load();

    expect(vm.rows.single.monthly, 360);
  });

  test('says so when there are no properties', () async {
    when(repo.getPropertiesByBusiness('BUS1')).thenAnswer((_) async => []);

    await vm.load();

    expect(vm.rows, isEmpty);
    expect(vm.error, isNull);
  });

  test('reports a failure and can retry', () async {
    when(repo.getPropertiesByBusiness('BUS1')).thenThrow(Exception('denied'));
    await vm.load();
    expect(vm.error, "Couldn't load your properties.");

    when(repo.getPropertiesByBusiness('BUS1')).thenAnswer((_) async => []);
    await vm.load();
    expect(vm.error, isNull);
  });
}
