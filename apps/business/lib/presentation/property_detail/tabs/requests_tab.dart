// lib/presentation/property_detail/tabs/requests_tab.dart
import 'package:flutter/material.dart';
import 'package:models/tenant/tenant_request_model.dart';

import '../../design/components/biz_avatar.dart';
import '../../design/components/biz_card.dart';
import '../../design/components/biz_chips.dart';
import '../../design/components/biz_states.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../views/home/home_format.dart';
import '../property_detail_models.dart';
import '../property_detail_viewmodel.dart';
import 'detail_common.dart';

/// People asking for a bed here, newest first, updating live.
class RequestsTab extends StatelessWidget {
  const RequestsTab({
    super.key,
    required this.vm,
    required this.now,
    required this.onOpen,
  });

  final PropertyDetailViewModel vm;
  final DateTime now;
  final void Function(TenantRequest request) onOpen;

  @override
  Widget build(BuildContext context) {
    final requests = vm.requests;

    if (vm.requestsError != null && requests.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: BizErrorState(message: vm.requestsError!),
      );
    }
    if (vm.requestsLoading && requests.isEmpty) {
      return detailSliver(const [BizSkeletonList(count: 3, cardHeight: 100)]);
    }
    if (requests.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: BizEmptyState(
          icon: Icons.inbox_outlined,
          title: 'No requests yet',
          message: 'When someone asks for a bed here, it shows up instantly. '
              'Share the QR code to get requests.',
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(kDetailGutter, 8, kDetailGutter, 0),
      sliver: SliverList.separated(
        itemCount: requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) =>
            _RequestRow(request: requests[i], now: now, onTap: () => onOpen(requests[i])),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request, required this.now, required this.onTap});

  final TenantRequest request;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final status = RequestStatus.of(r);
    final sharing = (r.sharingType ?? '').trim();
    final wants = [
      if (sharing.isNotEmpty) int.tryParse(sharing) != null ? '$sharing-sharing' : sharing,
      if (r.hasAC == true) 'AC',
    ].join(' · ');
    final name = r.tenantName.trim().isEmpty ? 'Unnamed request' : r.tenantName.trim();

    return Pressable(
      scale: 0.985,
      onTap: onTap,
      semanticLabel: name,
      child: BizCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BizAvatar(
              initials: initialsOf(name),
              size: 44,
              background: BizColors.greenTint,
              foreground: BizColors.greenDeep,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: BizText.rowTitle),
                  const SizedBox(height: 2),
                  if (r.phone.isNotEmpty) Text(r.phone, style: BizText.rowSubtitle),
                  Text(
                    [agoLabel(r.createdAt, now), if (wants.isNotEmpty) wants].join(' · '),
                    style: BizText.rowSubtitle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            BizStatusPill(status.label, tone: toneOf(status.tone)),
          ],
        ),
      ),
    );
  }
}
