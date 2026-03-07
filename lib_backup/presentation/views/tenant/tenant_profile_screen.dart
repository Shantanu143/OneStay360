import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/tenant_scaffold.dart';
import 'package:provider/provider.dart';
import 'package:onestay360/presentation/view_models/tenant/profile_viewmodel.dart';
import 'package:onestay360/data/models/tenant/tenant_document_model.dart';
import 'package:onestay360/data/services/image_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TenantProfileScreen extends StatelessWidget {
  const TenantProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: ChangeNotifierProvider(
        create: (_) => TenantProfileViewModel()..load(),
        child: TenantScaffold(
          currentTab: TenantTab.profile,
          body: Column(
            children: [
              Container(
                color: Colors.white,
                child: const TabBar(
                  labelColor: Color(0xFF0891B2),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Color(0xFF0891B2),
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'KYC'),
                    Tab(text: 'Documents'),
                    Tab(text: 'Settings'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: const [
                    _TenantOverviewTab(),
                    _TenantKYCTab(),
                    _TenantDocumentsTab(),
                    _TenantSettingsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TenantOverviewTab extends StatelessWidget {
  const _TenantOverviewTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.1 * 255).round()),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Color(0xFF3b82f6).withAlpha((0.1 * 255).round()),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 50,
                        color: Color(0xFF3b82f6),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => HapticFeedback.lightImpact(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3b82f6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Consumer<TenantProfileViewModel>(
                  builder: (context, vm, _) {
                    final name = vm.nameController.text.trim();
                    final displayName = name.isEmpty ? 'Tenant' : name;
                    return Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF164e63),
                        fontFamily: 'Geist',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Consumer<TenantProfileViewModel>(
                  builder: (context, vm, _) {
                    final officeName = vm.officeInstituteNameController.text.trim();
                    if (officeName.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      officeName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontFamily: 'Manrope',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Consumer<TenantProfileViewModel>(
                  builder: (context, vm, _) {
                    // Only show stats if we have meaningful data
                    final hasData = vm.nameController.text.trim().isNotEmpty;
                    if (!hasData) {
                      return const SizedBox.shrink();
                    }
                    // For now, hide stats until we have actual data
                    // You can add real stats later when you have payment/booking data
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          
          // QR Code Card (only show when profile is complete)
          Consumer<TenantProfileViewModel>(
            builder: (context, vm, _) {
              if (!vm.isProfileComplete || vm.qrCodeData == null) {
                return const SizedBox.shrink();
              }
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.1 * 255).round()),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'My QR Code',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF164e63),
                        fontFamily: 'Geist',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share this QR code with property owners to quickly add your details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: QrImageView(
                        data: vm.qrCodeData!,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tenant ID: ${vm.tenantId ?? "N/A"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Personal Information - Overview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.05 * 255).round()),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer<TenantProfileViewModel>(
                  builder: (context, vm, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF164e63),
                            fontFamily: 'Geist',
                          ),
                        ),
                        if (!vm.isOverviewEditMode)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              vm.toggleOverviewEditMode();
                            },
                            tooltip: 'Edit',
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              vm.exitOverviewEditMode();
                            },
                            tooltip: 'Cancel',
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Consumer<TenantProfileViewModel>(
                  builder: (context, vm, _) {
                    if (vm.isOverviewEditMode) {
                      return Column(
                        children: [
                          _EditableRow(
                            icon: Icons.person_outline,
                            label: 'Name',
                            controller: vm.nameController,
                          ),
                          _EditableRow(
                            icon: Icons.phone_outlined,
                            label: 'Mobile Number',
                            controller: vm.mobileNumberController,
                            keyboardType: TextInputType.phone,
                          ),
                          _EditableRow(
                            icon: Icons.phone_android_outlined,
                            label: 'Alternate Phone',
                            controller: vm.alternatePhoneController,
                            keyboardType: TextInputType.phone,
                          ),
                          _EditableRow(
                            icon: Icons.contact_phone_outlined,
                            label: 'Emergency Contact Name',
                            controller: vm.emergencyContactNameController,
                          ),
                          _EditableRow(
                            icon: Icons.phone_forwarded_outlined,
                            label: 'Emergency Contact Phone',
                            controller: vm.emergencyContactPhoneController,
                            keyboardType: TextInputType.phone,
                          ),
                          _EditableRow(
                            icon: Icons.apartment_outlined,
                            label: 'Office/Institute Name',
                            controller: vm.officeInstituteNameController,
                          ),
                          _EditableRow(
                            icon: Icons.perm_identity,
                            label: 'Office/Institute ID',
                            controller: vm.officeInstituteIdController,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: vm.isSaving
                                  ? null
                                  : () async {
                                      HapticFeedback.lightImpact();
                                      await vm.save();
                                      if (vm.errorMessage != null) {
                                        // ignore: use_build_context_synchronously
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(vm.errorMessage!),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      } else {
                                        // ignore: use_build_context_synchronously
                                        final message = vm.isProfileComplete
                                            ? 'Profile completed successfully!'
                                            : 'Profile updated. Please complete all required fields.';
                                        // ignore: use_build_context_synchronously
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(message),
                                            backgroundColor: vm.isProfileComplete
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        );
                                      }
                                    },
                              icon: vm.isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Save Profile'),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _ViewRow(
                            icon: Icons.person_outline,
                            label: 'Name',
                            value: vm.nameController.text.trim().isEmpty 
                                ? 'Not provided' 
                                : vm.nameController.text.trim(),
                          ),
                          _ViewRow(
                            icon: Icons.phone_outlined,
                            label: 'Mobile Number',
                            value: vm.mobileNumberController.text.trim().isEmpty 
                                ? 'Not provided' 
                                : vm.mobileNumberController.text.trim(),
                          ),
                          _ViewRow(
                            icon: Icons.phone_android_outlined,
                            label: 'Alternate Phone',
                            value: vm.alternatePhoneController.text.trim().isEmpty 
                                ? 'Not provided' 
                                : vm.alternatePhoneController.text.trim(),
                          ),
                          _ViewRow(
                            icon: Icons.contact_phone_outlined,
                            label: 'Emergency Contact Name',
                            value: vm.emergencyContactNameController.text.trim().isEmpty 
                                ? 'Not provided' 
                                : vm.emergencyContactNameController.text.trim(),
                          ),
                          _ViewRow(
                            icon: Icons.phone_forwarded_outlined,
                            label: 'Emergency Contact Phone',
                            value: vm.emergencyContactPhoneController.text.trim().isEmpty 
                                ? 'Not provided' 
                                : vm.emergencyContactPhoneController.text.trim(),
                          ),
                          _ViewRow(
                            icon: Icons.apartment_outlined,
                            label: 'Office/Institute Name',
                            value: vm.officeInstituteNameController.text.trim().isEmpty 
                                ? 'Not provided' 
                                : vm.officeInstituteNameController.text.trim(),
                          ),
                          _ViewRow(
                            icon: Icons.perm_identity,
                            label: 'Office/Institute ID',
                            value: vm.officeInstituteIdController.text.trim().isEmpty 
                                ? 'Not provided' 
                                : vm.officeInstituteIdController.text.trim(),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // App Version
          Text(
            'Version 1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontFamily: 'Manrope',
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _TenantKYCTab extends StatelessWidget {
  const _TenantKYCTab();

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _SectionCard(
            title: 'KYC Details',
            child: Consumer<TenantProfileViewModel>(
              builder: (context, vm, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox.shrink(),
                        if (!vm.isKYCEditMode)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              vm.toggleKYCEditMode();
                            },
                            tooltip: 'Edit',
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              vm.exitKYCEditMode();
                            },
                            tooltip: 'Cancel',
                          ),
                      ],
                    ),
                    if (vm.isKYCEditMode) ...[
                      // Gender Dropdown
                      DropdownButtonFormField<String>(
                        value: vm.selectedGender,
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          border: border,
                          enabledBorder: border,
                          focusedBorder: border.copyWith(
                            borderSide: const BorderSide(color: Color(0xFF0891B2)),
                          ),
                        ),
                        items: vm.genderOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          vm.selectedGender = newValue;
                          vm.notifyListeners();
                        },
                      ),
                      const SizedBox(height: 12),

                      // Date of Birth Field
                      GestureDetector(
                        onTap: () => vm.selectDateOfBirth(context),
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Date of Birth',
                              border: border,
                              enabledBorder: border,
                              focusedBorder: border.copyWith(
                                borderSide: const BorderSide(color: Color(0xFF0891B2)),
                              ),
                              suffixIcon: const Icon(Icons.calendar_today_outlined),
                            ),
                            controller: TextEditingController(
                              text: vm.selectedDateOfBirth != null
                                  ? '${vm.selectedDateOfBirth!.day}/${vm.selectedDateOfBirth!.month}/${vm.selectedDateOfBirth!.year}'
                                  : '',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Nationality Dropdown
                      DropdownButtonFormField<String>(
                        value: vm.selectedNationality,
                        decoration: InputDecoration(
                          labelText: 'Nationality',
                          border: border,
                          enabledBorder: border,
                          focusedBorder: border.copyWith(
                            borderSide: const BorderSide(color: Color(0xFF0891B2)),
                          ),
                        ),
                        items: vm.nationalityOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          vm.selectedNationality = newValue;
                          vm.notifyListeners();
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // Mother Tongue Dropdown
                      DropdownButtonFormField<String>(
                        value: vm.selectedMotherTongue,
                        decoration: InputDecoration(
                          labelText: 'Mother Tongue',
                          border: border,
                          enabledBorder: border,
                          focusedBorder: border.copyWith(
                            borderSide: const BorderSide(color: Color(0xFF0891B2)),
                          ),
                        ),
                        items: vm.motherTongueOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          vm.selectedMotherTongue = newValue;
                          vm.notifyListeners();
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // ID Type Dropdown (Aadhar Card Only)
                      DropdownButtonFormField<String>(
                        value: vm.selectedIdType,
                        decoration: InputDecoration(
                          labelText: 'ID Type',
                          border: border,
                          enabledBorder: border,
                          focusedBorder: border.copyWith(
                            borderSide: const BorderSide(color: Color(0xFF0891B2)),
                          ),
                        ),
                        items: vm.idTypeOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          vm.selectedIdType = newValue;
                          vm.notifyListeners();
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      TextField(
                        controller: vm.idNumberController,
                        decoration: InputDecoration(
                          labelText: 'ID Number',
                          hintText: 'Enter ID number',
                          border: border,
                          enabledBorder: border,
                          focusedBorder: border.copyWith(
                            borderSide: const BorderSide(color: Color(0xFF0891B2)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: vm.isSaving
                              ? null
                              : () async {
                                  HapticFeedback.lightImpact();
                                  await vm.save();
                                  if (vm.errorMessage != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(vm.errorMessage!),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } else {
                                    final message = vm.isProfileComplete
                                        ? 'KYC Details saved! Profile is now complete.'
                                        : 'KYC Details updated. Please complete all required fields.';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(message),
                                        backgroundColor: vm.isProfileComplete
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    );
                                  }
                                },
                          icon: vm.isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Save KYC Details'),
                        ),
                      ),
                    ] else ...[
                      _ViewRow(
                        icon: Icons.person_outline,
                        label: 'Gender',
                        value: vm.selectedGender ?? 'Not provided',
                      ),
                      _ViewRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date of Birth',
                        value: vm.selectedDateOfBirth != null
                            ? '${vm.selectedDateOfBirth!.day}/${vm.selectedDateOfBirth!.month}/${vm.selectedDateOfBirth!.year}'
                            : 'Not provided',
                      ),
                      _ViewRow(
                        icon: Icons.flag_outlined,
                        label: 'Nationality',
                        value: vm.selectedNationality ?? 'Not provided',
                      ),
                      _ViewRow(
                        icon: Icons.language_outlined,
                        label: 'Mother Tongue',
                        value: vm.selectedMotherTongue ?? 'Not provided',
                      ),
                      _ViewRow(
                        icon: Icons.badge_outlined,
                        label: 'ID Type',
                        value: vm.selectedIdType ?? 'Not provided',
                      ),
                      _ViewRow(
                        icon: Icons.credit_card_outlined,
                        label: 'ID Number',
                        value: vm.idNumberController.text.trim().isEmpty 
                            ? 'Not provided' 
                            : vm.idNumberController.text.trim(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          
          _SectionCard(
            title: 'Address',
            child: Consumer<TenantProfileViewModel>(
              builder: (context, vm, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox.shrink(),
                        if (!vm.isAddressEditMode)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              vm.toggleAddressEditMode();
                            },
                            tooltip: 'Edit',
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              vm.exitAddressEditMode();
                            },
                            tooltip: 'Cancel',
                          ),
                      ],
                    ),
                    if (vm.isAddressEditMode) ...[
                      TextField(
                        controller: vm.addressLine1Controller,
                        decoration: InputDecoration(
                          labelText: 'Address Line 1',
                          border: border,
                          enabledBorder: border,
                          focusedBorder: border.copyWith(
                            borderSide: const BorderSide(color: Color(0xFF0891B2)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: vm.cityController,
                        decoration: InputDecoration(
                          labelText: 'City',
                          border: border,
                          enabledBorder: border,
                          focusedBorder: border.copyWith(
                            borderSide: const BorderSide(color: Color(0xFF0891B2)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: vm.pincodeController,
                        decoration: InputDecoration(
                          labelText: 'Pincode',
                          border: border,
                          enabledBorder: border,
                          focusedBorder: border.copyWith(
                            borderSide: const BorderSide(color: Color(0xFF0891B2)),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: vm.isSaving
                              ? null
                              : () async {
                                  HapticFeedback.lightImpact();
                                  await vm.save();
                                  if (vm.errorMessage != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(vm.errorMessage!),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } else {
                                    final message = vm.isProfileComplete
                                        ? 'Address saved! Profile is now complete.'
                                        : 'Address updated. Please complete all required fields.';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(message),
                                        backgroundColor: vm.isProfileComplete
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    );
                                  }
                                },
                          icon: vm.isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Save Address'),
                        ),
                      ),
                    ] else ...[
                      _ViewRow(
                        icon: Icons.home_outlined,
                        label: 'Address Line 1',
                        value: vm.addressLine1Controller.text.trim().isEmpty 
                            ? 'Not provided' 
                            : vm.addressLine1Controller.text.trim(),
                      ),
                      _ViewRow(
                        icon: Icons.location_city_outlined,
                        label: 'City',
                        value: vm.cityController.text.trim().isEmpty 
                            ? 'Not provided' 
                            : vm.cityController.text.trim(),
                      ),
                      _ViewRow(
                        icon: Icons.pin_outlined,
                        label: 'Pincode',
                        value: vm.pincodeController.text.trim().isEmpty 
                            ? 'Not provided' 
                            : vm.pincodeController.text.trim(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantDocumentsTab extends StatelessWidget {
  const _TenantDocumentsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<TenantProfileViewModel>(
      builder: (context, vm, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionCard(
              title: 'Uploaded Documents',
              child: vm.documents.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No documents uploaded yet',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      children: [
                        ...vm.documents.map((doc) {
                          final dateStr = _formatDate(doc.uploadedAt);
                          return Column(
                            children: [
                              _DocTile(
                                icon: _getDocumentIcon(doc.type),
                                title: doc.typeName,
                                subtitle: 'Uploaded $dateStr',
                                onView: () async {
                                  HapticFeedback.lightImpact();
                                  // TODO: Open document viewer
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Opening ${doc.typeName}...'),
                                    ),
                                  );
                                },
                                onDelete: () async {
                                  HapticFeedback.lightImpact();
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Document'),
                                      content: Text('Are you sure you want to delete ${doc.typeName}?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && doc.id != null) {
                                    try {
                                      await vm.deleteDocument(doc.id!);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Document deleted')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                              if (doc != vm.documents.last) const Divider(),
                            ],
                          );
                        }),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Upload New Document',
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: vm.isUploadingDocument
                        ? null
                        : () => _uploadDocument(context, vm, DocumentType.aadhar),
                    icon: vm.isUploadingDocument
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload Aadhaar Card'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: vm.isUploadingDocument
                        ? null
                        : () => _uploadDocument(context, vm, DocumentType.pan),
                    icon: vm.isUploadingDocument
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload PAN Card'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: vm.isUploadingDocument
                        ? null
                        : () => _uploadDocument(context, vm, DocumentType.rentalAgreement),
                    icon: vm.isUploadingDocument
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload Rental Agreement'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: vm.isUploadingDocument
                        ? null
                        : () => _uploadDocument(context, vm, DocumentType.other),
                    icon: vm.isUploadingDocument
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload Other Document'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _uploadDocument(
    BuildContext context,
    TenantProfileViewModel vm,
    DocumentType type,
  ) async {
    try {
      HapticFeedback.lightImpact();
      final imageService = ImageService();
      final file = await imageService.pickSingleImage();
      
      if (file == null) return;

      await vm.uploadDocument(type, file);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_getDocumentTypeName(type)} uploaded successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading document: $e')),
        );
      }
    }
  }

  static String _getDocumentTypeName(DocumentType type) {
    switch (type) {
      case DocumentType.aadhar:
        return 'Aadhaar Card';
      case DocumentType.pan:
        return 'PAN Card';
      case DocumentType.rentalAgreement:
        return 'Rental Agreement';
      case DocumentType.other:
        return 'Document';
    }
  }

  static IconData _getDocumentIcon(DocumentType type) {
    switch (type) {
      case DocumentType.aadhar:
        return Icons.badge_outlined;
      case DocumentType.pan:
        return Icons.credit_card_outlined;
      case DocumentType.rentalAgreement:
        return Icons.assignment_outlined;
      case DocumentType.other:
        return Icons.description_outlined;
    }
  }

  static String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _TenantSettingsTab extends StatelessWidget {
  const _TenantSettingsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: const [
              _SettingItem(
                icon: Icons.lock_rounded,
                title: 'Change Password',
                subtitle: 'Update your password',
                color: Color(0xFF3b82f6),
              ),
              _SettingsDivider(),
              _SettingItem(
                icon: Icons.notifications_rounded,
                title: 'Notifications',
                subtitle: 'Manage notification preferences',
                color: Color(0xFFf97316),
              ),
              _SettingsDivider(),
              _SettingItem(
                icon: Icons.payment_rounded,
                title: 'Payment Methods',
                subtitle: 'Manage payment options',
                color: Color(0xFF34d399),
              ),
              _SettingsDivider(),
              _SettingItem(
                icon: Icons.help_rounded,
                title: 'Help & Support',
                subtitle: 'Get help and contact support',
                color: Color(0xFFec4899),
              ),
              _SettingsDivider(),
              _SettingItem(
                icon: Icons.privacy_tip_rounded,
                title: 'Privacy Policy',
                subtitle: 'Read our privacy policy',
                color: Color(0xFF9333ea),
              ),
              _SettingsDivider(),
              _SettingItem(
                icon: Icons.logout_rounded,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                color: Color(0xFFbe123c),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // App Version
        Center(
          child: Text(
            'Version 1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontFamily: 'Manrope',
            ),
          ),
        ),
      ],
    );
  }
}

// Reusable widgets

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF164e63),
            fontFamily: 'Geist',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF475569),
            fontFamily: 'Manrope',
          ),
        ),
      ],
    );
  }
}

class _DividerDot extends StatelessWidget {
  const _DividerDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: const Color(0xFFe5e7eb),
    );
  }
}

class _EditableRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  const _EditableRow({
    required this.icon,
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF0891B2), width: 2),
          ),
        ),
      ),
    );
  }
}

class _ViewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ViewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF164e63),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
              color: Color(0xFF164e63),
              fontFamily: 'Geist',
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onView;
  final VoidCallback onDelete;

  const _DocTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onView,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0891B2).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF0891B2)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2937),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: Wrap(
        spacing: 8,
        children: [
          IconButton(
            onPressed: onView,
            icon: const Icon(Icons.remove_red_eye_outlined),
            tooltip: 'View',
            color: const Color(0xFF0891B2),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            color: Colors.red,
          ),
        ],
      ),
      onTap: onView,
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _SettingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF164e63),
                      fontFamily: 'Geist',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      fontFamily: 'Manrope',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFF475569),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: const Color(0xFFe5e7eb),
    );
  }
}