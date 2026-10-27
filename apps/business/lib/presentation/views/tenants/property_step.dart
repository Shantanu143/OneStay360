// lib/presentation/views/tenants/property_step.dart
//
// Step 1: which property, floor and bed.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/components/biz_card.dart';
import '../../design/components/biz_list_row.dart';
import '../../design/components/biz_section_label.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../view_models/tenant_wizard/assignment.dart';
import '../../view_models/tenant_wizard/wizard_viewmodel.dart';

class PropertyStep extends StatelessWidget {
  const PropertyStep({
    super.key,
    required this.vm,
    required this.onChangeProperty,
  });

  final AddTenantWizardViewModel vm;
  final VoidCallback onChangeProperty;

  @override
  Widget build(BuildContext context) {
    final property = vm.property!;
    final floors = vm.floors;
    final selectedFloor = vm.floor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BizSectionLabel('Property'),
        BizCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const BizIconTile(
                icon: Icons.apartment_outlined,
                color: BizColors.green,
                size: 40,
                iconSize: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BizText.style(17.5, 600, letterSpacing: -0.3),
                    ),
                    Text(
                      '${floors.length} ${floors.length == 1 ? 'floor' : 'floors'} · '
                      '${vm.freeBeds} ${vm.freeBeds == 1 ? 'bed' : 'beds'} free',
                      style: BizText.style(13, 400, color: BizColors.inkSoft),
                    ),
                  ],
                ),
              ),
              if (vm.properties.length > 1)
                Pressable(
                  onTap: onChangeProperty,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      'Change',
                      style: BizText.style(16, 600, color: BizColors.green),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (vm.loadingRooms)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (floors.isEmpty)
          const _NoRooms()
        else ...[
          BizSectionLabel(
            'Floor',
            trailing: '${vm.freeBeds} of ${vm.totalBeds} beds free',
          ),
          _FloorRow(
            floors: floors,
            selected: vm.selectedFloor,
            onSelect: vm.selectFloor,
          ),
          const SizedBox(height: 20),
          if (selectedFloor != null) ...[
            BizSectionLabel(
              'Bed on ${selectedFloor.label.toLowerCase()}',
              trailing: 'Tap a free bed',
            ),
            _BedPanel(vm: vm, floor: selectedFloor),
          ],
          const SizedBox(height: 12),
          const _Legend(),
          if (vm.showErrors && vm.errors[WizardField.bed] != null)
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 4),
              child: Text(
                vm.errors[WizardField.bed]!,
                style: BizText.style(14, 600, color: BizColors.dangerInk),
              ),
            ),
        ],
      ],
    );
  }
}

class _NoRooms extends StatelessWidget {
  const _NoRooms();

  @override
  Widget build(BuildContext context) {
    return BizCard(
      child: Column(
        children: [
          const Icon(
            Icons.meeting_room_outlined,
            size: 32,
            color: BizColors.inkSoft,
          ),
          const SizedBox(height: 10),
          Text('This property has no rooms yet', style: BizText.cardTitle),
          const SizedBox(height: 4),
          Text(
            'Add rooms and beds to the property, then come back.',
            textAlign: TextAlign.center,
            style: BizText.rowSubtitle,
          ),
        ],
      ),
    );
  }
}

class _FloorRow extends StatelessWidget {
  const _FloorRow({
    required this.floors,
    required this.selected,
    required this.onSelect,
  });

  final List<FloorSlot> floors;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget card(FloorSlot f) => _FloorCard(
      floor: f,
      selected: f.floor == selected,
      onTap: () {
        HapticFeedback.selectionClick();
        onSelect(f.floor);
      },
    );

    // Up to three floors share the width; more scroll sideways.
    if (floors.length <= 3) {
      return Row(
        children: [
          for (var i = 0; i < floors.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: card(floors[i])),
          ],
        ],
      );
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        physics: const BouncingScrollPhysics(),
        itemCount: floors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(width: 112, child: card(floors[i])),
      ),
    );
  }
}

class _FloorCard extends StatelessWidget {
  const _FloorCard({
    required this.floor,
    required this.selected,
    required this.onTap,
  });

  final FloorSlot floor;
  final bool selected;
  final VoidCallback onTap;

  String get _caption {
    if (floor.freeBeds == 0) return 'Full';
    if (floor.isLastBed) return 'Last bed';
    return '${floor.freeBeds} of ${floor.totalBeds} free';
  }

  @override
  Widget build(BuildContext context) {
    final ink = selected ? Colors.white : BizColors.ink;
    final captionColor = selected
        ? Colors.white
        : (floor.isLastBed
              ? BizColors.lastBed
              : (floor.freeBeds == 0 ? BizColors.inkSoft : BizColors.ink));

    // One dot per bed (scaled down past 8) so fullness reads at a glance.
    final total = floor.totalBeds;
    final dots = total.clamp(1, 8);
    final filled = floor.freeBeds == 0
        ? 0
        : (total <= 8
              ? floor.freeBeds
              : (floor.freeBeds / total * 8).ceil().clamp(1, 8));
    final onColor = selected ? BizColors.mint : BizColors.green;
    final offColor = selected ? BizColors.dotEmptyOnDark : BizColors.dotEmpty;

    return Pressable(
      key: ValueKey('floor-${floor.floor}'),
      scale: 0.97,
      haptic: false,
      onTap: onTap,
      semanticLabel: '${floor.label}, $_caption',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        height: 117,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: selected ? BizColors.card : Colors.white,
          borderRadius: BorderRadius.circular(BizRadius.card),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: BizColors.card.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Floor',
              style: BizText.style(
                12.5,
                500,
                color: selected
                    ? Colors.white.withValues(alpha: 0.75)
                    : const Color(0xFF4D5350),
              ),
            ),
            Text(
              floor.floor == '0' ? 'G' : floor.floor,
              style: BizText.style(
                32,
                700,
                color: ink,
                letterSpacing: -1,
                height: 1.05,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                for (var i = 0; i < dots; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: i < filled ? onColor : offColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BizText.style(
                12.5,
                700,
                color: captionColor,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BedPanel extends StatelessWidget {
  const _BedPanel({required this.vm, required this.floor});

  final AddTenantWizardViewModel vm;
  final FloorSlot floor;

  @override
  Widget build(BuildContext context) {
    final multiRoom = floor.rooms.length > 1;
    final selected = vm.selectedBed;
    final selectedRoom = vm.selectedRoom;

    return BizCard(
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, if (current != null) current],
          ),
          child: Column(
            key: ValueKey('beds-${floor.floor}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var r = 0; r < floor.rooms.length; r++) ...[
                if (r > 0) const SizedBox(height: 16),
                // The room only needs naming when the floor has several.
                if (multiRoom)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Room ${floor.rooms[r].number} · ${floor.rooms[r].subtitle}',
                      style: BizText.style(14, 600, color: BizColors.inkSoft),
                    ),
                  ),
                Wrap(
                  spacing: 8.5,
                  runSpacing: 8.5,
                  children: [
                    for (final bed in floor.rooms[r].beds)
                      _BedTile(
                        key: ValueKey('bed-${bed.roomId}-${bed.number}'),
                        bed: bed,
                        selected:
                            selected != null &&
                            selectedRoom?.id == bed.roomId &&
                            selected.number == bed.number,
                        onTap: () {
                          final ok = vm.selectBed(floor.rooms[r], bed);
                          if (!ok) HapticFeedback.mediumImpact();
                        },
                      ),
                  ],
                ),
              ],
              if (!multiRoom && floor.rooms.isEmpty) const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BedTile extends StatelessWidget {
  const _BedTile({
    super.key,
    required this.bed,
    required this.selected,
    required this.onTap,
  });

  final BedSlot bed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    BoxBorder? border;
    if (bed.occupied) {
      bg = BizColors.bedOccupied;
      fg = BizColors.bedOccupiedInk;
    } else if (selected) {
      bg = BizColors.green;
      fg = Colors.white;
    } else {
      bg = Colors.white;
      fg = BizColors.green;
      border = Border.all(color: BizColors.green, width: 1.6);
    }

    return Semantics(
      button: !bed.occupied,
      selected: selected,
      label:
          'Bed ${bed.number}, ${bed.occupied ? 'occupied' : (selected ? 'selected' : 'free')}',
      child: Pressable(
        scale: 0.94,
        haptic: false,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 76,
          height: 64,
          decoration: BoxDecoration(
            color: bg,
            border: border,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bed_outlined, size: 22, color: fg),
              const SizedBox(height: 3),
              Text(
                bed.label,
                style: BizText.style(14, 700, color: fg, height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color fill, Color? border, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(5),
            border: border == null
                ? null
                : Border.all(color: border, width: 1.6),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: BizText.style(14, 500, color: BizColors.inkSoft)),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          item(Colors.white, BizColors.green, 'Free'),
          item(BizColors.bedOccupied, null, 'Occupied'),
          item(BizColors.green, null, 'Selected'),
        ],
      ),
    );
  }
}
