import 'dart:async';

import 'package:business/presentation/reports/reports_models.dart';
import 'package:business/presentation/reports/reports_source.dart';
import 'package:business/presentation/reports/reports_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSource implements ReportsSource {
  ReportsData data = ReportsData(
    properties: const [ReportProperty(id: 'P1', name: 'Sunrise', totalBeds: 10, occupiedBeds: 6)],
    invoices: [
      const ReportInvoice(
        tenantId: 't1',
        tenantName: 'Asha',
        propertyId: 'P1',
        periodMonth: '2026-10',
        amount: 5000,
        status: 'paid',
        mode: 'upi',
      ),
      const ReportInvoice(
        tenantId: 't1',
        tenantName: 'Asha',
        propertyId: 'P1',
        periodMonth: '2026-09',
        amount: 5000,
        status: 'paid',
        mode: 'cash',
      ),
    ],
  );
  Object? failure;
  Completer<void>? gate;
  final calls = <List<String>>[];

  @override
  Future<ReportsData> load(String businessId, List<String> periods) async {
    calls.add(periods);
    await gate?.future;
    if (failure != null) throw failure!;
    return data;
  }
}

void main() {
  late FakeSource source;
  late ReportsViewModel vm;

  setUp(() {
    source = FakeSource();
    vm = ReportsViewModel(source: source, clock: () => DateTime(2026, 10, 26));
  });

  tearDown(() => vm.dispose());

  test('starts empty and not loaded, and does not crash when asked for numbers', () {
    expect(vm.hasLoaded, isFalse);
    expect(vm.isLoading, isFalse);
    expect(vm.result.summary.billed, 0);
    expect(vm.result.properties, isEmpty);
  });

  test('loads six months once, oldest first', () async {
    await vm.load('B1');

    expect(vm.hasLoaded, isTrue);
    expect(source.calls, hasLength(1));
    expect(source.calls.single, ['2026-05', '2026-06', '2026-07', '2026-08', '2026-09', '2026-10']);
  });

  test('defaults to this month', () async {
    await vm.load('B1');

    expect(vm.range, ReportRange.thisMonth);
    expect(vm.result.summary.collected, 5000);
  });

  test('switching the range recalculates without loading again', () async {
    await vm.load('B1');

    vm.selectRange(ReportRange.last3);

    expect(vm.result.summary.collected, 10000);
    expect(vm.result.months, hasLength(3));
    expect(source.calls, hasLength(1));
  });

  test('tells listeners when the range changes, but not when it does not', () async {
    await vm.load('B1');
    var notified = 0;
    vm.addListener(() => notified++);

    vm.selectRange(ReportRange.last6);
    vm.selectRange(ReportRange.last6);

    expect(notified, 1);
  });

  test('is loading while the source works', () async {
    source.gate = Completer<void>();
    final pending = vm.load('B1');
    expect(vm.isLoading, isTrue);
    expect(vm.hasLoaded, isFalse);

    source.gate!.complete();
    await pending;

    expect(vm.isLoading, isFalse);
  });

  test('a second load while one is running does nothing', () async {
    source.gate = Completer<void>();
    final first = vm.load('B1');
    final second = vm.load('B1');

    source.gate!.complete();
    await Future.wait([first, second]);

    expect(source.calls, hasLength(1));
  });

  group('when loading fails', () {
    test('says so and can be retried', () async {
      source.failure = Exception('permission-denied');
      await vm.load('B1');

      expect(vm.hasLoaded, isFalse);
      expect(vm.error, "Couldn't load your reports.");

      source.failure = null;
      await vm.load('B1');

      expect(vm.error, isNull);
      expect(vm.hasLoaded, isTrue);
    });

    test('a failed refresh keeps the numbers already shown', () async {
      await vm.load('B1');
      source.failure = Exception('offline');

      await vm.refresh();

      expect(vm.hasLoaded, isTrue);
      expect(vm.error, isNull);
      expect(vm.refreshFailed, isTrue);
      expect(vm.result.summary.collected, 5000);
    });

    test('a later refresh that works clears the warning and shows new numbers', () async {
      await vm.load('B1');
      source.failure = Exception('offline');
      await vm.refresh();

      source.failure = null;
      source.data = const ReportsData(properties: [], invoices: []);
      await vm.refresh();

      expect(vm.refreshFailed, isFalse);
      expect(vm.result.summary.collected, 0);
    });
  });

  test('refresh before any load loads for the remembered business', () async {
    await vm.refresh();

    expect(source.calls, isEmpty, reason: 'it has no business to load for yet');
  });

  group('staleness', () {
    late DateTime clockNow;
    late ReportsViewModel timed;

    setUp(() {
      clockNow = DateTime(2026, 10, 26, 10);
      timed = ReportsViewModel(source: source, clock: () => clockNow);
    });

    tearDown(() => timed.dispose());

    test('has no load time before the first load', () {
      expect(timed.loadedAt, isNull);
    });

    test('remembers when it last loaded', () async {
      await timed.load('B1');

      expect(timed.loadedAt, DateTime(2026, 10, 26, 10));
    });

    test('does not reload while the numbers are fresh', () async {
      await timed.load('B1');
      clockNow = clockNow.add(const Duration(seconds: 30));

      await timed.refreshIfStale(const Duration(minutes: 1));

      expect(source.calls, hasLength(1));
    });

    test('reloads once they are older than the limit', () async {
      await timed.load('B1');
      clockNow = clockNow.add(const Duration(minutes: 2));

      await timed.refreshIfStale(const Duration(minutes: 1));

      expect(source.calls, hasLength(2));
      expect(timed.loadedAt, clockNow);
    });

    test('does nothing before there is a business to load for', () async {
      await timed.refreshIfStale(const Duration(minutes: 1));

      expect(source.calls, isEmpty);
    });

    test('markStale forces the next check to reload even if fresh', () async {
      await timed.load('B1');

      timed.markStale();
      await timed.refreshIfStale(const Duration(minutes: 1));

      expect(source.calls, hasLength(2));
    });
  });

  test('being disposed while loading does not throw', () async {
    source.gate = Completer<void>();
    final other = ReportsViewModel(source: source, clock: () => DateTime(2026, 10, 26));
    final pending = other.load('B1');

    other.dispose();
    source.gate!.complete();

    await expectLater(pending, completes);
  });
}
