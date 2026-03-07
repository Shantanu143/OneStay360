// lib/presentation/views/auth/profile_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onestay360/presentation/services/firestore_service.dart';
import 'package:onestay360/presentation/views/tenant/home_screen.dart';
import 'package:onestay360/presentation/views/business/home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String userType;
  final Map<String, dynamic>? existingUserData;

  const ProfileSetupScreen({
    super.key,
    required this.userType,
    this.existingUserData,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Tenant fields
  final TextEditingController _dobController = TextEditingController();
  String? _selectedGender;
  String? _selectedCity;

  // Business fields
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _businessAddressController = TextEditingController();
  String? _selectedBusinessType;

  bool _isLoading = false;
  final FirestoreService _firestoreService = FirestoreService();

  final Map<String, String> _cityCodes = {
    'Pune': 'PNQ',
    'Mumbai': 'BOM',
    'Bangalore': 'BLR',
    'Chennai': 'MAA',
    'Delhi': 'DEL',
    'Noida': 'NOI',
    'Gurgaon': 'GUR',
    'Kolkata': 'CCU',
    'Kochi': 'COK',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    // Pre-fill form with existing data if available
    if (widget.existingUserData != null) {
      _fullNameController.text = widget.existingUserData!['fullName'] ?? '';
      _phoneController.text = widget.existingUserData!['phoneNumber'] ?? '';

      if (widget.userType == 'tenant') {
        _dobController.text = widget.existingUserData!['dob'] ?? '';
        _selectedGender = widget.existingUserData!['gender'];
        _selectedCity = widget.existingUserData!['currentCity'];
      } else {
        _businessNameController.text = widget.existingUserData!['businessName'] ?? '';
        _contactPersonController.text = widget.existingUserData!['contactPerson'] ?? '';
        _businessAddressController.text = widget.existingUserData!['businessAddress'] ?? '';
        _selectedBusinessType = widget.existingUserData!['businessType'];
      }
    }

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _businessNameController.dispose();
    _contactPersonController.dispose();
    _businessAddressController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Color get _primaryColor => widget.userType == 'tenant'
      ? Colors.blue.shade600
      : Colors.teal.shade600;

  String get _userTypeTitle => widget.userType == 'tenant'
      ? 'Tenant Profile'
      : 'Business Profile';

  String get _userTypeSubtitle => widget.userType == 'tenant'
      ? 'Tell us more about yourself'
      : 'Tell us about your property business';

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        onTap: onTap,
        readOnly: readOnly,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey.shade800,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: _primaryColor),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primaryColor, width: 2),
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
    required IconData icon,
    String? Function(T?)? validator,
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
          prefixIcon: Icon(icon, color: _primaryColor),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade600),
        ),
        dropdownColor: Colors.white,
        style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
        iconEnabledColor: _primaryColor,
      ),
    );
  }

  // Helper for showing snackbars
  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // Helper method for navigation
  void _navigateToHomeScreen(String uid) async {
    final displayName = widget.userType == 'tenant'
        ? _fullNameController.text.trim()
        : _businessNameController.text.trim();

    String? customId = widget.userType == 'tenant'
        ? await _firestoreService.getTenantId(uid)
        : await _firestoreService.getBusinessId(uid);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => widget.userType == 'tenant'
            ? TenantHomeScreen(tenantName: displayName)
            : BusinessHomeScreen(businessId: customId ?? ''),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackbar('Please fill all required fields correctly.', isError: true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      // ✅ CHECK IF PROFILE IS ALREADY COMPLETE
      final isAlreadyComplete = await _firestoreService.isProfileComplete(user.uid);
      if (isAlreadyComplete) {
        _showSnackbar('Profile is already complete! Redirecting...');
        _navigateToHomeScreen(user.uid);
        return;
      }

      // Get the custom ID that was already generated during user initialization
      String? customId;
      if (widget.userType == 'tenant') {
        customId = await _firestoreService.getTenantId(user.uid);
      } else {
        customId = await _firestoreService.getBusinessId(user.uid);
      }

      if (customId == null) {
        throw Exception('User ID not found. Please try signing in again.');
      }

      final userData = {
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'profileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add user-type specific data
      if (widget.userType == 'tenant') {
        userData.addAll({
          'dob': _dobController.text.trim(),
          'gender': _selectedGender ?? '',
          'currentCity': _selectedCity ?? '',
        });
      } else {
        userData.addAll({
          'businessName': _businessNameController.text.trim(),
          'contactPerson': _contactPersonController.text.trim(),
          'businessAddress': _businessAddressController.text.trim(),
          'businessType': _selectedBusinessType ?? '',
        });
      }

      // Update user profile
      await _firestoreService.updateUserProfile(user.uid, userData);

      _showSnackbar('Profile saved successfully!');
      _navigateToHomeScreen(user.uid);

    } catch (e) {
      // Detailed error logging
      print('Profile Setup Error: $e');
      if (e is FirebaseException) {
        print('Firestore Error Code: ${e.code}');
        print('Firestore Error Message: ${e.message}');
      }

      _showSnackbar('Error saving profile: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade50,
              Colors.white,
              Colors.grey.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios),
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userTypeTitle,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _userTypeSubtitle,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                          border: Border.all(color: _primaryColor, width: 3),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 50,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _fullNameController,
                            label: widget.userType == 'tenant' ? 'Full Name' : 'Your Name',
                            hint: widget.userType == 'tenant'
                                ? 'Enter your full name'
                                : 'Enter your name',
                            icon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            hint: 'Enter your 10-digit phone number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your phone number';
                              }
                              if (value.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(value)) {
                                return 'Please enter a valid 10-digit phone number';
                              }
                              return null;
                            },
                          ),
                          if (widget.userType == 'tenant') ...[
                            _buildTextField(
                              controller: _dobController,
                              label: 'Date of Birth',
                              hint: 'DD/MM/YYYY',
                              icon: Icons.calendar_today_outlined,
                              readOnly: true,
                              onTap: () => _selectDate(context),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please select your date of birth';
                                }
                                return null;
                              },
                            ),
                            _buildDropdownField<String>(
                              label: 'Gender',
                              value: _selectedGender,
                              items: const [
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                                DropdownMenuItem(value: 'Prefer not to say', child: Text('Prefer not to say')),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedGender = value);
                              },
                              icon: Icons.wc_outlined,
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select your gender';
                                }
                                return null;
                              },
                            ),
                            _buildDropdownField<String>(
                              label: 'Current City',
                              value: _selectedCity,
                              items: _cityCodes.keys
                                  .map((city) => DropdownMenuItem(
                                value: city,
                                child: Text(city),
                              ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _selectedCity = value);
                              },
                              icon: Icons.location_city_outlined,
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select your current city';
                                }
                                return null;
                              },
                            ),
                          ] else if (widget.userType == 'business') ...[
                            _buildTextField(
                              controller: _businessNameController,
                              label: 'Business Name',
                              hint: 'e.g., OneStay Properties',
                              icon: Icons.apartment_outlined,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your business name';
                                }
                                return null;
                              },
                            ),
                            _buildTextField(
                              controller: _contactPersonController,
                              label: 'Contact Person Name',
                              hint: 'Name of primary contact',
                              icon: Icons.contact_mail_outlined,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter contact person name';
                                }
                                return null;
                              },
                            ),
                            _buildTextField(
                              controller: _businessAddressController,
                              label: 'Business Address',
                              hint: 'Full address of your business',
                              icon: Icons.location_on_outlined,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your business address';
                                }
                                return null;
                              },
                            ),
                            _buildDropdownField<String>(
                              label: 'Business Type',
                              value: _selectedBusinessType,
                              items: const [
                                DropdownMenuItem(value: 'Individual', child: Text('Individual Owner')),
                                DropdownMenuItem(value: 'Property Management Company', child: Text('Property Management Company')),
                                DropdownMenuItem(value: 'Real Estate Agency', child: Text('Real Estate Agency')),
                                DropdownMenuItem(value: 'Partnership', child: Text('Partnership')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedBusinessType = value);
                              },
                              icon: Icons.category_outlined,
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select your business type';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                shadowColor: _primaryColor.withOpacity(0.3),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Text(
                                'Save Profile',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}