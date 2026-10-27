// lib/presentation/requests/bed_picker.dart
import 'package:flutter/material.dart';

import '../design/components/biz_chips.dart';
import '../design/components/biz_section_label.dart';
import '../design/components/biz_states.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../view_models/tenant_wizard/assignment.dart';

/// Floors, rooms and their beds; free beds can be tapped.
class BedPicker extends StatelessWidget {
  const BedPicker({
    super.key,
    required this.floors,
    required this.selectedRoom,
    required this.selectedBed,
    required this.onSelect,
    this.highlight,
  });

  final List<FloorSlot> floors;
  final String? selectedRoom;
  final String? selectedBed;
  final void Function(String roomNumber, String bedNumber) onSelect;

  /// Rooms to tag as "Requested" (what the tenant asked for).
  final bool Function(RoomSlot room)? highlight;

  @override
  Widget build(BuildContext context) {
    final open = [
      for (final f in floors)
        if (f.hasFreeBeds)
          FloorSlot(floor: f.floor, rooms: [for (final r in f.rooms) if (r.freeBeds > 0) r]),
    ];
    if (open.isEmpty) {
      return const BizEmptyState(
        icon: Icons.bed_outlined,
        title: 'No free beds',
        message: 'Every bed in this property is taken or promised to someone else.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final floor in open) ...[
          BizSectionLabel(floor.label, trailing: '${floor.freeBeds} free'),
          for (final room in floor.rooms) ...[
            _RoomRow(
              room: room,
              selectedBed: selectedRoom == room.number ? selectedBed : null,
              requested: highlight?.call(room) ?? false,
              onSelect: (bed) => onSelect(room.number, bed),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.room,
    required this.selectedBed,
    required this.requested,
    required this.onSelect,
  });

  final RoomSlot room;
  final String? selectedBed;
  final bool requested;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BizRadius.control + 4),
        border: Border.all(
          color: selectedBed != null ? BizColors.green : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              if (requested) const BizStatusPill('Requested', tone: BizTone.info, dot: false),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final bed in room.beds)
                _BedChip(
                  label: 'B${bed.number}',
                  occupied: bed.occupied,
                  selected: selectedBed == bed.number,
                  onTap: () => onSelect(bed.number),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BedChip extends StatelessWidget {
  const _BedChip({
    required this.label,
    required this.occupied,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool occupied;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? BizColors.card
        : occupied
            ? BizColors.bedOccupied
            : BizColors.greenTint;
    final ink = selected
        ? Colors.white
        : occupied
            ? BizColors.bedOccupiedInk
            : BizColors.greenDeep;
    return Pressable(
      scale: 0.94,
      onTap: occupied ? null : onTap,
      semanticLabel: occupied ? '$label taken' : label,
      child: Container(
        constraints: const BoxConstraints(minWidth: 52),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        // widthFactor keeps the chip as wide as its label inside a Wrap.
        child: Center(
          widthFactor: 1,
          child: Text(label, style: BizText.style(14, 700, color: ink, height: 1)),
        ),
      ),
    );
  }
}
