// lib/presentation/views/business/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../view_models/add_property_viewmodel.dart';
import 'package:firebase_services/services/image_service.dart';
import 'package:firebase_services/repositories/property_repository.dart';
import './add_property_screen.dart';
import './business_properties_screen.dart' as props_view;
import '../view_models/business_properties_viewmodel.dart';
import '../view_models/business_dashboard_viewmodel.dart';
import './view_property_screen.dart';
import './reports_screen.dart';
import './add_tenant_screen.dart';
import './business_profile_screen.dart';
import './pending_payments_screen.dart';
import 'widgets/business_scaffold.dart';
import '../../data/providers/business_state_provider.dart';
import '../../utils/permissions.dart';

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

  final int _currentIndex = 0;

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
    final businessState = Provider.of<BusinessStateProvider>(context, listen: false);
    final perms = BusinessPermissions.fromRole(businessState.role);
    if (!perms.canEditRooms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only owners can add properties.')),
      );
      return;
    }
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

  void _goToPendingPayments() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PendingPaymentsScreen(businessId: widget.businessId),
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
          _reportsBody(),
          const BusinessProfileScreen(),
        ],
      ),
    );
  }

  Widget _dashboardBody() {
    final propertyRepository = context.read<PropertyRepository>();
    final businessState = context.watch<BusinessStateProvider>();

    return ChangeNotifierProvider(
      create: (_) => BusinessDashboardViewModel(propertyRepository: propertyRepository),
      child: _DashboardLoader(
        businessId: businessState.businessId,
        child: Consumer<BusinessDashboardViewModel>(
          builder: (context, viewModel, _) {
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
                            value: viewModel.isLoading ? '...' : viewModel.totalProperties.toString(),
                            icon: Icons.apartment_outlined,
                            color: Colors.teal.shade600,
                          ),
                          _buildStatCard(
                            title: 'Occupancy Rate',
                            value: viewModel.isLoading ? '...' : viewModel.occupancyRateString,
                            icon: Icons.people_outline,
                            color: Colors.orange.shade600,
                          ),
                          _buildStatCard(
                            title: 'Pending Payments',
                            value: viewModel.isLoading ? '...' : viewModel.pendingRentString,
                            icon: Icons.account_balance_wallet_outlined,
                            color: Colors.red.shade600,
                          ),
                          _buildStatCard(
                            title: 'Active Tenants',
                            value: viewModel.isLoading ? '...' : viewModel.activeTenants.toString(),
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
                      icon: Icons.payment_outlined,
                      label: 'Pending Payments',
                      color: Colors.green.shade600,
                      onTap: _goToPendingPayments,
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
              _RecentActivityFeed(businessId: businessState.businessId),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
            );
          },
        ),
      ),
    );
  }

  Widget _propertiesBody() {
    final propertyRepository = context.read<PropertyRepository>();
    final businessState = context.watch<BusinessStateProvider>();

    return ChangeNotifierProvider(
      create: (_) => BusinessPropertiesViewModel(propertyRepository: propertyRepository),
      child: _PropertiesLoader(
        businessId: businessState.businessId,
        child: Consumer<BusinessPropertiesViewModel>(
          builder: (context, viewModel, _) {
            return props_view.BusinessPropertiesView(
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
            );
          },
        ),
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

  Widget _reportsBody() {
    final propertyRepository = context.read<PropertyRepository>();
    final businessState = context.watch<BusinessStateProvider>();

    return ChangeNotifierProvider(
      create: (_) => BusinessPropertiesViewModel(propertyRepository: propertyRepository),
      child: _PropertiesLoader(
        businessId: businessState.businessId,
        child: const ReportsScreen(),
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

}

// ─── Real-time Recent Activity Feed ───────────────────────────────────────────

class _RecentActivityFeed extends StatelessWidget {
  final String? businessId;
  const _RecentActivityFeed({required this.businessId});

  @override
  Widget build(BuildContext context) {
    if (businessId == null || businessId!.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('audit_logs')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.history_toggle_off, size: 40, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('No recent activity yet', style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: List.generate(docs.length, (i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final action = data['action'] as String? ?? '';
              final entityType = data['entityType'] as String? ?? '';
              final entityId = data['entityId'] as String? ?? '';
              final createdAt = data['createdAt'] as Timestamp?;

              final label = _activityLabel(action, entityType, entityId);
              final icon = _activityIcon(action);
              final color = _activityColor(action);
              final timeStr = createdAt != null ? _timeAgo(createdAt.toDate()) : '';

              return Column(
                children: [
                  _ActivityRow(label: label, time: timeStr, icon: icon, color: color),
                  if (i < docs.length - 1) Divider(color: Colors.grey.shade200),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  String _activityLabel(String action, String entityType, String entityId) {
    switch (action) {
      case 'tenant_created':
        return 'New tenant added';
      case 'tenant_deleted':
        return 'Tenant removed';
      case 'bed_occupied':
        return 'Bed assigned to tenant';
      case 'bed_vacated':
        return 'Bed vacated';
      case 'property_access_granted':
        return 'Property access granted to member';
      case 'property_access_revoked':
        return 'Property access revoked from member';
      case 'member_role_changed':
        return 'Member role updated';
      default:
        // Humanise snake_case fallback
        return action.replaceAll('_', ' ').replaceFirstMapped(
          RegExp(r'^.'),
          (m) => m.group(0)!.toUpperCase(),
        );
    }
  }

  IconData _activityIcon(String action) {
    switch (action) {
      case 'tenant_created':
        return Icons.person_add_alt_1_outlined;
      case 'tenant_deleted':
        return Icons.person_remove_outlined;
      case 'bed_occupied':
        return Icons.bed_outlined;
      case 'bed_vacated':
        return Icons.hotel_outlined;
      case 'property_access_granted':
      case 'property_access_revoked':
        return Icons.key_outlined;
      case 'member_role_changed':
        return Icons.manage_accounts_outlined;
      default:
        return Icons.history_outlined;
    }
  }

  Color _activityColor(String action) {
    switch (action) {
      case 'tenant_created':
      case 'bed_occupied':
      case 'property_access_granted':
        return Colors.blue;
      case 'tenant_deleted':
      case 'bed_vacated':
      case 'property_access_revoked':
        return Colors.red;
      case 'member_role_changed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _ActivityRow extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final Color color;

  const _ActivityRow({
    required this.label,
    required this.time,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper widget that loads properties only when businessId changes
class _PropertiesLoader extends StatefulWidget {
  final String? businessId;
  final Widget child;

  const _PropertiesLoader({
    required this.businessId,
    required this.child,
  });

  @override
  State<_PropertiesLoader> createState() => _PropertiesLoaderState();
}

class _PropertiesLoaderState extends State<_PropertiesLoader> {
  String? _lastLoadedBusinessId;

  @override
  void didUpdateWidget(_PropertiesLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Load properties only when businessId changes
    if (oldWidget.businessId != widget.businessId && 
        widget.businessId != null && 
        widget.businessId!.isNotEmpty) {
      _lastLoadedBusinessId = widget.businessId;
      Future.microtask(() {
        if (mounted) {
          final viewModel = context.read<BusinessPropertiesViewModel>();
          viewModel.loadProperties(widget.businessId);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Initial load on first build
    if (widget.businessId != null && widget.businessId!.isNotEmpty) {
      _lastLoadedBusinessId = widget.businessId;
      Future.microtask(() {
        if (mounted) {
          final viewModel = context.read<BusinessPropertiesViewModel>();
          viewModel.loadProperties(widget.businessId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// Helper widget that loads dashboard metrics only when businessId changes
class _DashboardLoader extends StatefulWidget {
  final String? businessId;
  final Widget child;

  const _DashboardLoader({
    required this.businessId,
    required this.child,
  });

  @override
  State<_DashboardLoader> createState() => _DashboardLoaderState();
}

class _DashboardLoaderState extends State<_DashboardLoader> {
  String? _lastLoadedBusinessId;

  @override
  void didUpdateWidget(_DashboardLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId && 
        widget.businessId != null && 
        widget.businessId!.isNotEmpty) {
      _lastLoadedBusinessId = widget.businessId;
      Future.microtask(() {
        if (mounted) {
          final viewModel = context.read<BusinessDashboardViewModel>();
          viewModel.loadDashboardMetrics(widget.businessId);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.businessId != null && widget.businessId!.isNotEmpty) {
      _lastLoadedBusinessId = widget.businessId;
      Future.microtask(() {
        if (mounted) {
          final viewModel = context.read<BusinessDashboardViewModel>();
          viewModel.loadDashboardMetrics(widget.businessId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}



