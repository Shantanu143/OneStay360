// lib/presentation/reports/firestore_reports_source.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../common/active_occupancy.dart';
import 'reports_models.dart';
import 'reports_source.dart';

/// Reads invoices one tenant at a time: the rules have no collection-group
/// access to `rent_invoices`, so this bounds how many reads run at once.
class FirestoreReportsSource implements ReportsSource {
  FirestoreReportsSource({
    required this.loadProperties,
    FirebaseFirestore? firestore,
    this.concurrency = 10,
  }) : _fs = firestore ?? FirebaseFirestore.instance;

  final Future<List<ReportProperty>> Function(String businessId) loadProperties;
  final int concurrency;
  final FirebaseFirestore _fs;

  @override
  Future<ReportsData> load(String businessId, List<String> periods) async {
    final properties = await loadProperties(businessId);

    // Every tenant, past ones too: last month's rent from someone who has
    // since left still counts towards last month.
    final tenants = await _fs.collection('businesses').doc(businessId).collection('tenants').get();

    final invoices = <ReportInvoice>[];
    for (var i = 0; i < tenants.docs.length; i += concurrency) {
      final batch = tenants.docs.skip(i).take(concurrency).toList();
      final results = await Future.wait([
        for (final t in batch) t.reference.collection('rent_invoices').where('periodMonth', whereIn: periods).get(),
      ]);
      for (var j = 0; j < batch.length; j++) {
        final tenant = batch[j].data();
        for (final doc in results[j].docs) {
          invoices.add(_invoice(batch[j].id, tenant, doc.data()));
        }
      }
    }
    // Beds in use are the people living there now, not the stored counter.
    final occupied = countActiveTenants(tenants.docs.map((d) => d.data()));
    return ReportsData(
      properties: [for (final p in properties) p.withOccupiedBeds(occupied[p.id] ?? 0)],
      invoices: invoices,
    );
  }

  ReportInvoice _invoice(String tenantId, Map<String, dynamic> tenant, Map<String, dynamic> d) {
    final amount = d['amount'];
    final propertyId = (d['propertyId'] ?? '').toString();
    final mode = d['mode']?.toString();
    return ReportInvoice(
      tenantId: tenantId,
      tenantName: (tenant['name'] ?? 'Tenant').toString(),
      propertyId: propertyId.isNotEmpty ? propertyId : (tenant['propertyId'] ?? '').toString(),
      periodMonth: (d['periodMonth'] ?? '').toString(),
      amount: amount is num ? amount.toDouble() : double.tryParse('$amount') ?? 0.0,
      status: (d['status'] ?? 'unpaid').toString(),
      dueDate: _asDate(d['dueDate']),
      mode: mode == null || mode.isEmpty ? null : mode,
    );
  }

  DateTime? _asDate(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
