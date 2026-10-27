// lib/presentation/reports/reports_viewmodel.dart
import 'package:flutter/foundation.dart';

import 'reports_calculator.dart';
import 'reports_models.dart';
import 'reports_source.dart';

/// State of the Reports tab. The longest range is fetched once, so switching
/// between ranges is instant and costs no reads.
class ReportsViewModel extends ChangeNotifier {
  ReportsViewModel({required ReportsSource source, DateTime Function()? clock})
      : _source = source,
        _clock = clock ?? DateTime.now;

  final ReportsSource _source;
  final DateTime Function() _clock;

  static const _empty = ReportsData(properties: [], invoices: []);

  String? _businessId;
  ReportsData _data = _empty;
  ReportRange _range = ReportRange.thisMonth;
  ReportResult? _result;
  bool _loading = false;
  bool _hasLoaded = false;
  bool _refreshFailed = false;
  bool _disposed = false;
  String? _error;
  DateTime? _loadedAt;

  /// When the numbers were last loaded successfully.
  DateTime? get loadedAt => _loadedAt;

  ReportRange get range => _range;
  bool get isLoading => _loading;
  bool get hasLoaded => _hasLoaded;

  /// Set only when there is nothing to show.
  String? get error => _error;

  /// A refresh failed but earlier numbers are still on screen.
  bool get refreshFailed => _refreshFailed;

  /// The numbers for the selected range.
  ReportResult get result =>
      _result ??= buildReport(_data, range: _range, now: _clock());

  Future<void> load(String businessId) async {
    if (_loading) return;
    _businessId = businessId;
    _loading = true;
    _error = null;
    _notify();
    try {
      final periods = reportPeriods(_clock(), ReportRange.last6.months);
      _data = await _source.load(businessId, periods);
      _result = null;
      _hasLoaded = true;
      _loadedAt = _clock();
      _refreshFailed = false;
    } catch (e) {
      debugPrint('❌ [Reports] $e');
      if (_hasLoaded) {
        _refreshFailed = true;
      } else {
        _error = "Couldn't load your reports.";
      }
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Reloads for the business loaded before; a no-op before the first load.
  Future<void> refresh() async {
    final id = _businessId;
    if (id == null) return;
    await load(id);
  }

  /// Reloads only when nothing is loaded yet or the numbers are older than
  /// [maxAge]; a no-op before there is a business to load for.
  Future<void> refreshIfStale(Duration maxAge) async {
    final at = _loadedAt;
    if (at != null && _clock().difference(at) < maxAge) return;
    await refresh();
  }

  /// Something changed elsewhere: the next [refreshIfStale] reloads.
  void markStale() => _loadedAt = null;

  void selectRange(ReportRange range) {
    if (range == _range) return;
    _range = range;
    _result = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
