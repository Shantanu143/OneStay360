import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/data/models.dart';
import 'package:tenant/presentation/pinboard/pin_form.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBackend backend;
  late PinForm form;

  setUp(() {
    backend = FakeBackend();
    form = PinForm(source: backend, account: testAccount(), propertyId: 'P1');
  });

  test('needs something to say, within 200 characters', () async {
    expect(await form.submit(), isFalse);
    expect(form.error, 'Write something first.');
    form.setContent('x' * 201);
    expect(await form.submit(), isFalse);
    expect(form.error, 'Keep it under 200 characters.');
  });

  test('pins it for the property, as the tenant', () async {
    form.setCategory(PinCategory.sports);
    form.setContent(' Badminton at 7? ');
    expect(await form.submit(), isTrue);
    final d = backend.lastPin!;
    expect(d.propertyId, 'P1');
    expect(d.authorId, 'u1');
    expect(d.authorName, 'Asha Rao');
    expect(d.authorPhone, '+919811100001');
    expect(d.category, PinCategory.sports);
    expect(d.content, 'Badminton at 7?');
  });

  test('counts characters left', () {
    form.setContent('hello');
    expect(form.remaining, 195);
  });
}
