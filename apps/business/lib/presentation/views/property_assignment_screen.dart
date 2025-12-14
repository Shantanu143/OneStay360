import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:models/business/property/property_model.dart';
import 'package:firebase_services/services/tenant_invitation_service.dart';
import 'package:firebase_services/services/property_room_service.dart';
import 'package:models/business/property/property_room_model.dart';

class PropertyAssignmentScreen extends StatefulWidget {
  final String businessId;
  final Function(String propertyId, String propertyName, String floor,
      String roomId, String roomNumber, int bedIndex, String bedNumber)?
      onAssignmentSelected;

  const PropertyAssignmentScreen({
    super.key,
    required this.businessId,
    this.onAssignmentSelected,
  });

  @override
  State<PropertyAssignmentScreen> createState() =>
      _PropertyAssignmentScreenState();
}

class _PropertyAssignmentScreenState
    extends State<PropertyAssignmentScreen> {
  final _invitationService = TenantInvitationService();
  List<Property> _properties = [];
  Property? _selectedProperty;
  String? _selectedFloor;
  String? _selectedRoomId;
  String? _selectedRoomNumber;
  int? _selectedBedIndex;
  bool _isLoading = true;
  Map<String, List<Map<String, dynamic>>> _roomsByFloor = {};
  Map<String, List<Map<String, dynamic>>> _bedsByRoom = {};
  late PropertyRoomService _roomService;

  @override
  void initState() {
    super.initState();
    _loadProperties();
    _roomService = PropertyRoomService();
  }

  Future<void> _loadProperties() async {
    try {
      final propertiesSnapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .collection('properties')
          .get();

      _properties = propertiesSnapshot.docs
          .map((doc) => Property.fromMap({...doc.data()}, doc.id))
          .toList();

      if (_properties.isNotEmpty && _selectedProperty == null) {
        _selectedProperty = _properties.first;
        _loadRoomsForProperty(_selectedProperty!);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading properties: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRoomsForProperty(Property property) async {
    setState(() {
      _selectedProperty = property;
      _selectedFloor = null;
      _selectedRoomId = null;
      _selectedRoomNumber = null;
      _selectedBedIndex = null;
      _roomsByFloor = {};
      _bedsByRoom = {};
    });

    try {
      // Get all active tenants for this property to check bed availability
      final tenantsSnapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .collection('tenants')
          .where('propertyId', isEqualTo: property.id)
          .where('status', isEqualTo: 'active')
          .get();

      final occupiedBeds = <String, Set<String>>{};
      for (final tenantDoc in tenantsSnapshot.docs) {
        final tenantData = tenantDoc.data();
        final roomId = tenantData['roomId']?.toString() ?? '';
        final bedId = tenantData['bedId']?.toString() ?? '';
        if (roomId.isNotEmpty && bedId.isNotEmpty) {
          occupiedBeds.putIfAbsent(roomId, () => <String>{}).add(bedId);
        }
      }

      // Prefer rooms from rooms subcollection (compatibility), fallback to legacy array
      List<PropertyRoom> roomsToUse = [];
      try {
        roomsToUse = await _roomService.getRoomsForProperty(widget.businessId, property.id!);
      } catch (e) {
        // ignore
      }
      if (roomsToUse.isEmpty) roomsToUse = property.rooms;

      // Organize rooms by floor
      final roomsByFloor = <String, List<Map<String, dynamic>>>{};
      for (final room in roomsToUse) {
        final floor = room.floor.toString();
        roomsByFloor.putIfAbsent(floor, () => []);

        final sharingType = room.sharingType ?? 2;
        final roomId = room.roomNumber;
        final occupiedBedsForRoom = occupiedBeds[roomId] ?? <String>{};

        // Check if room is empty
        final isRoomEmpty = occupiedBedsForRoom.isEmpty;

        // Get room gender
        final roomGender = await _invitationService.getRoomGender(
          businessId: widget.businessId,
          propertyId: property.id!,
          roomId: roomId,
        );

        // Create beds list
        final beds = <Map<String, dynamic>>[];
        for (int i = 0; i < sharingType; i++) {
          final bedNumber = (i + 1).toString();
          final isOccupied = occupiedBedsForRoom.contains(bedNumber);
          beds.add({
            'index': i,
            'number': bedNumber,
            'isOccupied': isOccupied,
          });
        }

        roomsByFloor[floor]!.add({
          'id': roomId,
          'number': room.roomNumber,
          'sharingType': sharingType,
          'hasAC': room.hasAC,
          'status': room.status,
          'beds': beds,
          'isRoomEmpty': isRoomEmpty,
          'roomGender': roomGender,
        });
      }

      setState(() {
        _roomsByFloor = roomsByFloor;
      });
    } catch (e) {
      print('Error loading rooms: $e');
    }
  }

  void _selectFloor(String floor) {
    setState(() {
      _selectedFloor = floor;
      _selectedRoomId = null;
      _selectedRoomNumber = null;
      _selectedBedIndex = null;
    });
  }

  Future<void> _selectRoom(
      String roomId, String roomNumber, Map<String, dynamic> roomData) async {
    setState(() {
      _selectedRoomId = roomId;
      _selectedRoomNumber = roomNumber;
      _selectedBedIndex = null;
      _bedsByRoom[roomId] = (roomData['beds'] as List<dynamic>?)
              ?.map((b) => b as Map<String, dynamic>)
              .toList() ??
          [];
    });
  }

  void _selectBed(int bedIndex, String bedNumber) {
    setState(() {
      _selectedBedIndex = bedIndex;
    });
  }

  

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_properties.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select Property')),
        body: const Center(
          child: Text('No properties available'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Property'),
      ),
      body: Column(
        children: [
          // Property Selection
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: DropdownButtonFormField<Property>(
              initialValue: _selectedProperty,
              decoration: const InputDecoration(
                labelText: 'Select PG/Property',
                border: OutlineInputBorder(),
              ),
              items: _properties
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.name),
                      ))
                  .toList(),
              onChanged: (property) {
                if (property != null) {
                  _loadRoomsForProperty(property);
                }
              },
            ),
          ),

          // Floor Selection
          if (_selectedProperty != null && _roomsByFloor.isNotEmpty)
            Expanded(
              child: Row(
                children: [
                  // Floor List
                  Container(
                    width: 100,
                    color: Colors.grey.shade50,
                    child: ListView.builder(
                      itemCount: _roomsByFloor.keys.length,
                      itemBuilder: (context, index) {
                        final floor = _roomsByFloor.keys.toList()[index];
                        final isSelected = _selectedFloor == floor;
                        return InkWell(
                          onTap: () => _selectFloor(floor),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            color: isSelected
                                ? Colors.blue.shade50
                                : Colors.transparent,
                            child: Text(
                              'Floor $floor',
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Rooms and Beds
                  Expanded(
                    child: _selectedFloor == null
                        ? const Center(
                            child: Text('Select a floor'),
                          )
                        : _buildRoomsView(),
                  ),
                ],
              ),
            ),

          // Confirm Button
          if (_selectedProperty != null &&
              _selectedFloor != null &&
              _selectedRoomId != null &&
              _selectedBedIndex != null)
            Container(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () {
                  if (widget.onAssignmentSelected != null) {
                    widget.onAssignmentSelected!(
                      _selectedProperty!.id!,
                      _selectedProperty!.name,
                      _selectedFloor!,
                      _selectedRoomId!,
                      _selectedRoomNumber!,
                      _selectedBedIndex!,
                      (_selectedBedIndex! + 1).toString(),
                    );
                  }
                  Navigator.pop(context, {
                    'propertyId': _selectedProperty!.id,
                    'propertyName': _selectedProperty!.name,
                    'floor': _selectedFloor,
                    'roomId': _selectedRoomId,
                    'roomNumber': _selectedRoomNumber,
                    'bedIndex': _selectedBedIndex,
                    'bedNumber': (_selectedBedIndex! + 1).toString(),
                  });
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Confirm Assignment'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoomsView() {
    final floorRooms = _roomsByFloor[_selectedFloor] ?? [];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: floorRooms.length,
      itemBuilder: (context, index) {
        final room = floorRooms[index];
        final roomId = room['id'] as String;
        final roomNumber = room['number'] as String;
        final isSelected = _selectedRoomId == roomId;
        final isRoomEmpty = room['isRoomEmpty'] as bool? ?? true;
        final roomGender = room['roomGender']?.toString();
        final beds = room['beds'] as List<dynamic>? ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            initiallyExpanded: isSelected,
            title: Text(
              'Room $roomNumber',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              '${beds.length} beds • ${isRoomEmpty ? "Empty" : "Occupied"}'
                  '${roomGender != null ? " • $roomGender" : ""}',
            ),
            onExpansionChanged: (expanded) {
              if (expanded) {
                _selectRoom(roomId, roomNumber, room);
              }
            },
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: beds.map((bed) {
                    final bedIndex = bed['index'] as int;
                    final bedNumber = bed['number'] as String;
                    final isOccupied = bed['isOccupied'] as bool? ?? false;
                    final isBedSelected = _selectedBedIndex == bedIndex;

                    return InkWell(
                      onTap: isOccupied
                          ? null
                          : () => _selectBed(bedIndex, bedNumber),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isOccupied
                              ? Colors.grey.shade300
                              : isBedSelected
                                  ? Colors.blue
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: isBedSelected
                              ? Border.all(color: Colors.blue, width: 2)
                              : null,
                        ),
                        child: Text(
                          'Bed $bedNumber',
                          style: TextStyle(
                            color: isOccupied
                                ? Colors.grey
                                : isBedSelected
                                    ? Colors.white
                                    : Colors.black87,
                            fontWeight: isBedSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}




