// lib/presentation/property_detail/tabs/layout_tab.dart
import 'package:flutter/material.dart';

import '../../design/components/biz_dialogs.dart';
import '../../design/components/biz_section_label.dart';
import '../../design/components/biz_states.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../view_models/tenant_wizard/assignment.dart';
import '../../views/home/home_format.dart';
import '../property_detail_models.dart';
import '../property_detail_viewmodel.dart';
import '../../design/components/biz_info.dart';
import 'detail_common.dart';

/// Floors, rooms and beds — who sleeps where.
class LayoutTab extends StatelessWidget {
  const LayoutTab({super.key, required this.vm, required this.onOpenTenant});

  final PropertyDetailViewModel vm;
  final void Function(PropertyTenant tenant) onOpenTenant;

  @override
  Widget build(BuildContext context) {
    final floors = vm.floors;
    if (floors.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: BizEmptyState(
          icon: Icons.meeting_room_outlined,
          title: 'No rooms yet',
          message: 'Rooms and beds you add to this property show up here.',
        ),
      );
    }
    final s = vm.stats;
    return detailSliver([
      Row(
        children: [
          Expanded(child: BizStatBox(label: 'Rooms', value: '${s.totalRooms}')),
          const SizedBox(width: 10),
          Expanded(child: BizStatBox(label: 'Beds', value: '${s.totalBeds}')),
          const SizedBox(width: 10),
          Expanded(child: BizStatBox(label: 'Filled', value: '${s.occupiedBeds}')),
          const SizedBox(width: 10),
          Expanded(
            child: BizStatBox(label: 'Free', value: '${s.vacantBeds}', valueColor: BizColors.green),
          ),
        ],
      ),
      gap(18),
      for (final floor in floors) ...[
        BizSectionLabel(
          floor.floor == '0' ? 'Ground floor' : 'Floor ${floor.floor}',
          trailing: '${floor.freeBeds} of ${floor.totalBeds} beds free',
        ),
        for (final room in floor.rooms) ...[
          _RoomCard(
            room: room,
            onTap: () => _openRoom(context, room),
          ),
          gap(10),
        ],
        gap(8),
      ],
    ]);
  }

  void _openRoom(BuildContext context, RoomSlot room) {
    showBizSheet<void>(
      context,
      title: 'Room ${room.number}',
      subtitle: 'Floor ${room.floor} · ${room.subtitle}',
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
          for (final bed in room.beds)
            _BedRow(
              bed: bed,
              tenant: vm.occupantAt(room.id, bed.number),
              onTenant: (t) {
                Navigator.of(sheetContext).pop();
                onOpenTenant(t);
              },
            ),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onTap});

  final RoomSlot room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.985,
      onTap: onTap,
      semanticLabel: 'Room ${room.number}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(BizRadius.control + 4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Room ${room.number}', style: BizText.rowTitle),
                  const SizedBox(height: 2),
                  Text(room.subtitle, style: BizText.rowSubtitle),
                ],
              ),
            ),
            for (final bed in room.beds) ...[
              _BedDot(occupied: bed.occupied, label: 'B${bed.number}'),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right_rounded, size: 22, color: BizColors.chevron),
          ],
        ),
      ),
    );
  }
}

class _BedDot extends StatelessWidget {
  const _BedDot({required this.occupied, required this.label});

  final bool occupied;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 30),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: occupied ? BizColors.card : BizColors.greenTint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: BizText.style(
          11,
          700,
          color: occupied ? Colors.white : BizColors.greenDeep,
          height: 1,
        ),
      ),
    );
  }
}

class _BedRow extends StatelessWidget {
  const _BedRow({required this.bed, required this.tenant, required this.onTenant});

  final BedSlot bed;
  final PropertyTenant? tenant;
  final void Function(PropertyTenant) onTenant;

  @override
  Widget build(BuildContext context) {
    final t = tenant;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _BedDot(occupied: t != null, label: 'B${bed.number}'),
          const SizedBox(width: 14),
          Expanded(
            child: t == null
                ? Text('Vacant', style: BizText.rowSubtitle.copyWith(fontSize: 15))
                : Text(t.name, style: BizText.rowTitle),
          ),
          if (t != null && t.monthlyRent > 0)
            Text(formatInr(t.monthlyRent), style: BizText.bodyStrong),
          if (t != null)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.chevron_right_rounded, size: 20, color: BizColors.chevron),
            ),
        ],
      ),
    );
    return t == null ? row : Pressable(scale: 0.99, onTap: () => onTenant(t), child: row);
  }
}
