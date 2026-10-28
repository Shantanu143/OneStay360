// lib/presentation/maintenance/maintenance_models.dart
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';

/// Where a tenant's maintenance request is.
enum MaintenanceState {
  open('open', 'Open'),
  inProgress('in_progress', 'In progress'),
  resolved('resolved', 'Resolved'),
  cancelled('cancelled', 'Cancelled');

  const MaintenanceState(this.wire, this.label);

  final String wire;
  final String label;

  bool get isActive => this == open || this == inProgress;

  static MaintenanceState of(Object? v) =>
      values.firstWhere((s) => s.wire == v, orElse: () => open);
}

const _categories = {
  'electrical': ('Electrical', Icons.bolt_rounded),
  'plumbing': ('Plumbing', Icons.water_drop_rounded),
  'cleaning': ('Cleaning', Icons.cleaning_services_rounded),
  'internet': ('Wi-Fi', Icons.wifi_rounded),
  'furniture': ('Furniture', Icons.chair_rounded),
  'appliance': ('Appliance', Icons.kitchen_rounded),
  'other': ('Other', Icons.build_rounded),
};

/// `maintenanceRequests/{id}`, as raised from the tenant app.
class MaintenanceItem {
  const MaintenanceItem({
    required this.id,
    required this.title,
    required this.status,
    this.description = '',
    this.category = 'other',
    this.urgent = false,
    this.propertyId = '',
    this.propertyName = '',
    this.roomNumber = '',
    this.bedNumber = '',
    this.tenantName = '',
    this.tenantPhone = '',
    this.ownerNote,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final MaintenanceState status;
  final String description;
  final String category;
  final bool urgent;
  final String propertyId;
  final String propertyName;
  final String roomNumber;
  final String bedNumber;
  final String tenantName;
  final String tenantPhone;
  final String? ownerNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get categoryLabel => (_categories[category] ?? _categories['other']!).$1;
  IconData get icon => (_categories[category] ?? _categories['other']!).$2;

  /// "Green Nest · Room 101 · Bed 2".
  String get where => [
        if (propertyName.isNotEmpty) propertyName,
        if (roomNumber.isNotEmpty) 'Room $roomNumber',
        if (bedNumber.isNotEmpty) 'Bed $bedNumber',
      ].join(' · ');

  factory MaintenanceItem.fromMap(String id, Map<String, dynamic> m) {
    String text(String key) => m[key]?.toString().trim() ?? '';
    DateTime? date(String key) => m[key] is Timestamp ? (m[key] as Timestamp).toDate() : null;
    final note = text('ownerNote');
    return MaintenanceItem(
      id: id,
      title: text('title').isEmpty ? 'Request' : text('title'),
      status: MaintenanceState.of(m['status']),
      description: text('description'),
      category: _categories.containsKey(text('category')) ? text('category') : 'other',
      urgent: m['priority'] == 'urgent',
      propertyId: text('propertyId'),
      propertyName: text('propertyName'),
      roomNumber: text('roomNumber'),
      bedNumber: text('bedNumber'),
      tenantName: text('tenantName'),
      tenantPhone: text('tenantPhone'),
      ownerNote: note.isEmpty ? null : note,
      createdAt: date('createdAt'),
      updatedAt: date('updatedAt'),
    );
  }
}
