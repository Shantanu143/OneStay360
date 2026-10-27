// lib/presentation/property_detail/tabs/detail_common.dart
//
// Small pieces shared by the property detail tabs.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';

import '../../design/components/biz_chips.dart';

const double kDetailGutter = 16;

/// A list of boxes laid out as one sliver with the page gutter.
Widget detailSliver(List<Widget> children, {double top = 8}) {
  return SliverPadding(
    padding: EdgeInsets.fromLTRB(kDetailGutter, top, kDetailGutter, 0),
    sliver: SliverList.list(children: children),
  );
}

SizedBox gap([double h = 12]) => SizedBox(height: h);

BizTone toneOf(String key) {
  switch (key) {
    case 'success':
      return BizTone.success;
    case 'warning':
      return BizTone.warning;
    case 'danger':
      return BizTone.danger;
    case 'info':
      return BizTone.info;
    default:
      return BizTone.neutral;
  }
}

String titleCase(String s) {
  final t = s.trim().replaceAll('_', ' ');
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

DateTime? asDate(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

