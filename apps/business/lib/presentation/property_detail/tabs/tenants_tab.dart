// lib/presentation/property_detail/tabs/tenants_tab.dart
import 'package:flutter/material.dart';

import '../../design/components/biz_avatar.dart';
import '../../design/components/biz_header.dart';
import '../../design/components/biz_search_field.dart';
import '../../design/components/biz_section_label.dart';
import '../../design/components/biz_states.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../views/home/home_format.dart';
import '../property_detail_models.dart';
import '../property_detail_viewmodel.dart';
import 'detail_common.dart';

/// Everyone living at the property, searchable, with a one-tap call.
class TenantsTab extends StatelessWidget {
  const TenantsTab({
    super.key,
    required this.vm,
    required this.searchController,
    required this.onOpenTenant,
    required this.onCall,
  });

  final PropertyDetailViewModel vm;
  final TextEditingController searchController;
  final void Function(PropertyTenant tenant) onOpenTenant;
  final void Function(PropertyTenant tenant) onCall;

  @override
  Widget build(BuildContext context) {
    final all = vm.tenants;
    final shown = vm.visibleTenants;

    return SliverMainAxisGroup(
      slivers: [
        if (all.isNotEmpty)
          detailSliver([
            BizSearchField(
              hint: 'Search by name, room or phone',
              controller: searchController,
              onChanged: vm.setSearch,
            ),
            gap(14),
            BizSectionLabel(
              'Tenants',
              trailing: shown.length == all.length
                  ? '${all.length} living here'
                  : '${shown.length} of ${all.length}',
            ),
          ]),
        if (all.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: BizEmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No tenants yet',
              message: 'Tenants you add to this property appear here.',
            ),
          )
        else if (shown.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: BizEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No tenants match',
              message: 'Try a different name, room or phone number.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: kDetailGutter),
            sliver: SliverList.separated(
              itemCount: shown.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _TenantRow(
                tenant: shown[i],
                onTap: () => onOpenTenant(shown[i]),
                onCall: () => onCall(shown[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _TenantRow extends StatelessWidget {
  const _TenantRow({required this.tenant, required this.onTap, required this.onCall});

  final PropertyTenant tenant;
  final VoidCallback onTap;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final t = tenant;
    final where = [
      if (t.roomId.isNotEmpty) 'Room ${t.roomId}',
      if (t.bedId.isNotEmpty) 'Bed ${t.bedId}',
    ].join(' · ');
    return Pressable(
      scale: 0.985,
      onTap: onTap,
      semanticLabel: t.name,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(BizRadius.control + 4),
        ),
        child: Row(
          children: [
            BizAvatar(
              initials: initialsOf(t.name),
              size: 44,
              background: BizColors.greenTint,
              foreground: BizColors.greenDeep,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: BizText.rowTitle),
                  if (where.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(where, style: BizText.rowSubtitle),
                  ],
                ],
              ),
            ),
            if (t.monthlyRent > 0) ...[
              Text(formatInr(t.monthlyRent), style: BizText.bodyStrong),
              const SizedBox(width: 10),
            ],
            BizRoundButton(
              icon: Icons.call_rounded,
              iconSize: 18,
              size: 40,
              tooltip: 'Call ${t.name}',
              onTap: onCall,
            ),
          ],
        ),
      ),
    );
  }
}
