import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/data/models.dart';
import 'package:tenant/presentation/maintenance/maintenance_form.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBackend backend;
  late MaintenanceForm form;

  setUp(() {
    backend = FakeBackend();
    form = MaintenanceForm(
      source: backend,
      account: testAccount(),
      stay: testStay,
    );
  });

  test('needs a category and a short title', () async {
    expect(await form.submit(), isFalse);
    expect(form.categoryError, 'Pick what it is about.');
    expect(form.titleError, 'Say what is wrong in a few words.');

    form.setTitle('x' * 121);
    expect(await form.submit(), isFalse);
    expect(form.titleError, 'Keep it under 120 characters.');
    expect(backend.lastMaintenance, isNull);
  });

  test('raises it for the current stay', () async {
    form.setCategory(MaintenanceCategory.plumbing);
    form.setTitle('  Tap leaking ');
    form.setDescription(' Bathroom, since morning ');
    form.setUrgent(true);
    expect(await form.submit(), isTrue);

    final d = backend.lastMaintenance!;
    expect(d.uid, 'u1');
    expect(d.tenantId, 'TEN1');
    expect(d.tenantName, 'Asha Rao');
    expect(d.stay.propertyId, 'P1');
    expect(d.category, MaintenanceCategory.plumbing);
    expect(d.title, 'Tap leaking');
    expect(d.description, 'Bathroom, since morning');
    expect(d.urgent, isTrue);
  });

  test('suggests a title from the category', () {
    form.setCategory(MaintenanceCategory.internet);
    expect(form.suggestions, contains('Wi-Fi not working'));
  });

  test('a failure is shown', () async {
    form.setCategory(MaintenanceCategory.other);
    form.setTitle('Door');
    backend.failure = Exception('denied');
    expect(await form.submit(), isFalse);
    expect(form.error, "Couldn't send your request. Try again.");
  });
}
