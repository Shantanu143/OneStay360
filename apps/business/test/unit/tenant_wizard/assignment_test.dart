import 'package:business/presentation/view_models/tenant_wizard/assignment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/business/property/property_room_model.dart';

PropertyRoom room(
  String number,
  String floor,
  int sharing, {
  bool ac = false,
  String? gender,
}) => PropertyRoom(
  roomNumber: number,
  floor: floor,
  occupancyType: '$sharing',
  sharingType: sharing,
  hasAC: ac,
  gender: gender,
);

void main() {
  group('buildFloors', () {
    test('groups rooms by floor and orders floors numerically', () {
      final floors = buildFloors([
        room('301', '3', 2),
        room('101', '1', 2),
        room('201', '2', 2),
        room('1001', '10', 2),
      ], const {});

      expect(floors.map((f) => f.floor).toList(), ['1', '2', '3', '10']);
      expect(floors.first.label, 'Floor 1');
    });

    test('puts ground/non-numeric floors first, then numbers', () {
      final floors = buildFloors([
        room('A1', 'G', 2),
        room('101', '1', 2),
        room('B1', '0', 2),
      ], const {});

      expect(floors.map((f) => f.floor).toList(), ['0', 'G', '1']);
      expect(floors[0].label, 'Ground floor');
      expect(floors[1].label, 'Floor G');
    });

    test('creates one bed per sharing slot, numbered from 1', () {
      final floors = buildFloors([room('101', '1', 3)], const {});
      final beds = floors.single.rooms.single.beds;

      expect(beds.map((b) => b.number).toList(), ['1', '2', '3']);
      expect(beds.map((b) => b.index).toList(), [0, 1, 2]);
      expect(beds.every((b) => !b.occupied), isTrue);
    });

    test('marks occupied beds from the occupancy map', () {
      final floors = buildFloors(
        [room('101', '1', 3)],
        {
          '101': {'2'},
        },
      );
      final r = floors.single.rooms.single;

      expect(r.beds.map((b) => b.occupied).toList(), [false, true, false]);
      expect(r.freeBeds, 2);
      expect(r.totalBeds, 3);
    });

    test('floor totals add up and "last bed" means exactly one is free', () {
      final floors = buildFloors(
        [room('101', '1', 2), room('102', '1', 3)],
        {
          '101': {'1', '2'},
          '102': {'1', '2'},
        },
      );
      final f = floors.single;

      expect(f.totalBeds, 5);
      expect(f.freeBeds, 1);
      expect(f.isLastBed, isTrue);
      expect(f.hasFreeBeds, isTrue);
    });

    test('a full floor has no free beds and is not "last bed"', () {
      final floors = buildFloors(
        [room('101', '1', 1)],
        {
          '101': {'1'},
        },
      );

      expect(floors.single.freeBeds, 0);
      expect(floors.single.isLastBed, isFalse);
      expect(floors.single.hasFreeBeds, isFalse);
    });

    test('rooms within a floor are ordered naturally (2 before 10)', () {
      final floors = buildFloors([
        room('110', '1', 2),
        room('102', '1', 2),
        room('101', '1', 2),
      ], const {});

      expect(floors.single.rooms.map((r) => r.number).toList(), [
        '101',
        '102',
        '110',
      ]);
    });

    test('carries room traits for display and rent lookup', () {
      final r = buildFloors([
        room('101', '1', 2, ac: true, gender: 'Female'),
      ], const {}).single.rooms.single;

      expect(r.sharing, 2);
      expect(r.hasAC, isTrue);
      expect(r.gender, 'Female');
      expect(r.subtitle, '2-sharing · AC · Female');
    });

    test('a room with no sharing type defaults to a double', () {
      final r = buildFloors([
        PropertyRoom(roomNumber: '9', floor: '1', occupancyType: ''),
      ], const {}).single.rooms.single;

      expect(r.sharing, 2);
      expect(r.beds, hasLength(2));
    });

    test('totals across floors', () {
      final floors = buildFloors(
        [room('101', '1', 2), room('201', '2', 3)],
        {
          '101': {'1'},
        },
      );

      expect(totalBeds(floors), 5);
      expect(totalFreeBeds(floors), 4);
    });
  });
}
