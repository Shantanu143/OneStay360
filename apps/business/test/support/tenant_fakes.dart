import 'dart:async';

import 'package:business/presentation/tenant_detail/tenant_detail_models.dart';
import 'package:business/presentation/tenant_detail/tenant_detail_source.dart';

class FakeTenantSource implements TenantDetailSource {
  final controller = StreamController<List<TenantPayment>>.broadcast();
  int listens = 0;

  Object? updateFailure;
  Object? vacateFailure;
  final updates = <Map<String, String>>[];
  final vacated = <Map<String, String>>[];

  @override
  Stream<List<TenantPayment>> payments(String businessId, String tenantId) {
    listens++;
    return controller.stream;
  }

  @override
  Future<void> updateContact(
    String businessId,
    String tenantId, {
    required String name,
    required String phone,
    required String email,
  }) async {
    if (updateFailure != null) throw updateFailure!;
    updates.add({'businessId': businessId, 'tenantId': tenantId, 'name': name, 'phone': phone, 'email': email});
  }

  @override
  Future<void> vacate({
    required String businessId,
    required String tenantId,
    required String propertyId,
    required String roomId,
    required String bedId,
  }) async {
    if (vacateFailure != null) throw vacateFailure!;
    vacated.add({
      'businessId': businessId,
      'tenantId': tenantId,
      'propertyId': propertyId,
      'roomId': roomId,
      'bedId': bedId,
    });
  }
}

/// The map the property screen hands over.
Map<String, dynamic> tenantMap({
  String id = 'TEN0000001',
  String name = 'Rohan Mehta',
  Object? phone = '+919000000101',
  Object? email = 'rohan@example.test',
  Object? rent = 9500,
  Object? joinDate,
  String status = 'Active',
}) =>
    {
      'id': id,
      'tenantId': id,
      'businessId': 'BUS1',
      'propertyId': 'P1',
      'roomId': '101',
      'bedId': '1',
      'name': name,
      'phone': phone,
      'email': email,
      'room': '101',
      'bed': '1',
      'rent': rent,
      'joinDate': joinDate ?? DateTime(2026, 3, 30),
      'status': status,
    };
