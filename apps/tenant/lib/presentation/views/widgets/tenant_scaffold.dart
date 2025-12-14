import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

// Screens
import '../tenant_profile_screen.dart';
import '../explore_screen.dart';
import '../home_screen.dart';
import '../my_pg_screen.dart';
import '../notifications_screen.dart';

// Providers
import '../../../data/providers/tenant_state_provider.dart';

/// Enum for tab control
enum TenantTab { home, explore, mypg, profile }

class TenantScaffold extends StatefulWidget {
  final Widget body;
  final TenantTab currentTab;
  final Widget? title;
  final String? titleText;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBarBottom;
  final FloatingActionButton? floatingActionButton;
  final Color primaryColor;
  final bool showBackButton;
  final String? tenantId;

  const TenantScaffold({
    super.key,
    required this.body,
    required this.currentTab,
    this.title,
    this.titleText,
    this.actions,
    this.appBarBottom,
    this.floatingActionButton,
    this.primaryColor = const Color(0xFF06B6D4),
    this.showBackButton = false,
    this.tenantId,
  });

  @override
  State<TenantScaffold> createState() => _TenantScaffoldState();
}

class _TenantScaffoldState extends State<TenantScaffold> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _tenantDataSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notificationsSub;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadInitialData();
      _listenForNotifications();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _tenantDataSub?.cancel();
    _notificationsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final tenantState = Provider.of<TenantStateProvider>(context, listen: false);
    await tenantState.loadUserData();
  }

  void _listenForNotifications() {
    final tenantId = widget.tenantId;
    if (tenantId == null || tenantId.isEmpty) return;

    // Only listen if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _notificationsSub = FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) {
        final tenantState = Provider.of<TenantStateProvider>(context, listen: false);
        tenantState.updateUnreadNotificationsCount(snapshot.size);
      },
      onError: (e) {
        debugPrint('Error listening to notifications: $e');
      },
    );
  }

  int get _currentIndex {
    switch (widget.currentTab) {
      case TenantTab.home:
        return 0;
      case TenantTab.explore:
        return 1;
      case TenantTab.mypg:
        return 2;
      case TenantTab.profile:
        return 3;
    }
  }

  /// Personalized AppBar title
  Widget _buildDefaultTitle(TenantStateProvider tenantState) {
    if (widget.title != null) {
      // For screens using a custom title (like pg_detail_screen)
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
          widget.title!,
        ],
      );
    }

    // Default personalized header
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
          tenantState.fullName.isNotEmpty ? tenantState.fullName : 'Tenant',
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

  /// AppBar action icons: Notification, Support, Settings
  List<Widget> _buildDefaultActions(BuildContext context, TenantStateProvider tenantState) {
    final notificationIcon = Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none, size: 24, color: Colors.black87),
          onPressed: () => _openNotifications(context),
        ),
        if (tenantState.unreadNotificationsCount > 0)
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
                tenantState.unreadNotificationsCount > 9
                    ? '9+'
                    : '${tenantState.unreadNotificationsCount}',
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

    final supportIcon = IconButton(
      icon: const Icon(Icons.support_agent_outlined, size: 24, color: Colors.black87),
      onPressed: () {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support coming soon')),
        );
      },
    );

    final settingsIcon = IconButton(
      icon: const Icon(Icons.settings, size: 24, color: Colors.black87),
      onPressed: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TenantProfileScreen()),
        );
      },
    );

    return [notificationIcon, supportIcon, settingsIcon];
  }

  Future<void> _openNotifications(BuildContext context) async {
    HapticFeedback.lightImpact();
    final tenantId = await _getTenantId();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(tenantId: tenantId),
      ),
    );
  }

  String _getDefaultTitle(TenantTab tab) {
    switch (tab) {
      case TenantTab.home:
        return 'Home';
      case TenantTab.explore:
        return 'Explore PGs';
      case TenantTab.mypg:
        return 'My PG';
      case TenantTab.profile:
        return 'Profile';
    }
  }

  /// Fetch current tenant ID
  Future<String> _getTenantId() async {
    if (widget.tenantId != null && widget.tenantId!.isNotEmpty) {
      return widget.tenantId!;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        return userData['tenantId'] as String? ?? user.uid;
      }
      return user.uid;
    }

    return 'default_tenant_id';
  }

  /// ✅ Updated Navigation Handler
  void _handleNavTap(BuildContext context, int index) async {
    HapticFeedback.lightImpact();

    if (index == _currentIndex) return;

    final actualTenantId = await _getTenantId();
    final tenantState = Provider.of<TenantStateProvider>(context, listen: false);

    switch (index) {
      case 0:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => TenantHomeScreen(
              tenantId: actualTenantId,
              tenantName: tenantState.fullName, // ✅ Added Tenant Name
            ),
          ),
              (route) => false,
        );
        break;
      case 1:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ExploreScreen()),
              (route) => false,
        );
        break;
      case 2:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MyPGScreen()),
              (route) => false,
        );
        break;
      case 3:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TenantProfileScreen()),
              (route) => false,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TenantStateProvider>(
      builder: (context, tenantState, child) {
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
            title: _buildDefaultTitle(tenantState),
            actions: _buildDefaultActions(context, tenantState),
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
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.explore_outlined),
                activeIcon: Icon(Icons.explore),
                label: 'Explore',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.apartment_outlined),
                activeIcon: Icon(Icons.apartment),
                label: 'My PG',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
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
