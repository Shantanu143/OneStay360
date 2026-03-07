// lib/presentation/views/business/edit_property_screen.dart
// Comprehensive property editing screen with form validation and image management

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onestay360/presentation/views/business/widgets/business_scaffold.dart';

class EditPropertyScreen extends StatefulWidget {
  final String propertyId;

  const EditPropertyScreen({
    super.key,
    required this.propertyId,
  });

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;

  // Form controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Property data
  String _selectedPropertyType = 'PG';
  List<String> _selectedAmenities = [];
  List<String> _propertyImages = [];
  List<Map<String, dynamic>> _rooms = [];

  final List<String> _propertyTypes = ['PG', 'Hostel', 'Apartment', 'Villa'];
  final List<String> _availableAmenities = [
    'WiFi',
    'AC',
    'Laundry',
    'Parking',
    'Security',
    'Housekeeping',
    'Meals',
    'Power Backup',
    'Gym',
    'Swimming Pool',
    'Garden',
    'Elevator'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPropertyData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadPropertyData() async {
    // Simulate loading existing property data
    await Future.delayed(const Duration(seconds: 1));

    // Sample data (replace with actual data fetching)
    setState(() {
      _nameController.text = 'Greenview Residency';
      _addressController.text = '12 Park Street, Koramangala';
      _cityController.text = 'Bengaluru';
      _stateController.text = 'Karnataka';
      _pincodeController.text = '560034';
      _descriptionController.text = 'A premium PG accommodation with modern amenities and excellent connectivity to major IT hubs.';
      _selectedPropertyType = 'PG';
      _selectedAmenities = ['WiFi', 'AC', 'Laundry', 'Parking', 'Security'];
      _propertyImages = [
        'https://picsum.photos/seed/greenview1/800/600',
        'https://picsum.photos/seed/greenview2/800/600',
      ];
      _rooms = [
        {
          'id': 'r1',
          'number': '101',
          'type': 'Single',
          'rent': 8500,
          'deposit': 17000,
          'beds': 1,
        },
        {
          'id': 'r2',
          'number': '102',
          'type': 'Double',
          'rent': 6500,
          'deposit': 13000,
          'beds': 2,
        },
      ];
      _isLoading = false;
    });
  }

  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Simulate saving
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Property updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating property: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return BusinessScaffold(
        currentTab: BusinessTab.properties,
        //titleText: 'Edit Property',
        showBackButton: true,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return BusinessScaffold(
      currentTab: BusinessTab.properties,
      //titleText: 'Edit Property',
      showBackButton: true,
      floatingActionButton: FloatingActionButton(
        onPressed: _isSaving ? null : _saveProperty,
        child: _isSaving
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : const Icon(Icons.save),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicInfoTab(),
                  _buildImagesTab(),
                  _buildRoomsTab(),
                  _buildAmenitiesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.teal.shade600,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.teal.shade600,
        tabs: const [
          Tab(text: 'Basic Info'),
          Tab(text: 'Images'),
          Tab(text: 'Rooms'),
          Tab(text: 'Amenities'),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormCard(
            title: 'Property Details',
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Property Name *',
                  hintText: 'Enter property name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Property name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedPropertyType,
                decoration: const InputDecoration(
                  labelText: 'Property Type *',
                ),
                items: _propertyTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPropertyType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter property description',
                ),
                maxLines: 3,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildFormCard(
            title: 'Address Information',
            children: [
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address *',
                  hintText: 'Enter complete address',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Address is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City *',
                        hintText: 'Enter city',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'City is required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: const InputDecoration(
                        labelText: 'State *',
                        hintText: 'Enter state',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'State is required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pincodeController,
                decoration: const InputDecoration(
                  labelText: 'Pincode *',
                  hintText: 'Enter pincode',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Pincode is required';
                  }
                  if (value.length != 6) {
                    return 'Pincode must be 6 digits';
                  }
                  return null;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormCard(
            title: 'Property Images',
            children: [
              const Text(
                'Add high-quality images of your property to attract more tenants.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: _propertyImages.length + 1,
                itemBuilder: (context, index) {
                  if (index == _propertyImages.length) {
                    return _buildAddImageCard();
                  }
                  return _buildImageCard(_propertyImages[index], index);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageCard() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Implement image picker
        _addImage();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 32, color: Colors.grey.shade600),
            const SizedBox(height: 8),
            Text(
              'Add Image',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(String imageUrl, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _removeImage(index);
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rooms Configuration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addRoom,
                icon: const Icon(Icons.add),
                label: const Text('Add Room'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _rooms.length,
            itemBuilder: (context, index) {
              return _buildRoomCard(_rooms[index], index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Room ${room['number']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeRoom(index),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: room['number'],
                  decoration: const InputDecoration(
                    labelText: 'Room Number',
                    isDense: true,
                  ),
                  onChanged: (value) {
                    room['number'] = value;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: room['type'],
                  decoration: const InputDecoration(
                    labelText: 'Room Type',
                    isDense: true,
                  ),
                  items: ['Single', 'Double', 'Triple', 'Dormitory'].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      room['type'] = value!;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: room['rent'].toString(),
                  decoration: const InputDecoration(
                    labelText: 'Monthly Rent (₹)',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    room['rent'] = int.tryParse(value) ?? 0;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: room['deposit'].toString(),
                  decoration: const InputDecoration(
                    labelText: 'Security Deposit (₹)',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    room['deposit'] = int.tryParse(value) ?? 0;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmenitiesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormCard(
            title: 'Available Amenities',
            children: [
              const Text(
                'Select all amenities available at your property.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableAmenities.map((amenity) {
                  final isSelected = _selectedAmenities.contains(amenity);
                  return FilterChip(
                    label: Text(amenity),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedAmenities.add(amenity);
                        } else {
                          _selectedAmenities.remove(amenity);
                        }
                      });
                    },
                    selectedColor: Colors.teal.shade100,
                    checkmarkColor: Colors.teal.shade700,
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  void _addImage() {
    // Simulate adding an image
    setState(() {
      _propertyImages.add('https://picsum.photos/seed/new${_propertyImages.length}/800/600');
    });
  }

  void _removeImage(int index) {
    setState(() {
      _propertyImages.removeAt(index);
    });
  }

  void _addRoom() {
    setState(() {
      _rooms.add({
        'id': 'r${_rooms.length + 1}',
        'number': '${_rooms.length + 101}',
        'type': 'Single',
        'rent': 0,
        'deposit': 0,
        'beds': 1,
      });
    });
  }

  void _removeRoom(int index) {
    setState(() {
      _rooms.removeAt(index);
    });
  }
}