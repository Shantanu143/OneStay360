// lib/presentation/views/business/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onestay360/presentation/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:onestay360/presentation/view_models/business/add_property_viewmodel.dart';
import 'package:onestay360/data/services/image_service.dart';
import 'package:onestay360/data/repositories/property_repository.dart';
import 'package:onestay360/presentation/views/business/add_property_screen.dart';
import 'package:onestay360/presentation/views/business/business_properties_screen.dart' as props_view;
import 'package:onestay360/presentation/view_models/business/business_properties_viewmodel.dart';
import 'package:onestay360/presentation/views/business/view_property_screen.dart';
import 'package:onestay360/data/models/business/property/property_model.dart';
import 'package:onestay360/presentation/views/business/add_tenant_screen.dart';
import 'package:onestay360/presentation/views/business/business_profile_screen.dart';
import 'package:onestay360/presentation/views/business/widgets/business_scaffold.dart';
import 'package:onestay360/data/providers/business_state_provider.dart';

class BusinessHomeScreen extends StatefulWidget {
  final String businessId;

  const BusinessHomeScreen({super.key, required this.businessId});

  @override
  State<BusinessHomeScreen> createState() => _BusinessHomeScreenState();
}

class _BusinessHomeScreenState extends State<BusinessHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _currentIndex = 0;

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
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _goToAddProperty() {
    HapticFeedback.lightImpact();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((userDoc) {
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final businessId = userData['businessId'] as String?;
          final businessName = userData['businessName'] as String? ?? '';
          final businessPhone = userData['phoneNumber'] as String? ?? '';

          if (businessId == null || businessId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Business ID not found')),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider(
                create: (_) => AddPropertyViewModel(
                  imageService: context.read<ImageService>(),
                  propertyRepository: context.read<PropertyRepository>(),
                ),
                child: AddPropertyScreen(
                  businessId: businessId,
                  businessName: businessName,
                  businessPhone: businessPhone,
                ),
              ),
            ),
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in again')),
      );
    }
  }

  void _goToAddTenant() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddTenantScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BusinessScaffold(
      currentTab: BusinessTab.dashboard,
      businessId: widget.businessId,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _dashboardBody(),
          _propertiesBody(),
          _tenantsPlaceholder(),
          _reportsPlaceholder(),
          const BusinessProfileScreen(),
        ],
      ),
    );
  }

  Widget _dashboardBody() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  _buildStatCard(
                    title: 'Total Properties',
                    value: '12',
                    icon: Icons.apartment_outlined,
                    color: Colors.teal.shade600,
                  ),
                  _buildStatCard(
                    title: 'Occupancy Rate',
                    value: '85%',
                    icon: Icons.people_outline,
                    color: Colors.orange.shade600,
                  ),
                  _buildStatCard(
                    title: 'Pending Payments',
                    value: '₹ 15,000',
                    icon: Icons.account_balance_wallet_outlined,
                    color: Colors.red.shade600,
                  ),
                  _buildStatCard(
                    title: 'Active Tenants',
                    value: '98',
                    icon: Icons.person_outline,
                    color: Colors.blue.shade600,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Quick Actions',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    _buildQuickAction(
                      icon: Icons.add_business_outlined,
                      label: 'Add Property',
                      color: Colors.teal.shade600,
                      onTap: _goToAddProperty,
                    ),
                    const SizedBox(width: 16),
                    _buildQuickAction(
                      icon: Icons.group_add_outlined,
                      label: 'Add Tenant',
                      color: Colors.blue.shade600,
                      onTap: _goToAddTenant,
                    ),
                    const SizedBox(width: 16),
                    _buildQuickAction(
                      icon: Icons.receipt_long_outlined,
                      label: 'Collect Rent',
                      color: Colors.green.shade600,
                      onTap: () => debugPrint('Collect Rent tapped'),
                    ),
                    const SizedBox(width: 16),
                    _buildQuickAction(
                      icon: Icons.build_outlined,
                      label: 'Manage Issues',
                      color: Colors.orange.shade600,
                      onTap: () => debugPrint('Manage Issues tapped'),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Recent Activities',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 10,
                        offset: const Offset(0, 4)
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildActivityItem(
                        'New tenant added: John Doe',
                        '5 mins ago',
                        Icons.person_add_alt_1_outlined,
                        Colors.blue
                    ),
                    Divider(color: Colors.grey.shade200),
                    _buildActivityItem(
                        'Rent collected from Room 203',
                        '1 hour ago',
                        Icons.payments_outlined,
                        Colors.green
                    ),
                    Divider(color: Colors.grey.shade200),
                    _buildActivityItem(
                        'Maintenance request: AC repair',
                        'Yesterday',
                        Icons.handyman_outlined,
                        Colors.orange
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _propertiesBody() {
    final propertyRepository = context.read<PropertyRepository>();

    return ChangeNotifierProvider(
      create: (_) => BusinessPropertiesViewModel(propertyRepository: propertyRepository)..loadProperties(),
      child: props_view.BusinessPropertiesView(
        onAddProperty: _goToAddProperty,
        onPropertySelected: (property) {
          if (property.id != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ViewPropertyScreen(propertyId: property.id!),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cannot view property: ID is missing')),
            );
          }
        },
      ),
    );
  }

  Widget _tenantsPlaceholder() {
    return Center(
      child: Text(
        'Tenants coming soon',
        style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 16,
            fontWeight: FontWeight.w600
        ),
      ),
    );
  }

  Widget _reportsPlaceholder() {
    return Center(
      child: Text(
        'Reports coming soon',
        style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 16,
            fontWeight: FontWeight.w600
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              offset: const Offset(0, 4)
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16)
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }
}