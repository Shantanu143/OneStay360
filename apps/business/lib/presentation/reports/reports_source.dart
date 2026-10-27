// lib/presentation/reports/reports_source.dart
import 'reports_models.dart';

/// Where report data comes from; faked in tests.
abstract class ReportsSource {
  /// The business's properties and every rent invoice whose `periodMonth` is
  /// one of [periods] (`YYYY-MM`).
  Future<ReportsData> load(String businessId, List<String> periods);
}
