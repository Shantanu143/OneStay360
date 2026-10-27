// lib/presentation/common/format.dart
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:intl/intl.dart';

final NumberFormat _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// ₹4,82,500 style (Indian digit grouping, no decimals).
String formatInr(num value) => _inr.format(value.round());

String firstNameOf(String fullName) {
  final trimmed = fullName.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.split(RegExp(r'\s+')).first;
}

/// "Asha Rao" -> "AR", "Asha" -> "A".
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  final first = parts.first.characters.first;
  final last = parts.length > 1 ? parts.last.characters.first : '';
  return (first + last).toUpperCase();
}

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'Good morning';
  if (h >= 12 && h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "Just now", "5m ago", "3h ago", "2d ago", then a date ("28 Mar 2026").
String agoLabel(DateTime at, DateTime now) {
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatDay(at);
}

/// "28 Mar 2026".
String formatDay(DateTime d) => DateFormat('d MMM y').format(d);

/// "28 Mar".
String formatShortDay(DateTime d) => DateFormat('d MMM').format(d);

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Due today", "Due in 5 days", "3 days overdue".
String dueLabel(DateTime due, DateTime now) {
  final days = _dateOnly(due).difference(_dateOnly(now)).inDays;
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  if (days > 1) return 'Due in $days days';
  final late = -days;
  return late == 1 ? '1 day overdue' : '$late days overdue';
}

/// 1st, 2nd, 3rd, 4th... 11th, 12th, 13th, 21st.
String ordinalDay(int day) {
  if (day % 100 >= 11 && day % 100 <= 13) return '${day}th';
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}

/// "March 2026", the label rent invoices and payments use for a month.
String monthLabel(DateTime d) => DateFormat('MMMM yyyy').format(d);
