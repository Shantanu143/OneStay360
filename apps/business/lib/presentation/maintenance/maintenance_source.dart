// lib/presentation/maintenance/maintenance_source.dart
import 'maintenance_models.dart';

/// Tenants' maintenance requests for a business. Faked in tests.
abstract class MaintenanceSource {
  Stream<List<MaintenanceItem>> watch(String businessId);

  /// Moves a request along; [note] replaces the note the tenant sees.
  Future<void> update(String id, {required MaintenanceState status, String? note, required String by});
}
