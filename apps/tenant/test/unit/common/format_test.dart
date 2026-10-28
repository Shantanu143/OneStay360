import 'package:flutter_test/flutter_test.dart';
import 'package:tenant/presentation/common/format.dart';
import 'package:tenant/presentation/common/phone_format.dart';

void main() {
  group('formatInr', () {
    test('uses Indian grouping and no decimals', () {
      expect(formatInr(482500), '₹4,82,500');
      expect(formatInr(9000.4), '₹9,000');
      expect(formatInr(0), '₹0');
    });
  });

  group('names', () {
    test('first name and initials', () {
      expect(firstNameOf('  Asha  Rao '), 'Asha');
      expect(initialsOf('Asha Rao'), 'AR');
      expect(initialsOf('asha'), 'A');
      expect(initialsOf(''), '');
    });
  });

  group('greeting', () {
    test('follows the time of day', () {
      expect(greetingFor(DateTime(2026, 1, 1, 7)), 'Good morning');
      expect(greetingFor(DateTime(2026, 1, 1, 13)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 1, 1, 19)), 'Good evening');
      expect(greetingFor(DateTime(2026, 1, 1, 2)), 'Good evening');
    });
  });

  group('agoLabel', () {
    final now = DateTime(2026, 3, 28, 12);
    test('counts up, then shows the date', () {
      expect(agoLabel(now, now), 'Just now');
      expect(agoLabel(now.subtract(const Duration(minutes: 5)), now), '5m ago');
      expect(agoLabel(now.subtract(const Duration(hours: 3)), now), '3h ago');
      expect(agoLabel(now.subtract(const Duration(days: 2)), now), '2d ago');
      expect(agoLabel(DateTime(2026, 3, 1), now), '1 Mar 2026');
    });
  });

  group('dueLabel', () {
    final now = DateTime(2026, 3, 10, 9);
    test('says when rent is due relative to today', () {
      expect(dueLabel(DateTime(2026, 3, 10), now), 'Due today');
      expect(dueLabel(DateTime(2026, 3, 11), now), 'Due tomorrow');
      expect(dueLabel(DateTime(2026, 3, 15), now), 'Due in 5 days');
      expect(dueLabel(DateTime(2026, 3, 9), now), '1 day overdue');
      expect(dueLabel(DateTime(2026, 3, 1), now), '9 days overdue');
    });
  });

  group('ordinalDay', () {
    test('adds the right suffix', () {
      expect(ordinalDay(1), '1st');
      expect(ordinalDay(2), '2nd');
      expect(ordinalDay(3), '3rd');
      expect(ordinalDay(4), '4th');
      expect(ordinalDay(11), '11th');
      expect(ordinalDay(12), '12th');
      expect(ordinalDay(13), '13th');
      expect(ordinalDay(21), '21st');
      expect(ordinalDay(22), '22nd');
    });
  });

  group('phone numbers', () {
    test('normalizes Indian numbers', () {
      expect(normalizePhoneNumber('98111 00001'), '+919811100001');
      expect(normalizePhoneNumber('09811100001'), '+919811100001');
      expect(normalizePhoneNumber('+91 98111-00001'), '+919811100001');
      expect(normalizePhoneNumber('12345'), isNull);
      expect(normalizePhoneNumber(''), isNull);
    });

    test('masks and formats', () {
      expect(maskPhone('+919811100001'), '+91 98••• •0001');
      expect(formatPhoneForDisplay('+919811100001'), '+91 98111 00001');
    });

    test('builds a WhatsApp number with the country code', () {
      expect(whatsAppNumber('98111 00001'), '919811100001');
      expect(whatsAppNumber('+44 7700 900123'), '447700900123');
      expect(whatsAppNumber(''), isNull);
    });
  });
}
