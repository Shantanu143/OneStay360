// lib/presentation/maintenance/maintenance_form.dart
import 'package:flutter/foundation.dart';

import '../../data/models.dart';
import '../../data/sources.dart';

/// Raising a maintenance request for the current stay.
class MaintenanceForm extends ChangeNotifier {
  MaintenanceForm({required MaintenanceSource source, required this.account, required this.stay})
      : _source = source;

  final MaintenanceSource _source;
  final TenantAccount account;
  final Stay stay;

  static const maxTitle = 120;

  MaintenanceCategory? _category;
  String _title = '';
  String _description = '';
  bool _urgent = false;
  bool _attempted = false;
  bool _busy = false;
  String? _error;

  MaintenanceCategory? get category => _category;
  String get title => _title;
  String get description => _description;
  bool get urgent => _urgent;
  bool get busy => _busy;
  String? get error => _error;

  String? get categoryError => _attempted && _category == null ? 'Pick what it is about.' : null;

  String? get titleError {
    if (!_attempted) return null;
    final t = _title.trim();
    if (t.isEmpty) return 'Say what is wrong in a few words.';
    if (t.length > maxTitle) return 'Keep it under $maxTitle characters.';
    return null;
  }

  /// Common problems for the chosen category, to fill the title with a tap.
  List<String> get suggestions => switch (_category) {
        MaintenanceCategory.electrical => ['Fan not working', 'Light not working', 'Switch board damaged'],
        MaintenanceCategory.plumbing => ['Tap leaking', 'No water', 'Drain blocked'],
        MaintenanceCategory.cleaning => ['Room needs cleaning', 'Bathroom needs cleaning', 'Pest control'],
        MaintenanceCategory.internet => ['Wi-Fi not working', 'Wi-Fi is slow'],
        MaintenanceCategory.furniture => ['Bed broken', 'Cupboard lock broken', 'Chair broken'],
        MaintenanceCategory.appliance => ['Geyser not working', 'AC not cooling', 'Washing machine broken'],
        _ => const [],
      };

  void setCategory(MaintenanceCategory c) => _set(() => _category = c);
  void setTitle(String v) => _set(() => _title = v);
  void setDescription(String v) => _set(() => _description = v);
  void setUrgent(bool v) => _set(() => _urgent = v);

  void _set(VoidCallback change) {
    change();
    _error = null;
    notifyListeners();
  }

  Future<bool> submit() async {
    if (_busy) return false;
    _attempted = true;
    if (categoryError != null || titleError != null) {
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _source.raiseMaintenance(MaintenanceDraft(
        uid: account.uid,
        tenantId: account.tenantId,
        tenantName: account.name,
        tenantPhone: account.phone,
        stay: stay,
        category: _category!,
        title: _title.trim(),
        description: _description.trim(),
        urgent: _urgent,
      ));
      return true;
    } catch (e) {
      debugPrint('❌ [Maintenance] $e');
      _error = e is TenantFailure ? e.message : "Couldn't send your request. Try again.";
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
