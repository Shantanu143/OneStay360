import 'package:business/presentation/view_models/tenant_wizard/assignment_data_source.dart';
import 'package:models/business/property/property_model.dart';
import 'package:models/business/property/property_room_model.dart';

PropertyRoom room(
  String number,
  String floor,
  int sharing, {
  bool ac = false,
}) => PropertyRoom(
  roomNumber: number,
  floor: floor,
  occupancyType: '$sharing',
  sharingType: sharing,
  hasAC: ac,
);

class FakeAssignments implements AssignmentDataSource {
  FakeAssignments({
    required this.props,
    required this.rooms,
    this.occupied = const {},
  });

  final List<Property> props;
  final Map<String, List<PropertyRoom>> rooms;
  Map<String, Map<String, Set<String>>> occupied;
  Object? failure;
  int roomLoads = 0;

  @override
  Future<List<Property>> propertiesFor(String businessId) async {
    if (failure != null) throw failure!;
    return props;
  }

  @override
  Future<List<PropertyRoom>> roomsFor(
    String businessId,
    Property property,
  ) async {
    roomLoads++;
    return rooms[property.id] ?? const [];
  }

  @override
  Future<Map<String, Set<String>>> occupiedBeds(
    String businessId,
    String propertyId,
  ) async => occupied[propertyId] ?? const {};
}
