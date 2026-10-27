import 'package:business/presentation/team/invite_form_viewmodel.dart';
import 'package:business/presentation/team/team_models.dart';
import 'package:flutter_test/flutter_test.dart';

const properties = [
  TeamProperty(id: 'P1', name: 'Sunrise Boys PG'),
  TeamProperty(id: 'P2', name: 'Lotus Ladies Hostel'),
];

void main() {
  group('normalizeInvitePhone', () {
    test('turns a ten digit mobile into an Indian number', () {
      expect(normalizeInvitePhone('9811100001'), '+919811100001');
      expect(normalizeInvitePhone('98111 00001'), '+919811100001');
      expect(normalizeInvitePhone('98111-00001'), '+919811100001');
    });

    test('accepts the country code and a leading zero', () {
      expect(normalizeInvitePhone('+91 98111 00001'), '+919811100001');
      expect(normalizeInvitePhone('919811100001'), '+919811100001');
      expect(normalizeInvitePhone('09811100001'), '+919811100001');
    });

    test('keeps another country\'s number as typed', () {
      expect(normalizeInvitePhone('+14155550123'), '+14155550123');
      expect(normalizeInvitePhone('+44 7911 123456'), '+447911123456');
    });

    test('refuses anything that is not a phone number', () {
      expect(normalizeInvitePhone(''), isNull);
      expect(normalizeInvitePhone('12345'), isNull);
      expect(normalizeInvitePhone('abcdefghij'), isNull);
      expect(normalizeInvitePhone('+12'), isNull);
      expect(normalizeInvitePhone('98111000011'), isNull, reason: 'eleven digits and no leading 0');
    });
  });

  group('InviteFormViewModel', () {
    late InviteFormViewModel form;

    setUp(() => form = InviteFormViewModel(properties: properties));
    tearDown(() => form.dispose());

    test('starts as a manager with nothing chosen and no errors', () {
      expect(form.role, 'manager');
      expect(form.selected, isEmpty);
      expect(form.phoneError, isNull);
      expect(form.propertiesError, isNull);
    });

    test('asks for a phone number, a valid one, and a property, only after a try', () {
      expect(form.validate(), isFalse);

      expect(form.phoneError, 'Enter their mobile number.');
      expect(form.propertiesError, 'Pick at least one property.');
    });

    test('says what is wrong with a bad number or email', () {
      form.setPhone('12345');
      form.setEmail('not-an-email');
      form.toggleProperty('P1');

      expect(form.validate(), isFalse);

      expect(form.phoneError, 'Enter a 10-digit mobile number.');
      expect(form.emailError, 'Enter a valid email, or leave it blank.');
    });

    test('is valid with a number and a property; the email is optional', () {
      form.setPhone('98111 00001');
      form.toggleProperty('P1');

      expect(form.validate(), isTrue);
      final r = form.build();
      expect(r.phone, '+919811100001');
      expect(r.email, isNull);
      expect(r.role, 'manager');
      expect(r.propertyIds, ['P1']);
    });

    test('tidies the email', () {
      form.setPhone('9811100001');
      form.setEmail('  New.Manager@Example.test ');
      form.toggleProperty('P2');

      expect(form.validate(), isTrue);
      expect(form.build().email, 'new.manager@example.test');
    });

    test('toggles properties on and off and keeps them in the order the business lists them', () {
      form.setPhone('9811100001');
      form.toggleProperty('P2');
      form.toggleProperty('P1');
      expect(form.selected, {'P1', 'P2'});
      expect(form.build().propertyIds, ['P1', 'P2']);

      form.toggleProperty('P1');
      expect(form.selected, {'P2'});
    });

    test('can pick every property at once, then none', () {
      form.toggleAll();
      expect(form.selected, {'P1', 'P2'});
      expect(form.allSelected, isTrue);

      form.toggleAll();
      expect(form.selected, isEmpty);
    });

    test('switches role', () {
      form.setRole('staff');

      expect(form.role, 'staff');
      form.setPhone('9811100001');
      form.toggleProperty('P1');
      form.validate();
      expect(form.build().role, 'staff');
    });

    test('ignores a role that is not offered', () {
      form.setRole('owner');

      expect(form.role, 'manager');
    });

    test('clears an error as soon as it is fixed', () {
      form.validate();
      expect(form.phoneError, isNotNull);

      form.setPhone('9811100001');

      expect(form.phoneError, isNull);
    });

    test('tells listeners when something changes', () {
      var heard = 0;
      form.addListener(() => heard++);

      form.setRole('staff');
      form.toggleProperty('P1');
      form.setPhone('9');

      expect(heard, 3);
    });

    test('with no properties to pick from, says to add one first', () {
      final empty = InviteFormViewModel(properties: const []);
      addTearDown(empty.dispose);
      empty.setPhone('9811100001');

      expect(empty.validate(), isFalse);
      expect(empty.propertiesError, 'Add a property first, then invite your team.');
    });
  });
}
