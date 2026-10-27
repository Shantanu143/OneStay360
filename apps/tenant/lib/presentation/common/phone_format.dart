// lib/presentation/common/phone_format.dart

/// "98111 00001", "+91 98111 00001" or "09811100001" as `+919811100001`;
/// null when it is not a phone number. Other countries are kept as typed.
String? normalizePhoneNumber(String input) {
  final text = input.replaceAll(RegExp(r'[\s\-().]'), '');
  if (text.isEmpty) return null;
  if (text.startsWith('+')) {
    final digits = text.substring(1);
    if (!RegExp(r'^\d{8,15}$').hasMatch(digits)) return null;
    return '+$digits';
  }
  if (!RegExp(r'^\d+$').hasMatch(text)) return null;
  if (text.length == 10) return '+91$text';
  if (text.length == 11 && text.startsWith('0')) return '+91${text.substring(1)}';
  if (text.length == 12 && text.startsWith('91')) return '+$text';
  return null;
}

/// `+91 98111 00001`, for showing a number to a person.
String formatPhoneForDisplay(String e164) {
  final m = RegExp(r'^\+91(\d{5})(\d{5})$').firstMatch(e164);
  return m == null ? e164 : '+91 ${m.group(1)} ${m.group(2)}';
}

/// `+91 98••• ••009`: enough to recognise, not to read out.
String maskPhone(String e164) {
  final m = RegExp(r'^\+91(\d{2})\d{4}(\d{4})$').firstMatch(e164);
  if (m != null) return '+91 ${m.group(1)}••• •${m.group(2)}';
  if (e164.length <= 4) return e164;
  return '${'•' * (e164.length - 4)}${e164.substring(e164.length - 4)}';
}

/// The last ten digits of a number, however it was written.
String _lastTen(String? phone) {
  final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}

/// True when both numbers are present and are the same number.
bool phonesMatch(String? a, String? b) {
  final x = _lastTen(a);
  return x.isNotEmpty && x == _lastTen(b);
}

/// Digits for a wa.me link: an Indian number gets its 91 prefix.
String? whatsAppNumber(String? phone) {
  final normalized = normalizePhoneNumber(phone ?? '');
  if (normalized != null) return normalized.substring(1);
  final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  return digits.length >= 8 ? digits : null;
}
