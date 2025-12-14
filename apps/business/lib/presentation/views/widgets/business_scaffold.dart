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
import '../../../data/providers/business_state_provider.dart';

enum BusinessTab { dashboard, properties, tenants, reports, profile }

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
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadInitialData();
      _listenPendingRequests();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _requestsCountSub?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final businessState = Provider.of<BusinessStateProvider>(context, listen: false);
    await businessState.loadUserData();
  }

  void _listenPendingRequests() {
    final businessId = widget.businessId;
    if (businessId == null || businessId.isEmpty) return;

    _requestsCountSub?.cancel();
    _requestsCountSub = FirebaseFirestore.instance
        .collectionGroup('requests')
        .where('businessId', isEqualTo: businessId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      final businessState = Provider.of<BusinessStateProvider>(context, listen: false);
      businessState.updatePendingRequestsCount(snapshot.size);
    }, onError: (e) {
      debugPrint('Error listening to requests: $e');
    });
  }

  int get _currentIndex {
    switch (widget.currentTab) {
      case BusinessTab.dashboard:
        return 0;
      case BusinessTab.properties:
        return 1;
      case BusinessTab.tenants:
        return 2;
      case BusinessTab.reports:
        return 3;
      case BusinessTab.profile:
        return 4;
    }
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

  List<Widget> _buildDefaultActions(BuildContext context, BusinessStateProvider businessState) {
    debugPrint('🛎️ BUILDING ACTIONS - Notification bell should be VISIBLE');

    // FORCEFULLY create the notification icon with explicit styling
    final notificationIcon = IconButton(
      icon: const Icon(
        Icons.notifications_none,
        size: 24,
        color: Colors.black87, // Force black color
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications coming soon')),
        );
      },
    );

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
          .collectionGroup('requests')
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
            initialTabIndex: 4, // Requests tab
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

  String _getDefaultTitle(BusinessTab tab) {
    switch (tab) {
      case BusinessTab.dashboard:
        return 'Dashboard';
      case BusinessTab.properties:
        return 'Properties';
      case BusinessTab.tenants:
        return 'Tenants';
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

  void _handleNavTap(BuildContext context, int index) async {
    HapticFeedback.lightImpact();

    if (index == _currentIndex) return;

    final actualBusinessId = await _getBusinessId();

    switch (index) {
      case 0:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => BusinessHomeScreen(businessId: actualBusinessId),
          ),
              (route) => false,
        );
        break;
      case 1:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const BusinessPropertiesScreen()),
              (route) => false,
        );
        break;
      case 2:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AddTenantScreen()),
              (route) => false,
        );
        break;
      case 3:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reports coming soon')),
        );
        break;
      case 4:
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
            currentIndex: _currentIndex,
            backgroundColor: Colors.white,
            selectedItemColor: widget.primaryColor,
            unselectedItemColor: Colors.grey.shade500,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.apartment_outlined),
                label: 'Properties',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                label: 'Tenants',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.analytics_outlined),
                label: 'Reports',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: 'Profile',
              ),
            ],
            onTap: (index) => _handleNavTap(context, index),
          ),
        );
      },
    );
  }
}