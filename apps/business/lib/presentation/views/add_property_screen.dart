// lib/presentation/views/business/add_property_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../view_models/add_property_viewmodel.dart';
import 'package:models/business/property/meal_enum.dart';
import 'widgets/business_scaffold.dart';

class AddPropertyScreen extends StatefulWidget {
  final String businessId;
  final String businessName;
  final String businessPhone;

  const AddPropertyScreen({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.businessPhone,
  });

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, .1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();

    debugPrint('🎯 AddPropertyScreen initialized with:');
    debugPrint('  Business ID: ${widget.businessId}');
    debugPrint('  Business Name: ${widget.businessName}');
    debugPrint('  Business Phone: ${widget.businessPhone}');
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Text(
          title,
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800
          )
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String hint = '',
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
    Color primaryColor = Colors.teal,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: primaryColor) : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade600),
          hintStyle: TextStyle(color: Colors.grey.shade400),
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    IconData? icon,
    String? Function(T?)? validator,
    Color primaryColor = Colors.teal,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: primaryColor) : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade600),
        ),
        dropdownColor: Colors.white,
        style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
        iconEnabledColor: primaryColor,
      ),
    );
  }

  Widget _amenityTile(String title, bool value, IconData icon, void Function(bool v) onChanged, Color primaryColor) {
    return CheckboxListTile(
      title: Row(
        children: [
          Icon(icon, color: primaryColor, size: 20),
          const SizedBox(width: 12),
          Text(title),
        ],
      ),
      value: value,
      onChanged: (val) => onChanged(val ?? false),
      activeColor: primaryColor,
      checkColor: Colors.white,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildFoodPlanSection(AddPropertyViewModel viewModel, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(left: 0, top: 8, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Food Plan',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade800
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      OutlinedButton(
                        onPressed: viewModel.applyPresetAllMealsAllDays,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        child: const Text('All meals', style: TextStyle(fontSize: 12)),
                      ),
                      OutlinedButton(
                        onPressed: viewModel.applyPresetWeekdayBF_DinnerWeekendAll,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        child: const Text('Weekdays BF+D', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _legendChip('B', Colors.amber.shade600, 'Breakfast'),
                const SizedBox(width: 8),
                _legendChip('L', Colors.orange.shade600, 'Lunch'),
                const SizedBox(width: 8),
                _legendChip('D', Colors.red.shade600, 'Dinner'),
              ],
            ),
            const SizedBox(height: 12),
            ...viewModel.days.map((day) => _buildDayRow(day, viewModel, primaryColor)),
            const SizedBox(height: 12),
            _buildTextField(
              controller: viewModel.foodNotesController,
              label: 'Food Notes (optional)',
              hint: 'e.g., Non-veg twice a week, special Sunday menu',
              icon: Icons.note_alt_outlined,
              maxLines: 2,
              primaryColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendChip(String label, Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Chip(
        label: Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: color,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
    );
  }

  Widget _buildDayRow(String day, AddPropertyViewModel viewModel, Color primaryColor) {
    final set = viewModel.weeklyMeals[day]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              day.length > 6 ? day.substring(0, 6) : day,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _mealFilterChip(
                  label: 'B',
                  selected: set.contains(Meal.breakfast),
                  color: Colors.amber.shade600,
                  onSelected: (_) => viewModel.toggleMeal(day, Meal.breakfast),
                ),
                _mealFilterChip(
                  label: 'L',
                  selected: set.contains(Meal.lunch),
                  color: Colors.orange.shade600,
                  onSelected: (_) => viewModel.toggleMeal(day, Meal.lunch),
                ),
                _mealFilterChip(
                  label: 'D',
                  selected: set.contains(Meal.dinner),
                  color: Colors.red.shade600,
                  onSelected: (_) => viewModel.toggleMeal(day, Meal.dinner),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              viewModel.weeklyMeals[day] = <Meal>{};
              viewModel.notifyListeners();
            },
            child: const Text('Clear', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _mealFilterChip({
    required String label,
    required bool selected,
    required Color color,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      selected: selected,
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
      showCheckmark: false,
      onSelected: onSelected,
      backgroundColor: color.withOpacity(0.08),
      selectedColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      side: BorderSide(color: selected ? color : color.withOpacity(0.4)),
    );
  }

  String _getOrdinalSuffix(int number) {
    if (number % 100 >= 11 && number % 100 <= 13) return 'th';
    switch (number % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  Future<void> _addProperty(AddPropertyViewModel viewModel, BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields correctly.')),
      );
      return;
    }

    if (viewModel.currentMaxSharing <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a valid Max Sharing (e.g., 3).')),
      );
      return;
    }

    final hasAnyPrice = viewModel.sharingRows.any((row) =>
    (row['nonAcController'] as TextEditingController).text.trim().isNotEmpty ||
        (row['acController'] as TextEditingController).text.trim().isNotEmpty);

    if (!hasAnyPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set at least one price for any sharing type.')),
      );
      return;
    }

    if (viewModel.hasFood && viewModel.weeklyMeals.values.every((s) => s.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configure Food Plan or disable Food Included.')),
      );
      return;
    }

    HapticFeedback.lightImpact();

    try {
      // Use the business data passed from parameters
      debugPrint('🎯 Calling addProperty with passed business data:');
      debugPrint('  Business ID: ${widget.businessId}');
      debugPrint('  Business Name: ${widget.businessName}');
      debugPrint('  Business Phone: ${widget.businessPhone}');

      await viewModel.addProperty(
        widget.businessId,    // Use the passed business ID
        widget.businessName,  // Use the passed business name
        widget.businessPhone, // Use the passed business phone
        context,
      );
    } catch (e) {
      // Error handling is done in the ViewModel
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.teal.shade600;

    return BusinessScaffold(
      currentTab: BusinessTab.properties,
      //titleText: 'Add New Property',
      showBackButton: true,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Consumer<AddPropertyViewModel>(
            builder: (context, viewModel, child) {
              final floorItems = [
                const DropdownMenuItem(value: 'Ground', child: Text('Ground')),
                for (int i = 1; i <= (int.tryParse(viewModel.numberOfFloorsController.text.trim()) ?? 0); i++)
                  DropdownMenuItem(value: '$i', child: Text('$i${_getOrdinalSuffix(i)}')),
              ];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Business Info Display
                      _buildSectionTitle('Business Information'),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Business: ${widget.businessName}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.teal.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${widget.businessId}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.teal.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Phone: ${widget.businessPhone}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.teal.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      _buildSectionTitle('General Information'),
                      _buildTextField(
                        controller: viewModel.propertyNameController,
                        label: 'Property Name',
                        hint: 'e.g., The Grand Residency PG',
                        icon: Icons.apartment_outlined,
                        validator: (value) => (value == null || value.isEmpty) ? 'Please enter property name' : null,
                        primaryColor: primaryColor,
                      ),
                      _buildTextField(
                        controller: viewModel.addressController,
                        label: 'Full Address',
                        hint: 'Street, Area, City',
                        icon: Icons.location_on_outlined,
                        maxLines: 3,
                        validator: (value) => (value == null || value.isEmpty) ? 'Please enter full address' : null,
                        primaryColor: primaryColor,
                      ),
                      _buildTextField(
                        controller: viewModel.pincodeController,
                        label: 'Pincode',
                        hint: 'e.g., 560001',
                        icon: Icons.local_post_office_outlined,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Enter pincode';
                          if (value.length < 4) return 'Enter valid pincode';
                          return null;
                        },
                        primaryColor: primaryColor,
                      ),
                      _buildDropdownField<String>(
                        label: 'City',
                        value: viewModel.selectedCity,
                        items: viewModel.cities.keys
                            .map((city) => DropdownMenuItem(
                            value: city,
                            child: Text('$city (${viewModel.cities[city]})')
                        ))
                            .toList(),
                        onChanged: (v) {
                          viewModel.selectedCity = v;
                          viewModel.notifyListeners();
                        },
                        icon: Icons.location_city_outlined,
                        validator: (v) => v == null ? 'Please select a city' : null,
                        primaryColor: primaryColor,
                      ),
                      _buildTextField(
                        controller: viewModel.numberOfFloorsController,
                        label: 'Number of Floors (Excluding Ground)',
                        hint: 'e.g., 3',
                        icon: Icons.layers_outlined,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Enter number of floors';
                          if (int.tryParse(value) == null) return 'Enter a valid number';
                          return null;
                        },
                        primaryColor: primaryColor,
                      ),
                      _buildTextField(
                        controller: viewModel.descriptionController,
                        label: 'Description',
                        hint: 'Brief description of the property',
                        icon: Icons.description_outlined,
                        maxLines: 5,
                        primaryColor: primaryColor,
                      ),
                      _buildTextField(
                        controller: viewModel.landmarksController,
                        label: 'Nearby Landmarks',
                        hint: 'e.g., Near Forum Mall, Beside Metro Station',
                        icon: Icons.place_outlined,
                        primaryColor: primaryColor,
                      ),
                      _buildTextField(
                        controller: viewModel.googleMapsLinkController,
                        label: 'Google Maps Link (Optional)',
                        hint: 'Paste Google Maps URL',
                        icon: Icons.link_outlined,
                        keyboardType: TextInputType.url,
                        primaryColor: primaryColor,
                      ),

                      // Images Section
                      _buildSectionTitle('Property Images'),
                      if (viewModel.selectedImages.isNotEmpty)
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (context, index) {
                              final file = viewModel.selectedImages[index];
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(file.path),
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 120,
                                        height: 120,
                                        color: Colors.grey.shade200,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.broken_image),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.red,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, size: 14, color: Colors.white),
                                        onPressed: () => viewModel.removeImageAt(index),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemCount: viewModel.selectedImages.length,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300, width: 1),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: viewModel.isUploadingImages ? null : () => viewModel.pickImages(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (viewModel.isUploadingImages) ...[
                                const CircularProgressIndicator(),
                                const SizedBox(height: 8),
                                Text(
                                    'Uploading images...',
                                    style: TextStyle(color: Colors.grey.shade600)
                                ),
                              ] else ...[
                                Icon(
                                    Icons.camera_alt_outlined,
                                    size: 40,
                                    color: Colors.grey.shade400
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    'Tap to add images',
                                    style: TextStyle(color: Colors.grey.shade500)
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () => viewModel.pickImages(),
                                  icon: const Icon(Icons.add_a_photo),
                                  label: const Text('Add Images'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Max Sharing & Pricing
                      _buildSectionTitle('Max Sharing & Pricing'),
                      _buildTextField(
                        controller: viewModel.maxSharingController,
                        label: 'Max Sharing (Highest number of people per room)',
                        hint: 'e.g., 3',
                        icon: Icons.people_alt_outlined,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Enter max sharing (e.g., 3)';
                          final v = int.tryParse(value);
                          if (v == null || v <= 0) return 'Enter a number greater than 0';
                          return null;
                        },
                        primaryColor: primaryColor,
                      ),
                      if (viewModel.currentMaxSharing > 0)
                        ...viewModel.sharingRows.map((row) {
                          final s = row['sharing'] as int;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$s Sharing Pricing',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          controller: row['nonAcController'],
                                          label: 'Non-AC Rent (₹/month)',
                                          hint: 'e.g., 8000',
                                          icon: Icons.currency_rupee_outlined,
                                          keyboardType: TextInputType.number,
                                          primaryColor: primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildTextField(
                                          controller: row['acController'],
                                          label: 'AC Rent (₹/month)',
                                          hint: 'e.g., 10000',
                                          icon: Icons.ac_unit_outlined,
                                          keyboardType: TextInputType.number,
                                          primaryColor: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                      // Common Charges
                      _buildSectionTitle('Common Charges'),
                      _buildTextField(
                        controller: viewModel.securityDepositController,
                        label: 'Security Deposit (per person)',
                        hint: '₹ 5000',
                        icon: Icons.money_outlined,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter security deposit';
                          if (int.tryParse(value) == null) return 'Enter a valid amount';
                          return null;
                        },
                        primaryColor: primaryColor,
                      ),
                      _buildTextField(
                        controller: viewModel.oneTimeMaintenanceChargeController,
                        label: 'One-time Maintenance Charge (if applicable)',
                        hint: '₹ 1000',
                        icon: Icons.build_outlined,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                        primaryColor: primaryColor,
                      ),
                      CheckboxListTile(
                        title: Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, color: primaryColor, size: 20),
                            const SizedBox(width: 12),
                            const Text('Deduct maintenance from security deposit'),
                          ],
                        ),
                        value: viewModel.isMaintenanceDeductedFromDeposit,
                        onChanged: (val) {
                          viewModel.isMaintenanceDeductedFromDeposit = val ?? false;
                          viewModel.notifyListeners();
                        },
                        activeColor: primaryColor,
                        checkColor: Colors.white,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),

                      // Rooms Section
                      _buildSectionTitle('Individual Room Details'),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Rooms: ${viewModel.getTotalRooms()}',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                            Text('Total Beds: ${viewModel.getTotalBeds()}',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                      ...viewModel.roomDetails.asMap().entries.map((entry) {
                        final index = entry.key;
                        final room = entry.value;
                        final isExpanded = viewModel.expandedRoomIndex == index;

                        Widget expanded = Card(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Room ${index + 1}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.unfold_less),
                                      tooltip: 'Collapse',
                                      onPressed: () {
                                        viewModel.expandedRoomIndex = null;
                                        viewModel.notifyListeners();
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                                      onPressed: () => viewModel.removeRoom(index),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: room['roomNumberController'],
                                  label: 'Room Number',
                                  hint: 'e.g., 101',
                                  icon: Icons.door_front_door_outlined,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Enter room number';
                                    return null;
                                  },
                                  primaryColor: primaryColor,
                                ),
                                _buildDropdownField<String>(
                                  label: 'Floor',
                                  value: room['floor'],
                                  items: floorItems,
                                  onChanged: (value) {
                                    room['floor'] = value;
                                    viewModel.notifyListeners();
                                  },
                                  icon: Icons.layers_outlined,
                                  validator: (value) => value == null ? 'Select floor' : null,
                                  primaryColor: primaryColor,
                                ),
                                _buildDropdownField<int>(
                                  label: 'Sharing Type',
                                  value: room['sharingType'],
                                  items: [
                                    for (int i = 1; i <= viewModel.currentMaxSharing; i++)
                                      DropdownMenuItem(value: i, child: Text('$i Sharing')),
                                  ],
                                  onChanged: (value) {
                                    room['sharingType'] = value;
                                    viewModel.notifyListeners();
                                  },
                                  icon: Icons.group_outlined,
                                  validator: (value) {
                                    if (viewModel.currentMaxSharing <= 0) return 'Set Max Sharing above first';
                                    if (value == null || value < 1 || value > viewModel.currentMaxSharing) {
                                      return 'Select sharing type';
                                    }
                                    return null;
                                  },
                                  primaryColor: primaryColor,
                                ),
                                CheckboxListTile(
                                  title: Row(
                                    children: [
                                      Icon(Icons.ac_unit_outlined, color: primaryColor, size: 20),
                                      const SizedBox(width: 12),
                                      const Text('Is AC Room?'),
                                    ],
                                  ),
                                  value: room['hasAC'] as bool? ?? false,
                                  onChanged: (val) {
                                    room['hasAC'] = val ?? false;
                                    viewModel.notifyListeners();
                                  },
                                  activeColor: primaryColor,
                                  checkColor: Colors.white,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                ),
                              ],
                            ),
                          ),
                        );

                        Widget collapsed = Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            onTap: () {
                              viewModel.expandedRoomIndex = index;
                              viewModel.notifyListeners();
                            },
                            title: Text(
                              'Room ${index + 1} • ${(room['roomNumberController'] as TextEditingController).text.isEmpty ? 'No. —' : (room['roomNumberController'] as TextEditingController).text}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${room['floor'] ?? 'Floor —'} • ${viewModel.sharingLabel(room['sharingType'] as int?)} • ${(room['hasAC'] == true) ? 'AC' : 'Non-AC'}',
                            ),
                            trailing: const Icon(Icons.unfold_more),
                          ),
                        );

                        return AnimatedCrossFade(
                          duration: const Duration(milliseconds: 200),
                          crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                          firstChild: expanded,
                          secondChild: collapsed,
                        );
                      }),
                      const SizedBox(height: 8),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (viewModel.currentMaxSharing <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Set Max Sharing before adding rooms.')),
                              );
                              return;
                            }
                            viewModel.addRoom();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add New Room'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: primaryColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ),

                      // Amenities
                      _buildSectionTitle('Amenities'),
                      CheckboxListTile(
                        title: Row(
                          children: [
                            Icon(Icons.check_box_outlined, color: primaryColor, size: 20),
                            const SizedBox(width: 12),
                            const Text('Select All Amenities'),
                          ],
                        ),
                        value: viewModel.selectAllAmenities,
                        onChanged: (val) => viewModel.toggleSelectAllAmenities(val ?? false),
                        activeColor: primaryColor,
                        checkColor: Colors.white,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      _amenityTile('Wi-Fi', viewModel.hasWifi, Icons.wifi_outlined,
                              (v) => viewModel.updateAmenity('wifi', v), primaryColor),
                      _amenityTile('Air Conditioning (Common)', viewModel.hasAC, Icons.ac_unit_outlined,
                              (v) => viewModel.updateAmenity('ac', v), primaryColor),
                      _amenityTile('Laundry Service', viewModel.hasLaundry, Icons.local_laundry_service_outlined,
                              (v) => viewModel.updateAmenity('laundry', v), primaryColor),
                      _amenityTile('Food Included', viewModel.hasFood, Icons.restaurant_menu_outlined,
                              (v) => viewModel.updateAmenity('food', v), primaryColor),
                      if (viewModel.hasFood) _buildFoodPlanSection(viewModel, primaryColor),
                      _amenityTile('Parking Available', viewModel.hasParking, Icons.local_parking_outlined,
                              (v) => viewModel.updateAmenity('parking', v), primaryColor),
                      _amenityTile('Geyser/Hot Water', viewModel.hasGeyser, Icons.water_drop_outlined,
                              (v) => viewModel.updateAmenity('geyser', v), primaryColor),
                      _amenityTile('Power Backup', viewModel.hasPowerBackup, Icons.battery_charging_full_outlined,
                              (v) => viewModel.updateAmenity('powerBackup', v), primaryColor),
                      _amenityTile('CCTV Surveillance', viewModel.hasCCTV, Icons.videocam_outlined,
                              (v) => viewModel.updateAmenity('cctv', v), primaryColor),
                      _amenityTile('Daily Housekeeping', viewModel.hasHousekeeping, Icons.cleaning_services_outlined,
                              (v) => viewModel.updateAmenity('housekeeping', v), primaryColor),

                      // Rules
                      _buildSectionTitle('Rules & Policies'),
                      _buildDropdownField<String>(
                        label: 'Gender Allowed',
                        value: viewModel.genderAllowed,
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Co-ed', child: Text('Co-ed')),
                        ],
                        onChanged: (v) {
                          viewModel.genderAllowed = v;
                          viewModel.notifyListeners();
                        },
                        icon: Icons.wc_outlined,
                        validator: (v) => v == null ? 'Please select gender allowed' : null,
                        primaryColor: primaryColor,
                      ),
                      _buildTextField(
                        controller: viewModel.noticePeriodController,
                        label: 'Notice Period (in days)',
                        hint: 'e.g., 30',
                        icon: Icons.calendar_month_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter notice period';
                          if (int.tryParse(v) == null) return 'Enter a valid number';
                          return null;
                        },
                        primaryColor: primaryColor,
                      ),
                      _amenityTile('Curfew Applicable', viewModel.hasCurfew, Icons.access_time_outlined,
                              (v) => viewModel.updateRule('curfew', v), primaryColor),
                      _amenityTile('Visitors Allowed', viewModel.visitorsAllowed, Icons.group_add_outlined,
                              (v) => viewModel.updateRule('visitors', v), primaryColor),
                      _amenityTile('Smoking Allowed', viewModel.smokingAllowed, Icons.smoking_rooms_outlined,
                              (v) => viewModel.updateRule('smoking', v), primaryColor),
                      _amenityTile('Alcohol Allowed', viewModel.alcoholAllowed, Icons.local_bar_outlined,
                              (v) => viewModel.updateRule('alcohol', v), primaryColor),

                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (viewModel.isLoading || viewModel.isUploadingImages)
                              ? null
                              : () => _addProperty(viewModel, context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            shadowColor: primaryColor.withOpacity(0.3),
                          ),
                          child: (viewModel.isLoading || viewModel.isUploadingImages)
                              ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          )
                              : const Text('Add Property', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}


