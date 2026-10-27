// lib/presentation/views/home/home_format.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final NumberFormat _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// ₹4,82,500 style (Indian digit grouping, no decimals).
String formatInr(num value) => _inr.format(value.round());

/// "92.8%" — one decimal, but a clean "100%" / "0%" at the ends.
String formatPercent(double fraction) {
  final pct = (fraction * 100).clamp(0.0, 100.0);
  if (pct >= 99.95) return '100%';
  if (pct <= 0.05) return '0%';
  return '${pct.toStringAsFixed(1)}%';
}

String firstNameOf(String fullName) {
  final trimmed = fullName.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.split(RegExp(r'\s+')).first;
}

/// "Rajesh Sharma" -> "RS", "Rajesh" -> "R".
String initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  final first = parts.first.characters.first;
  final last = parts.length > 1 ? parts.last.characters.first : '';
  return (first + last).toUpperCase();
}

/// Days remaining in [now]'s month, as a label for the collections pill.
String daysLeftLabel(DateTime now) {
  final lastDay = DateTime(now.year, now.month + 1, 0).day;
  final left = lastDay - now.day;
  if (left <= 0) return 'Last day';
  return left == 1 ? '1 day left' : '$left days left';
}

String monthName(DateTime date) => DateFormat('MMMM').format(date);

/// "Just now", "5m ago", "3h ago", "2d ago", then a date ("28 Mar 2026").
String agoLabel(DateTime at, DateTime now) {
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM y').format(at);
}

/// "28 Mar 2026".
String formatDay(DateTime d) => DateFormat('d MMM y').format(d);
