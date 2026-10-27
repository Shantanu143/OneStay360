// lib/presentation/stay/stay_feed.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models.dart';
import '../../data/sources.dart';
import '../../data/tenant_session.dart';

/// Live data about the tenant's current stay, shared by Home, My stay, the
/// rent screen and payment history: the property, the room, rent invoices
/// and payments. Follows [TenantSession.stay] as it changes.
class StayFeed extends ChangeNotifier {
  StayFeed({required TenantSession session, required StaySource source, DateTime Function()? clock})
      : _session = session,
        _source = source,
        _clock = clock ?? DateTime.now {
    _session.addListener(_follow);
    _follow();
  }

  final TenantSession _session;
  final StaySource _source;
  final DateTime Function() _clock;

  String? _key;
  Stay? _stay;
  PropertyContact? _property;
  RoomInfo? _room;
  List<RentInvoice> _invoices = const [];
  List<RentPayment> _payments = const [];
  bool _invoicesLoaded = false;
  bool _paymentsLoaded = false;
  bool _disposed = false;
  final _subs = <StreamSubscription<Object?>>[];

  Stay? get stay => _stay;
  PropertyContact? get property => _property;
  RoomInfo? get room => _room;
  List<RentInvoice> get invoices => _invoices;
  List<RentPayment> get payments => _payments;

  /// Invoices or payments are still on their way.
  bool get loadingMoney => _stay != null && !(_invoicesLoaded && _paymentsLoaded);

  /// Unpaid and overdue invoices, oldest first.
  List<RentInvoice> get openInvoices =>
      _invoices.where((i) => i.isOpen).toList()..sort((a, b) => a.periodMonth.compareTo(b.periodMonth));

  /// What to pay next.
  RentInvoice? get dueInvoice => openInvoices.firstOrNull;

  double get totalDue => openInvoices.fold(0, (sum, i) => sum + i.amount);

  /// A payment the owner still has to confirm for [invoiceId].
  RentPayment? pendingPaymentFor(String invoiceId) =>
      _payments.where((p) => p.invoiceId == invoiceId && p.state == PaymentState.pending).firstOrNull;

  List<RentPayment> get pendingPayments => _payments.where((p) => p.state == PaymentState.pending).toList();

  /// The next time rent is billed (the move-in day each month).
  DateTime? get nextBillingDate {
    final day = _stay?.billingDay;
    if (day == null) return null;
    final now = _clock();
    DateTime on(int year, int month) {
      final last = DateTime(year, month + 1, 0).day;
      return DateTime(year, month, day > last ? last : day);
    }

    final thisMonth = on(now.year, now.month);
    final today = DateTime(now.year, now.month, now.day);
    return thisMonth.isBefore(today) ? on(now.year, now.month + 1) : thisMonth;
  }

  void _follow() {
    final stay = _session.stay;
    final tenantId = _session.tenantId;
    final key = stay == null || tenantId == null
        ? null
        : '${stay.businessId}/${stay.propertyId}/${stay.roomId}/$tenantId';
    if (key == _key) {
      if (stay != null && _stay != stay) {
        _stay = stay;
        _notify();
      }
      return;
    }
    _key = key;
    _cancel();
    _stay = stay;
    _property = null;
    _room = null;
    _invoices = const [];
    _payments = const [];
    _invoicesLoaded = _paymentsLoaded = false;
    if (stay != null && tenantId != null) _listen(stay, tenantId, key!);
    _notify();
  }

  void _listen(Stay stay, String tenantId, String key) {
    void onError(Object e) => debugPrint('⚠️ [StayFeed] $e');
    _subs
      ..add(_source.watchProperty(stay.businessId, stay.propertyId).listen((p) {
        _property = p;
        _notify();
      }, onError: onError))
      ..add(_source.watchInvoices(stay.businessId, tenantId).listen((list) {
        _invoices = list;
        _invoicesLoaded = true;
        _notify();
      }, onError: (Object e) {
        onError(e);
        _invoicesLoaded = true;
        _notify();
      }))
      ..add(_source.watchPayments(stay.businessId, tenantId).listen((list) {
        _payments = list;
        _paymentsLoaded = true;
        _notify();
      }, onError: (Object e) {
        onError(e);
        _paymentsLoaded = true;
        _notify();
      }));
    _source.loadRoom(stay.businessId, stay.propertyId, stay.roomId).then((room) {
      if (_key != key) return;
      _room = room;
      _notify();
    });
  }

  void _cancel() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _session.removeListener(_follow);
    _cancel();
    super.dispose();
  }
}
