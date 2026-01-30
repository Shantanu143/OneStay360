// lib/presentation/views/business/widgets/business_scaffold.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../business_profile_screen.dart';
import '../business_properties_screen.dart';
import '../home_screen.dart';
import '../add_tenant_screen.dart';
import '../view_property_screen.dart';
import '../create_business_screen.dart';
import '../team_screen.dart';
import '../business_notifications_screen.dart';
import '../../../data/providers/business_state_provider.dart';
import '../../../data/providers/business_notifications_provider.dart';
import '../../../utils/permissions.dart';

enum BusinessTab { dashboard, properties, tenants, team, reports, profile }

class _NavItem {
  final BusinessTab tab;
  final IconData icon;
  final String label;
  const _NavItem(this.tab, this.icon, this.label);
}

class BusinessScaffold extends StatefulWidget {
  final Widget body;
  final BusinessTab currentTab;
  final Widget? title;
  final String? titleText;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBarBottom;
  final FloatingActionButton? floatingActionButton;
  final Color primaryColor;
  final bool showBackButton;
  final String? businessId;

  const BusinessScaffold({
    super.key,
    required this.body,
    required this.currentTab,
    this.title,
    this.titleText,
    this.actions,
    this.appBarBottom,
    this.floatingActionButton,
    this.primaryColor = const Color(0xFF0D9488),
    this.showBackButton = false,
    this.businessId,
  });

  @override
  State<BusinessScaffold> createState() => _BusinessScaffoldState();
}

class _BusinessScaffoldState extends State<BusinessScaffold> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _requestsCountSub;
  String? _lastBusinessId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // NOTE: BusinessStateProvider.loadUserData() is already called in login flow
    // It MUST be called after EnsureUserDocumentService.ensureUserDocumentExists()
    // Do NOT call it here - that would break the bootstrap order and cause permission-denied errors
    // 
    // Listeners are managed via _listenPendingRequests() called from didUpdateWidget and build
  }

  @override
  void didUpdateWidget(BusinessScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Manage listener subscription only when businessId changes, not on every build
    final businessState = Provider.of<BusinessStateProvider>(context, listen: false);
    final businessId = businessState.businessId;
    
    if (_lastBusinessId != businessId) {
      _lastBusinessId = businessId;
      _listenPendingRequests(businessId);
    }
  }

  @override
  void dispose() {
    _requestsCountSub?.cancel();
    super.dispose();
  }

  void _listenPendingRequests(String? businessId) {
    // Guard: Only listen if businessId is available
    if (businessId == null || businessId.isEmpty) {
      _requestsCountSub?.cancel();
      _requestsCountSub = null;
      return;
    }

    // Cancel previous subscription if any
    _requestsCountSub?.cancel();

    // Start new subscription ONLY when businessId is non-null
    _requestsCountSub = FirebaseFirestore.instance
        .collection('enrollmentRequests')
        .where('businessId', isEqualTo: businessId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      // Guard: Ensure we still have context (widget not disposed)
      if (!mounted) return;
      
      final businessState = Provider.of<BusinessStateProvider>(context, listen: false);
      businessState.updatePendingRequestsCount(snapshot.size);
    }, onError: (e) {
      debugPrint('Error listening to requests: $e');
    });
  }

  List<_NavItem> _navItemsForRole(String role) {
    const allItems = [
      _NavItem(BusinessTab.dashboard, Icons.dashboard_outlined, 'Dashboard'),
      _NavItem(BusinessTab.properties, Icons.apartment_outlined, 'Properties'),
      _NavItem(BusinessTab.tenants, Icons.people_outline, 'Tenants'),
      _NavItem(BusinessTab.team, Icons.group_outlined, 'Team'),
      _NavItem(BusinessTab.reports, Icons.analytics_outlined, 'Reports'),
      _NavItem(BusinessTab.profile, Icons.person_outline, 'Profile'),
    ];

    if (role == 'owner') {
      return allItems;
    }

    // Managers and staff see a trimmed navigation without Team/Reports.
    return const [
      _NavItem(BusinessTab.dashboard, Icons.dashboard_outlined, 'Dashboard'),
      _NavItem(BusinessTab.properties, Icons.apartment_outlined, 'Properties'),
      _NavItem(BusinessTab.tenants, Icons.people_outline, 'Tenants'),
      _NavItem(BusinessTab.profile, Icons.person_outline, 'Profile'),
    ];
  }

  Widget _buildDefaultTitle(BusinessStateProvider businessState) {
    // If custom title is provided, use it (view_property_screen uses this)
    if (widget.title != null) {
      // For screens like view_property_screen that use custom title,
      // we still want to show the personalized header structure
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Welcome back',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          widget.title!, // Use the custom title but in our header structure
        ],
      );
    }

    // Show personalized header on ALL screens
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          businessState.fullName.isNotEmpty
              ? businessState.fullName
              : (businessState.businessName.isNotEmpty
              ? businessState.businessName
              : 'Business'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  List<Widget> _buildDefaultActions(
      BuildContext context, BusinessStateProvider businessState) {
    debugPrint('🛎️ BUILDING ACTIONS - Notification bell should be VISIBLE');

    final notificationsProvider =
        Provider.of<BusinessNotificationsProvider>(context);
    final unreadCount = notificationsProvider.unreadCount;

    Widget buildNotificationButton() {
      return Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none,
              size: 24,
              color: Colors.black87,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _openNotifications(context);
            },
          ),
          if (unreadCount > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    final Widget notificationIcon = buildNotificationButton();

    // Create the inbox icon
    final inboxIcon = Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(
            Icons.inbox_outlined,
            size: 24,
            color: Colors.black87, // Force black color
          ),
          onPressed: () => _openLatestRequest(context),
        ),
        if (businessState.pendingRequestsCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                businessState.pendingRequestsCount > 9 ? '9+' : '${businessState.pendingRequestsCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );

    // Create the settings icon
    final settingsIcon = IconButton(
      icon: const Icon(
        Icons.settings,
        size: 24,
        color: Colors.black87, // Force black color
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
        );
      },
    );

    // ALWAYS include these three icons in this exact order
    final List<Widget> actions = [
      notificationIcon, // Notification bell - FIRST
      inboxIcon,        // Requests inbox - SECOND
      settingsIcon,     // Settings - THIRD
    ];

    debugPrint('🛎️ Actions count: ${actions.length}');
    debugPrint('🛎️ First action type: ${actions.first.runtimeType}');

    return actions;
  }

  Future<void> _openLatestRequest(BuildContext context) async {
    HapticFeedback.lightImpact();
    final businessId = widget.businessId;
    if (businessId == null || businessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business ID not available')),
      );
      return;
    }

    try {
      final qs = await FirebaseFirestore.instance
          .collection('enrollmentRequests')
          .where('businessId', isEqualTo: businessId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (qs.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pending requests')),
        );
        return;
      }

      final doc = qs.docs.first;
      final data = doc.data();
      final propertyId = data['propertyId']?.toString();

      if (propertyId == null || propertyId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request missing property reference')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewPropertyScreen(
            propertyId: propertyId,
            initialTabIndex: ViewPropertyScreen.requestsTabIndex,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error opening latest request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open request: $e')),
      );
    }
  }

  void _openNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BusinessNotificationsScreen(),
      ),
    );
  }

  String _getDefaultTitle(BusinessTab tab) {
    switch (tab) {
      case BusinessTab.dashboard:
        return 'Dashboard';
      case BusinessTab.properties:
        return 'Properties';
      case BusinessTab.tenants:
        return 'Tenants';
      case BusinessTab.team:
        return 'Team';
      case BusinessTab.reports:
        return 'Reports';
      case BusinessTab.profile:
        return 'Profile';
    }
  }

  Future<String> _getBusinessId() async {
    if (widget.businessId != null && widget.businessId!.isNotEmpty) {
      return widget.businessId!;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        return userData['businessId'] as String? ?? user.uid;
      }
      return user.uid;
    }

    return 'default_business_id';
  }

  void _handleNavTap(BuildContext context, BusinessTab targetTab) async {
    HapticFeedback.lightImpact();

    if (targetTab == widget.currentTab) return;

    final actualBusinessId = await _getBusinessId();

    switch (targetTab) {
      case BusinessTab.dashboard:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => BusinessHomeScreen(businessId: actualBusinessId),
          ),
              (route) => false,
        );
        break;
      case BusinessTab.properties:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const BusinessPropertiesScreen()),
              (route) => false,
        );
        break;
      case BusinessTab.tenants:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AddTenantScreen()),
              (route) => false,
        );
        break;
      case BusinessTab.team:
        final role = Provider.of<BusinessStateProvider>(context, listen: false).role;
        final perms = BusinessPermissions.fromRole(role);
        if (!perms.canInviteMembers) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Team management is owner-only.')),
          );
          return;
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TeamScreen()),
              (route) => false,
        );
        break;
      case BusinessTab.reports:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reports coming soon')),
        );
        break;
      case BusinessTab.profile:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
              (route) => false,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessStateProvider>(
      builder: (context, businessState, child) {
        // UI Guard: Block all business data loading if no active membership
        final businessId = businessState.businessId;
        if (businessId == null || businessId.isEmpty) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No Active Business',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create or join a business to get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateBusinessScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Business'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (_lastBusinessId != businessId) {
          _lastBusinessId = businessId;
          _listenPendingRequests(businessId);
        }

        final navItems = _navItemsForRole(businessState.role);
        final currentIndex = navItems.indexWhere((item) => item.tab == widget.currentTab);
        final safeIndex = currentIndex >= 0 ? currentIndex : 0;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            titleSpacing: 20,
            leading: widget.showBackButton
                ? IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_ios, color: Colors.grey.shade700, size: 20),
            )
                : null,
            title: _buildDefaultTitle(businessState),
            actions: _buildDefaultActions(context, businessState),
            bottom: widget.appBarBottom,
          ),
          body: widget.body,
          floatingActionButton: widget.floatingActionButton,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: safeIndex,
            backgroundColor: Colors.white,
            selectedItemColor: widget.primaryColor,
            unselectedItemColor: Colors.grey.shade500,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            items: navItems
                .map(
                  (item) => BottomNavigationBarItem(
                    icon: Icon(item.icon),
                    label: item.label,
                  ),
                )
                .toList(),
            onTap: (index) => _handleNavTap(context, navItems[index].tab),
          ),
        );
      },
    );
  }
}