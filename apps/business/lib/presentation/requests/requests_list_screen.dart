// lib/presentation/requests/requests_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/providers/business_state_provider.dart';
import '../design/components/biz_card.dart';
import '../design/components/biz_avatar.dart';
import '../design/components/biz_chips.dart';
import '../design/components/biz_scaffold.dart';
import '../design/components/biz_states.dart';
import '../design/tokens.dart';
import '../views/home/home_format.dart';
import 'firestore_request_source.dart';
import 'request_detail_screen.dart';
import 'request_list_viewmodel.dart';
import 'request_models.dart';
import 'request_source.dart';

typedef RequestOpener = Future<void> Function(BuildContext context, EnrollmentRequest request);

BizTone _tone(String key) => switch (key) {
      'success' => BizTone.success,
      'warning' => BizTone.warning,
      'danger' => BizTone.danger,
      'info' => BizTone.info,
      _ => BizTone.neutral,
    };

/// Every enrollment request of the business, live, grouped by who has to act.
class EnrollmentRequestsScreen extends StatefulWidget {
  const EnrollmentRequestsScreen({
    super.key,
    this.initialPropertyId,
    this.initialRequestId,
    this.businessId,
    this.source,
    this.onOpen,
    this.clock,
  });

  /// Only this property's requests.
  final String? initialPropertyId;

  /// A request to point out (from a notification).
  final String? initialRequestId;

  /// Defaults to the signed-in business.
  final String? businessId;
  final RequestListSource? source;

  /// Replaces opening the detail screen (tests).
  final RequestOpener? onOpen;
  final DateTime Function()? clock;

  @override
  State<EnrollmentRequestsScreen> createState() => _EnrollmentRequestsScreenState();
}

class _EnrollmentRequestsScreenState extends State<EnrollmentRequestsScreen> {
  RequestListViewModel? _vm;

  /// The properties this person can open (null = all); read when needed so a
  /// change of access shows up.
  Set<String>? _scope() {
    try {
      return Provider.of<BusinessStateProvider>(context, listen: false).propertyScope;
    } catch (_) {
      return null;
    }
  }

  final _highlightKey = GlobalKey(debugLabel: 'highlighted-request');
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    var businessId = widget.businessId;
    if (businessId == null) {
      try {
        businessId = Provider.of<BusinessStateProvider>(context, listen: false).businessId;
      } catch (_) {
        // No session in scope: the screen explains there is no business.
      }
    }
    if (businessId != null && businessId.isNotEmpty) {
      _vm = RequestListViewModel(
        source: widget.source ?? FirestoreRequestListSource(),
        businessId: businessId,
        propertyId: widget.initialPropertyId,
        propertyScope: () => _scope(),
      )..start();
      _vm!.addListener(_onChange);
    }
  }

  /// A notification can name a request in any stage: make sure it is listed,
  /// and bring it into view once.
  void _onChange() {
    final vm = _vm!;
    final wanted = widget.initialRequestId;
    if (wanted == null || _scrolled || vm.loading) return;
    final all = vm.count(RequestFilter.all);
    if (all == 0) return;
    if (!vm.visible.any((r) => r.id == wanted)) vm.setFilter(RequestFilter.all);
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _highlightKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.2);
      }
    });
  }

  @override
  void dispose() {
    _vm?.removeListener(_onChange);
    _vm?.dispose();
    super.dispose();
  }

  Future<void> _open(BuildContext context, EnrollmentRequest r) async {
    final custom = widget.onOpen;
    if (custom != null) return custom(context, r);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RequestDetailScreen.fromRequest(request: r)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) {
      return const BizScaffold(
        title: 'Requests',
        body: BizEmptyState(
          icon: Icons.business_outlined,
          title: 'No business found',
          message: 'Requests appear here once your business is set up.',
        ),
      );
    }
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => BizScaffold(
        title: 'Requests',
        eyebrow: vm.loading || vm.error != null
            ? null
            : switch (vm.count(RequestFilter.needsYou)) {
                0 => 'Nothing needs you right now',
                1 => '1 needs you',
                final n => '$n need you',
              },
        showBack: true,
        belowHeader: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: BizFilterChips(
            chips: [
              for (final f in RequestFilter.values) BizChipData(f.label, count: vm.count(f)),
            ],
            selectedIndex: vm.filter.index,
            onSelected: (i) => vm.setFilter(RequestFilter.values[i]),
          ),
        ),
        body: _body(vm),
      ),
    );
  }

  Widget _body(RequestListViewModel vm) {
    if (vm.error != null && vm.count(RequestFilter.all) == 0) {
      return BizErrorState(message: vm.error!, onRetry: vm.retry);
    }
    if (vm.loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: BizSkeletonList(count: 4, cardHeight: 104),
      );
    }
    if (vm.count(RequestFilter.all) == 0) {
      return const BizEmptyState(
        icon: Icons.inbox_outlined,
        title: 'No enrollment requests yet',
        message: 'When a tenant asks for a bed, it shows up here instantly.',
      );
    }
    final items = vm.visible;
    if (items.isEmpty) {
      return BizEmptyState(
        icon: Icons.done_all_rounded,
        title: 'Nothing here',
        message: vm.filter == RequestFilter.needsYou
            ? 'You are all caught up.'
            : 'No requests in this group.',
      );
    }
    final bottom = MediaQuery.viewPaddingOf(context).bottom + 24;
    final now = (widget.clock ?? DateTime.now)();
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = items[i];
        final highlighted = r.id == widget.initialRequestId;
        return _Row(
          key: highlighted ? const Key('highlighted-request') : ValueKey(r.id),
          anchor: highlighted ? _highlightKey : null,
          request: r,
          now: now,
          highlighted: highlighted,
          onTap: () => _open(context, r),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.request,
    required this.now,
    required this.highlighted,
    required this.onTap,
    this.anchor,
  });

  final EnrollmentRequest request;
  final DateTime now;
  final bool highlighted;
  final VoidCallback onTap;
  final GlobalKey? anchor;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final where = [
      if (r.propertyName != null) r.propertyName!,
      if (r.sharingLabel != null) r.sharingLabel!,
    ].join(' · ');
    return Container(
      key: anchor,
      decoration: highlighted
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(BizRadius.card + 2),
              border: Border.all(color: BizColors.green, width: 1.5),
            )
          : null,
      child: BizCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BizAvatar(
              initials: r.initials,
              size: 44,
              background: BizColors.greenTint,
              foreground: BizColors.greenDeep,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: BizText.rowTitle),
                  if (r.phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(r.phone, style: BizText.rowSubtitle),
                  ],
                  if (where.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(where, maxLines: 1, overflow: TextOverflow.ellipsis, style: BizText.rowSubtitle),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BizStatusPill(r.stage.label, tone: _tone(r.stage.tone)),
                const SizedBox(height: 8),
                Text(agoLabel(r.createdAt, now), style: BizText.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
