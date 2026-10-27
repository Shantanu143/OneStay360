import 'package:business/presentation/common/phone_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a ten digit mobile becomes an Indian number', () {
    expect(normalizePhoneNumber('98111 00001'), '+919811100001');
    expect(normalizePhoneNumber('09811100001'), '+919811100001');
    expect(normalizePhoneNumber('+91 98111-00001'), '+919811100001');
    expect(normalizePhoneNumber('919811100001'), '+919811100001');
  });

  test('another country is kept', () {
    expect(normalizePhoneNumber('+1 (415) 555-0123'), '+14155550123');
  });

  test('anything else is refused', () {
    for (final bad in ['', '123', 'abc', '+12', '98111000011']) {
      expect(normalizePhoneNumber(bad), isNull, reason: bad);
    }
  });

  test('a number is shown with spaces', () {
    expect(formatPhoneForDisplay('+919811100001'), '+91 98111 00001');
    expect(formatPhoneForDisplay('+14155550123'), '+14155550123');
  });

  test('a number can be masked', () {
    expect(maskPhone('+919811100001'), '+91 98••• •0001');
    expect(maskPhone('+14155550123'), '••••••••0123');
  });

  test('two numbers match when they are the same number written differently', () {
    expect(phonesMatch('+919811100001', '98111 00001'), isTrue);
    expect(phonesMatch('09811100001', '+91 98111-00001'), isTrue);
    expect(phonesMatch('+919811100001', '+919811100002'), isFalse);
  });

  test('a missing number never matches', () {
    expect(phonesMatch(null, '+919811100001'), isFalse);
    expect(phonesMatch('', ''), isFalse);
    expect(phonesMatch(null, null), isFalse);
  });
}
