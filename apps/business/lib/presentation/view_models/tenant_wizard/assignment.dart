// lib/presentation/view_models/tenant_wizard/assignment.dart
//
// Floors -> rooms -> beds, derived from a property's rooms and which beds are
// taken. Pure data (no Firebase) so it can be tested directly.
import 'package:models/business/property/property_room_model.dart';

class BedSlot {
  const BedSlot({
    required this.roomId,
    required this.roomNumber,
    required this.number,
    required this.index,
    required this.occupied,
  });

  final String roomId;
  final String roomNumber;

  /// "1", "2"... (shown as B1, B2).
  final String number;
  final int index;
  final bool occupied;

  String get label => 'B$number';
}

class RoomSlot {
  const RoomSlot({
    required this.id,
    required this.number,
    required this.floor,
    required this.sharing,
    required this.hasAC,
    required this.beds,
    this.gender,
  });

  final String id;
  final String number;
  final String floor;
  final int sharing;
  final bool hasAC;
  final String? gender;
  final List<BedSlot> beds;

  int get totalBeds => beds.length;
  int get freeBeds => beds.where((b) => !b.occupied).length;

  /// "2-sharing · AC · Female"
  String get subtitle => [
    '$sharing-sharing',
    if (hasAC) 'AC',
    if (gender != null && gender!.isNotEmpty) gender!,
  ].join(' · ');
}

class FloorSlot {
  const FloorSlot({required this.floor, required this.rooms});

  final String floor;
  final List<RoomSlot> rooms;

  String get label {
    if (floor == '0') return 'Ground floor';
    return 'Floor $floor';
  }

  int get totalBeds => rooms.fold(0, (n, r) => n + r.totalBeds);
  int get freeBeds => rooms.fold(0, (n, r) => n + r.freeBeds);
  bool get hasFreeBeds => freeBeds > 0;

  /// Exactly one bed left: worth nudging the owner about.
  bool get isLastBed => freeBeds == 1;
}

int totalBeds(List<FloorSlot> floors) =>
    floors.fold(0, (n, f) => n + f.totalBeds);
int totalFreeBeds(List<FloorSlot> floors) =>
    floors.fold(0, (n, f) => n + f.freeBeds);

/// [occupied] maps a room id (its number) to the bed numbers already taken.
List<FloorSlot> buildFloors(
  List<PropertyRoom> rooms,
  Map<String, Set<String>> occupied,
) {
  final byFloor = <String, List<RoomSlot>>{};

  for (final room in rooms) {
    final sharing = (room.sharingType == null || room.sharingType! < 1)
        ? 2
        : room.sharingType!;
    final taken = occupied[room.roomNumber] ?? const <String>{};
    final beds = [
      for (var i = 0; i < sharing; i++)
        BedSlot(
          roomId: room.roomNumber,
          roomNumber: room.roomNumber,
          number: '${i + 1}',
          index: i,
          occupied: taken.contains('${i + 1}'),
        ),
    ];
    byFloor
        .putIfAbsent(room.floor, () => [])
        .add(
          RoomSlot(
            id: room.roomNumber,
            number: room.roomNumber,
            floor: room.floor,
            sharing: sharing,
            hasAC: room.hasAC,
            gender: room.gender,
            beds: beds,
          ),
        );
  }

  final floors = [
    for (final entry in byFloor.entries)
      FloorSlot(
        floor: entry.key,
        rooms: entry.value..sort((a, b) => naturalCompare(a.number, b.number)),
      ),
  ]..sort((a, b) => _floorOrder(a.floor, b.floor));

  return floors;
}

int _floorOrder(String a, String b) {
  final an = int.tryParse(a);
  final bn = int.tryParse(b);
  if (an != null && bn != null) return an.compareTo(bn);
  // "0" (ground) first, then other labels, then numbers: 0, G, 1, 2 ...
  if (a == '0') return -1;
  if (b == '0') return 1;
  if (an == null && bn != null) return -1;
  if (an != null && bn == null) return 1;
  return a.compareTo(b);
}

/// Compares "101" < "102" < "110" and "A2" < "A10".
int naturalCompare(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final pa = re.allMatches(a).map((m) => m.group(0)!).toList();
  final pb = re.allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final x = pa[i];
    final y = pb[i];
    final xn = int.tryParse(x);
    final yn = int.tryParse(y);
    final c = (xn != null && yn != null) ? xn.compareTo(yn) : x.compareTo(y);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}
