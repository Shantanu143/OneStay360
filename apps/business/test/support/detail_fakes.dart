import 'dart:async';

import 'package:business/presentation/property_detail/property_detail_models.dart';
import 'package:business/presentation/property_detail/property_detail_source.dart';
import 'package:models/business/property/property_model.dart';
import 'package:models/business/property/property_room_model.dart';
import 'package:models/tenant/tenant_request_model.dart';

PropertyTenant tenant(
  String id, {
  String name = 'Tenant',
  String phone = '9000000000',
  String room = '101',
  String bed = '1',
  double rent = 6500,
}) =>
    PropertyTenant(
      id: id,
      name: name,
      phone: phone,
      roomId: room,
      bedId: bed,
      monthlyRent: rent,
      status: 'active',
    );

TenantRequest request(String id, String status, {DateTime? at, String name = 'Mohit'}) =>
    TenantRequest(
      id: id,
      tenantName: name,
      phone: '9000000501',
      status: status,
      createdAt: at ?? DateTime(2026, 10, 20),
      propertyId: 'P1',
      businessId: 'BUS1',
    );

class FakeDetailSource implements PropertyDetailSource {
  Property? prop;
  List<PropertyRoom> roomList = const [];
  List<PropertyTenant> tenantList = const [];
  List<Map<String, dynamic>> payments = const [];
  String? unpaid;
  List<InvoiceSummary> invoices = const [];

  Object? coreFailure;
  Object? billingFailure;
  Object? invoicesFailure;

  int propertyCalls = 0;
  int billingCalls = 0;
  int unpaidCalls = 0;
  int invoiceCalls = 0;
  String? lastPeriod;
  List<String>? lastInvoiceTenants;

  final requestsController = StreamController<List<TenantRequest>>.broadcast();
  bool requestsCancelled = false;

  @override
  Future<Property?> property(String propertyId) async {
    propertyCalls++;
    if (coreFailure != null) throw coreFailure!;
    return prop;
  }

  @override
  Future<List<PropertyRoom>> rooms(Property property) async => roomList;

  @override
  Future<List<PropertyTenant>> activeTenants(String businessId, String propertyId) async =>
      tenantList;

  @override
  Stream<List<TenantRequest>> requests(String propertyId) {
    return requestsController.stream;
  }

  @override
  Future<List<Map<String, dynamic>>> billingPayments(String businessId, String propertyId) async {
    billingCalls++;
    if (billingFailure != null) throw billingFailure!;
    return payments;
  }

  @override
  Future<String?> unpaidInvoiceId(String businessId, String propertyId) async {
    unpaidCalls++;
    return unpaid;
  }

  @override
  Future<List<InvoiceSummary>> invoicesFor(
      String businessId, List<String> tenantIds, String period) async {
    invoiceCalls++;
    lastPeriod = period;
    lastInvoiceTenants = tenantIds;
    if (invoicesFailure != null) throw invoicesFailure!;
    return invoices;
  }
}
