// lib/presentation/views/property_form/property_form_steps.dart
//
// The steps of the property form (add and edit), drawn with the design
// system on top of AddPropertyViewModel.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:models/business/property/meal_enum.dart';

import '../../design/components/biz_button.dart';
import '../../design/components/biz_card.dart';
import '../../design/components/biz_chips.dart';
import '../../design/components/biz_section_label.dart';
import '../../design/components/biz_text_field.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../view_models/add_property_viewmodel.dart';
import 'property_form_checks.dart';

/// A white card holding a group of fields, with a small label above.
class FormGroup extends StatelessWidget {
  const FormGroup({super.key, this.label, required this.children, this.padding = const EdgeInsets.all(16)});

  final String? label;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) BizSectionLabel(label!),
          BizCard(
            padding: padding,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ],
      ),
    );
  }
}

/// A label with a switch on the right.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 21, color: value ? BizColors.green : BizColors.inkSoft),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: BizText.bodyStrong),
                if (subtitle != null) Text(subtitle!, style: BizText.rowSubtitle),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

Widget _gap([double h = 14]) => SizedBox(height: h);

final _digits = [FilteringTextInputFormatter.digitsOnly];

/// Name, city, address, floors, description.
class BasicsStep extends StatelessWidget {
  const BasicsStep({super.key, required this.vm, this.cityLocked = false});

  final AddPropertyViewModel vm;

  /// The city can't change once a property is listed (its id carries it).
  final bool cityLocked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormGroup(label: 'PROPERTY', children: [
          BizTextField(
            label: 'Property name',
            fieldKey: const Key('property-name'),
            controller: vm.propertyNameController,
            hint: 'Green Nest Co-living',
            textCapitalization: TextCapitalization.words,
          ),
          _gap(),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(cityLocked ? 'City (can\'t be changed)' : 'City', style: BizText.fieldLabel),
          ),
          IgnorePointer(
            ignoring: cityLocked,
            child: Opacity(
              opacity: cityLocked ? 0.6 : 1,
              child: BizChoiceWrap<String>(
                options: vm.cities.keys.toList(),
                selected: vm.selectedCity,
                onChanged: vm.setCity,
                onCard: true,
              ),
            ),
          ),
          _gap(),
          BizTextField(
            label: 'Full address',
            fieldKey: const Key('property-address'),
            controller: vm.addressController,
            hint: 'Building, street, area',
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          _gap(),
          Row(
            children: [
              Expanded(
                child: BizTextField(
                  label: 'PIN code',
                  fieldKey: const Key('property-pincode'),
                  controller: vm.pincodeController,
                  hint: '411045',
                  keyboardType: TextInputType.number,
                  inputFormatters: [..._digits, LengthLimitingTextInputFormatter(6)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BizTextField(
                  label: 'Floors above ground',
                  fieldKey: const Key('property-floors'),
                  controller: vm.numberOfFloorsController,
                  hint: '2',
                  keyboardType: TextInputType.number,
                  inputFormatters: [..._digits, LengthLimitingTextInputFormatter(2)],
                  onChanged: (_) => vm.fieldsChanged(),
                ),
              ),
            ],
          ),
        ]),
        FormGroup(label: 'FOR TENANTS', children: [
          BizTextField(
            label: 'Nearby landmarks (optional)',
            controller: vm.landmarksController,
            hint: 'Near Baner metro, opposite D-Mart',
            textCapitalization: TextCapitalization.sentences,
          ),
          _gap(),
          BizTextField(
            label: 'About the property (optional)',
            controller: vm.descriptionController,
            hint: 'What makes it a good place to live',
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
          _gap(),
          BizTextField(
            label: 'Google Maps link (optional)',
            controller: vm.googleMapsLinkController,
            hint: 'https://maps.app.goo.gl/…',
            keyboardType: TextInputType.url,
          ),
        ]),
      ],
    );
  }
}

/// Photos tenants see first.
class PhotosStep extends StatelessWidget {
  const PhotosStep({super.key, required this.vm, this.existing = const [], this.onRemoveExisting});

  final AddPropertyViewModel vm;

  /// Already uploaded photos (editing).
  final List<String> existing;
  final ValueChanged<String>? onRemoveExisting;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      for (final url in existing)
        _Photo(
          image: NetworkImage(url),
          onRemove: onRemoveExisting == null ? null : () => onRemoveExisting!(url),
        ),
      for (var i = 0; i < vm.selectedImages.length; i++)
        _Photo(image: FileImage(File(vm.selectedImages[i].path)), onRemove: () => vm.removeImageAt(i)),
      Pressable(
        onTap: vm.isUploadingImages ? null : () => vm.pickImages(),
        semanticLabel: 'Add photos',
        child: Container(
          decoration: BoxDecoration(
            color: BizColors.page,
            borderRadius: BorderRadius.circular(BizRadius.control),
            border: Border.all(color: BizColors.fieldBorder, width: 1.4),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, color: BizColors.green, size: 28),
              SizedBox(height: 6),
              Text('Add photos'),
            ],
          ),
        ),
      ),
    ];
    return FormGroup(
      label: 'PHOTOS',
      children: [
        Text(
          'Bright photos of rooms, washrooms and common areas get more requests. The first photo is the cover.',
          style: BizText.rowSubtitle.copyWith(height: 1.4),
        ),
        _gap(),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: tiles,
        ),
      ],
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.image, this.onRemove});

  final ImageProvider image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(BizRadius.control),
          child: Image(
            image: image,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(color: BizColors.photo),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 4,
            right: 4,
            child: Pressable(
              onTap: onRemove,
              semanticLabel: 'Remove photo',
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: BizColors.ink.withValues(alpha: 0.7), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

/// Sharing, rent per sharing (AC / non-AC), deposit and charges.
class PricingStep extends StatelessWidget {
  const PricingStep({super.key, required this.vm});

  final AddPropertyViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormGroup(label: 'SHARING', children: [
          Text('Up to how many people share a room?', style: BizText.bodyStrong),
          _gap(10),
          BizChoiceWrap<int>(
            options: const [1, 2, 3, 4, 5, 6],
            selected: vm.currentMaxSharing == 0 ? null : vm.currentMaxSharing,
            labelOf: (n) => n == 1 ? 'Single only' : 'Up to $n',
            onChanged: (n) => vm.maxSharingController.text = '$n',
            onCard: true,
          ),
        ]),
        if (vm.currentMaxSharing > 0)
          FormGroup(label: 'MONTHLY RENT PER PERSON', children: [
            for (var i = 0; i < vm.sharingRows.length; i++) ...[
              if (i > 0) const Divider(height: 28),
              Text(vm.sharingLabel(vm.sharingRows[i]['sharing'] as int), style: BizText.cardTitle),
              _gap(10),
              Row(
                children: [
                  Expanded(
                    child: BizTextField(
                      label: 'Non-AC (₹)',
                      fieldKey: Key('price-${vm.sharingRows[i]['sharing']}-nonac'),
                      controller: vm.sharingRows[i]['nonAcController'] as TextEditingController,
                      hint: '8000',
                      keyboardType: TextInputType.number,
                      inputFormatters: _digits,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BizTextField(
                      label: 'AC (₹)',
                      fieldKey: Key('price-${vm.sharingRows[i]['sharing']}-ac'),
                      controller: vm.sharingRows[i]['acController'] as TextEditingController,
                      hint: '10000',
                      keyboardType: TextInputType.number,
                      inputFormatters: _digits,
                    ),
                  ),
                ],
              ),
            ],
            _gap(8),
            Text('Leave a box empty if you don\'t offer that option.', style: BizText.caption),
          ]),
        FormGroup(label: 'ONE-TIME CHARGES', children: [
          Row(
            children: [
              Expanded(
                child: BizTextField(
                  label: 'Security deposit (₹)',
                  controller: vm.securityDepositController,
                  hint: '10000',
                  keyboardType: TextInputType.number,
                  inputFormatters: _digits,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BizTextField(
                  label: 'Maintenance (₹)',
                  controller: vm.oneTimeMaintenanceChargeController,
                  hint: '1000',
                  keyboardType: TextInputType.number,
                  inputFormatters: _digits,
                ),
              ),
            ],
          ),
          _gap(8),
          SwitchRow(
            title: 'Take maintenance from the deposit',
            value: vm.isMaintenanceDeductedFromDeposit,
            onChanged: vm.setMaintenanceDeducted,
          ),
        ]),
      ],
    );
  }
}

/// The rooms, each with its floor, sharing and AC.
class RoomsStep extends StatelessWidget {
  const RoomsStep({super.key, required this.vm});

  final AddPropertyViewModel vm;

  @override
  Widget build(BuildContext context) {
    final floors = PropertyFormChecks.floorOptions(int.tryParse(vm.numberOfFloorsController.text.trim()) ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _Stat(label: 'Rooms', value: '${vm.getTotalRooms()}')),
            const SizedBox(width: 10),
            Expanded(child: _Stat(label: 'Beds', value: '${vm.getTotalBeds()}')),
          ],
        ),
        _gap(18),
        for (var i = 0; i < vm.roomDetails.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RoomCard(vm: vm, index: i, floors: floors),
          ),
        BizButton(
          label: vm.roomDetails.isEmpty ? 'Add your first room' : 'Add another room',
          icon: Icons.add_rounded,
          kind: BizButtonKind.outline,
          size: BizButtonSize.medium,
          onPressed: vm.addRoom,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return BizCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: BizText.statCaption),
          Text(value, style: BizText.bigNumber),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.vm, required this.index, required this.floors});

  final AddPropertyViewModel vm;
  final int index;
  final List<String> floors;

  @override
  Widget build(BuildContext context) {
    final room = vm.roomDetails[index];
    final number = room['roomNumberController'] as TextEditingController;
    final expanded = vm.expandedRoomIndex == index;
    final summary = [
      if (room['floor'] != null) PropertyFormChecks.floorLabel(room['floor'] as String),
      if (room['sharingType'] != null) vm.sharingLabel(room['sharingType'] as int),
      (room['hasAC'] == true) ? 'AC' : 'Non-AC',
    ].join(' · ');

    return BizCard(
      padding: const EdgeInsets.all(16),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Pressable(
              scale: 0.99,
              onTap: () => vm.expandedRoomIndex = expanded ? null : index,
              semanticLabel: 'Room ${index + 1}',
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: BizColors.greenTint, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.meeting_room_outlined, size: 20, color: BizColors.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(number.text.trim().isEmpty ? 'Room ${index + 1}' : 'Room ${number.text.trim()}',
                            style: BizText.rowTitle),
                        Text(summary, style: BizText.rowSubtitle),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove room',
                    icon: const Icon(Icons.delete_outline_rounded, color: BizColors.dangerInk),
                    onPressed: () => vm.removeRoom(index),
                  ),
                  Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: BizColors.chevron),
                ],
              ),
            ),
            if (expanded) ...[
              _gap(),
              BizTextField(
                label: 'Room number',
                fieldKey: Key('room-$index-number'),
                controller: number,
                hint: '101',
                onChanged: (_) => vm.fieldsChanged(),
              ),
              _gap(),
              Text('Floor', style: BizText.fieldLabel),
              _gap(8),
              BizChoiceWrap<String>(
                options: floors,
                selected: room['floor'] as String?,
                labelOf: (f) => f == 'Ground' ? 'Ground' : PropertyFormChecks.floorLabel(f).replaceAll(' floor', ''),
                onChanged: (f) => vm.setRoomField(index, 'floor', f),
                onCard: true,
              ),
              _gap(),
              Text('Beds in this room', style: BizText.fieldLabel),
              _gap(8),
              BizChoiceWrap<int>(
                options: [for (var s = 1; s <= vm.currentMaxSharing; s++) s],
                selected: room['sharingType'] as int?,
                labelOf: (s) => vm.sharingLabel(s),
                onChanged: (s) => vm.setRoomField(index, 'sharingType', s),
                onCard: true,
              ),
              SwitchRow(
                title: 'Air-conditioned',
                icon: Icons.ac_unit_rounded,
                value: room['hasAC'] as bool? ?? false,
                onChanged: (v) => vm.setRoomField(index, 'hasAC', v),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _amenities = [
  ('wifi', 'Wi-Fi', Icons.wifi_rounded),
  ('ac', 'AC', Icons.ac_unit_rounded),
  ('food', 'Meals', Icons.restaurant_rounded),
  ('laundry', 'Laundry', Icons.local_laundry_service_rounded),
  ('housekeeping', 'Housekeeping', Icons.cleaning_services_rounded),
  ('geyser', 'Hot water', Icons.hot_tub_rounded),
  ('powerBackup', 'Power backup', Icons.bolt_rounded),
  ('parking', 'Parking', Icons.local_parking_rounded),
  ('cctv', 'CCTV', Icons.videocam_rounded),
];

bool _amenityOn(AddPropertyViewModel vm, String key) => switch (key) {
      'wifi' => vm.hasWifi,
      'ac' => vm.hasAC,
      'food' => vm.hasFood,
      'laundry' => vm.hasLaundry,
      'housekeeping' => vm.hasHousekeeping,
      'geyser' => vm.hasGeyser,
      'powerBackup' => vm.hasPowerBackup,
      'parking' => vm.hasParking,
      'cctv' => vm.hasCCTV,
      _ => false,
    };

/// Amenities and, with meals, the weekly food plan.
class AmenitiesStep extends StatelessWidget {
  const AmenitiesStep({super.key, required this.vm});

  final AddPropertyViewModel vm;

  @override
  Widget build(BuildContext context) {
    final allOn = _amenities.every((a) => _amenityOn(vm, a.$1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormGroup(label: 'AMENITIES', children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.05,
            children: [
              for (final (key, label, icon) in _amenities)
                _Toggle(
                  label: label,
                  icon: icon,
                  on: _amenityOn(vm, key),
                  onTap: () => vm.updateAmenity(key, !_amenityOn(vm, key)),
                ),
            ],
          ),
          _gap(8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => vm.toggleSelectAllAmenities(!allOn),
              child: Text(allOn ? 'Clear all' : 'Select all'),
            ),
          ),
        ]),
        if (vm.hasFood) FoodPlanCard(vm: vm),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.icon, required this.on, required this.onTap});

  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.94,
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: on ? BizColors.greenTint : BizColors.page,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? BizColors.green : Colors.transparent, width: 1.6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: on ? BizColors.green : BizColors.inkSoft, size: 24),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: BizText.style(12.5, 600, color: on ? BizColors.ink : BizColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}

/// Which meals are served on which day, with quick presets.
class FoodPlanCard extends StatelessWidget {
  const FoodPlanCard({super.key, required this.vm});

  final AddPropertyViewModel vm;

  @override
  Widget build(BuildContext context) {
    const meals = [(Meal.breakfast, 'B'), (Meal.lunch, 'L'), (Meal.dinner, 'D')];
    return FormGroup(label: 'FOOD PLAN', children: [
      Row(
        children: [
          Expanded(
            child: BizButton(
              label: 'All meals daily',
              kind: BizButtonKind.tonal,
              size: BizButtonSize.small,
              onPressed: vm.applyPresetAllMealsAllDays,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: BizButton(
              label: 'Weekday B+D',
              kind: BizButtonKind.tonal,
              size: BizButtonSize.small,
              onPressed: vm.applyPresetWeekdayBF_DinnerWeekendAll,
            ),
          ),
        ],
      ),
      _gap(),
      for (final day in vm.days)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 92, child: Text(day, style: BizText.bodyStrong)),
              const Spacer(),
              for (final (meal, letter) in meals) ...[
                const SizedBox(width: 8),
                Pressable(
                  scale: 0.9,
                  onTap: () => vm.toggleMeal(day, meal),
                  semanticLabel: '$day ${meal.name}',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 40,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: vm.weeklyMeals[day]!.contains(meal) ? BizColors.green : BizColors.page,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      letter,
                      style: BizText.style(14, 700,
                          color: vm.weeklyMeals[day]!.contains(meal) ? Colors.white : BizColors.inkSoft),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      _gap(6),
      Text('B breakfast · L lunch · D dinner', style: BizText.caption),
      _gap(),
      BizTextField(
        label: 'Food notes (optional)',
        controller: vm.foodNotesController,
        hint: 'Veg only, Sunday special…',
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
      ),
    ]);
  }
}

/// Who can stay and house rules.
class RulesStep extends StatelessWidget {
  const RulesStep({super.key, required this.vm});

  final AddPropertyViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormGroup(label: 'WHO CAN STAY', children: [
          BizChoiceWrap<String>(
            options: const ['Male', 'Female', 'Co-ed'],
            selected: vm.genderAllowed,
            labelOf: (g) => switch (g) { 'Male' => 'Boys', 'Female' => 'Girls', _ => 'Co-ed' },
            onChanged: vm.setGender,
            onCard: true,
          ),
        ]),
        FormGroup(label: 'HOUSE RULES', padding: const EdgeInsets.fromLTRB(16, 10, 8, 10), children: [
          SwitchRow(title: 'Curfew', icon: Icons.nightlight_round, value: vm.hasCurfew, onChanged: (v) => vm.updateRule('curfew', v)),
          SwitchRow(title: 'Visitors allowed', icon: Icons.people_outline_rounded, value: vm.visitorsAllowed, onChanged: (v) => vm.updateRule('visitors', v)),
          SwitchRow(title: 'Smoking allowed', icon: Icons.smoking_rooms_rounded, value: vm.smokingAllowed, onChanged: (v) => vm.updateRule('smoking', v)),
          SwitchRow(title: 'Alcohol allowed', icon: Icons.local_bar_rounded, value: vm.alcoholAllowed, onChanged: (v) => vm.updateRule('alcohol', v)),
        ]),
        FormGroup(label: 'NOTICE PERIOD', children: [
          BizTextField(
            label: 'Days of notice before moving out',
            fieldKey: const Key('property-notice'),
            controller: vm.noticePeriodController,
            hint: '30',
            keyboardType: TextInputType.number,
            inputFormatters: [..._digits, LengthLimitingTextInputFormatter(3)],
          ),
        ]),
      ],
    );
  }
}

/// Snapshots the view model for [PropertyFormChecks].
extension PropertyFormDraft on AddPropertyViewModel {
  String? problemAt(PropertyFormStep step) => switch (step) {
        PropertyFormStep.basics => PropertyFormChecks.basics(
            name: propertyNameController.text,
            city: selectedCity,
            address: addressController.text,
            pincode: pincodeController.text,
            floors: numberOfFloorsController.text,
          ),
        PropertyFormStep.photos => null,
        PropertyFormStep.pricing => PropertyFormChecks.pricing(
            maxSharing: currentMaxSharing,
            prices: [
              for (final row in sharingRows)
                ((row['nonAcController'] as TextEditingController).text, (row['acController'] as TextEditingController).text),
            ],
          ),
        PropertyFormStep.rooms => PropertyFormChecks.rooms([
            for (final r in roomDetails)
              (
                number: (r['roomNumberController'] as TextEditingController).text,
                floor: r['floor'] as String?,
                sharing: r['sharingType'] as int?,
              ),
          ], maxSharing: currentMaxSharing),
        PropertyFormStep.amenities =>
          PropertyFormChecks.food(hasFood: hasFood, anyMeal: weeklyMeals.values.any((s) => s.isNotEmpty)),
        PropertyFormStep.rules => PropertyFormChecks.rules(gender: genderAllowed),
      };
}

enum PropertyFormStep {
  basics('Basics'),
  photos('Photos'),
  pricing('Pricing'),
  rooms('Rooms'),
  amenities('Amenities'),
  rules('Rules');

  const PropertyFormStep(this.label);

  final String label;
}
