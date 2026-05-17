import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'widgets/tenant_scaffold.dart';
import '../../data/providers/tenant_state_provider.dart';
import 'explore_screen.dart';
import 'my_pg_screen.dart';
import 'tenant_profile_screen.dart';
import 'enroll_request_screen.dart';
import 'bill_review_screen.dart';
import 'rent_payment_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TenantHomeScreen extends StatefulWidget {
  final String? tenantId;
  final String tenantName;

  const TenantHomeScreen({
    super.key,
    this.tenantId,
    required this.tenantName,
  });

  @override
  State<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends State<TenantHomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    _screens.addAll([
      _buildHomeContent(),
      const ExploreScreen(),
      const MyPGScreen(),
      const TenantProfileScreen(),
    ]);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _openEnrollRequest() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EnrollRequestScreen(),
      ),
    );
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
    HapticFeedback.lightImpact();
  }

  // In TenantHomeScreen
  @override
  Widget build(BuildContext context) {
    return TenantScaffold(
      currentTab: TenantTab.home,
      tenantId: widget.tenantId,

      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => HapticFeedback.lightImpact(),
        ),
        IconButton(
          icon: const Icon(Icons.privacy_tip_outlined),
          onPressed: () => HapticFeedback.lightImpact(),
        ),
      ],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Consumer<TenantStateProvider>(
          builder: (context, tenantState, child) {
            final currentUser = FirebaseAuth.instance.currentUser;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
// Removed duplicate header since TenantScaffold handles it
                const SizedBox(height: 8),
                if (currentUser != null)
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .snapshots(),
                    builder: (context, snap) {
                      final data = snap.data?.data();
                      final complete = (data?['profileComplete'] ?? false) == true;
                      if (complete) return const SizedBox.shrink();
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE68A),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_add_alt_1, color: Color(0xFF92400E)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Complete Your Profile',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Add details to speed up your booking.',
                                    style: TextStyle(color: Color(0xFFB45309), fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const TenantProfileScreen()),
                                      );
                                    },
                                    child: const Text(
                                      'Complete Now →',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                
                // Pending Bill Banner
                if (currentUser != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('enrollmentRequests')
                        .where('tenantId', isEqualTo: currentUser.uid)
                        .where('status', isEqualTo: 'bill_sent')
                        .limit(1)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      
                      final doc = snapshot.data!.docs.first;
                      final data = doc.data() as Map<String, dynamic>;
                      final propertyName = data['propertyName'] ?? 'PG';
                      final totalAmount = (data['totalBillAmount'] as num?)?.toDouble() 
                          ?? ((data['depositAmount'] as num?)?.toDouble() ?? 0) + ((data['advanceAmount'] as num?)?.toDouble() ?? 0);
                      
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade600,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '💰 Payment Pending',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFF166534),
                                        ),
                                      ),
                                      Text(
                                        '$propertyName • ₹${totalAmount.toInt()}',
                                        style: const TextStyle(
                                          color: Color(0xFF166534),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BillReviewScreen(
                                        enrollmentRequestId: doc.id,
                                      ),
                                    ),
                                  );
                                },
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: Colors.green.shade600,
                                   foregroundColor: Colors.white,
                                   elevation: 0,
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                   padding: const EdgeInsets.symmetric(vertical: 16),
                                 ),
                                 child: const Text('Pay Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                               ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                // Pending Application Banner
                if (currentUser != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('enrollmentRequests')
                        .where('tenantId', isEqualTo: currentUser.uid)
                        .where('status', isEqualTo: 'pending')
                        .limit(1)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      
                      final doc = snapshot.data!.docs.first;
                      final data = doc.data() as Map<String, dynamic>;
                      final propertyName = data['propertyName'] ?? 'PG';
                      
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFDE68A).withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.hourglass_empty, color: Color(0xFFD97706), size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Application Pending',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: Color(0xFF92400E),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Your request to join $propertyName is currently under review by the owner.',
                                    style: const TextStyle(
                                      color: Color(0xFFB45309),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                
                // Current Accommodation Card
                Builder(
                  builder: (context) {
                    final hasProperty = tenantState.propertyId.isNotEmpty && tenantState.businessId.isNotEmpty;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)], // Premium deep blue gradient
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  hasProperty ? 'CURRENT STAY' : 'NO ACTIVE PG',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              Icon(hasProperty ? Icons.home_work_outlined : Icons.explore, color: Colors.white.withOpacity(0.8), size: 24),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            hasProperty ? tenantState.currentPG : 'Start Exploring PGs',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          hasProperty ? const _HomeLocationRow() : Row(
                            children: [
                              const Icon(Icons.touch_app, color: Colors.white70, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Find your perfect stay today',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha((0.9 * 255).round()),
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }
                ),
                const SizedBox(height: 32),

                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _buildQuickActionCard(
                      'Pay Rent',
                      Icons.account_balance_wallet_outlined,
                      const Color(0xFF10B981),
                      () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RentPaymentScreen()),
                        );
                      },
                    ),
                    _buildQuickActionCard(
                      'Enroll Request',
                      Icons.assignment_turned_in_outlined,
                      const Color(0xFF3B82F6),
                      _openEnrollRequest,
                    ),
                    _buildQuickActionCard(
                      'Maintenance',
                      Icons.build_circle_outlined,
                      const Color(0xFFF43F5E),
                          () => HapticFeedback.lightImpact(),
                    ),
                    _buildQuickActionCard(
                      'Support',
                      Icons.support_agent_outlined,
                      const Color(0xFF8B5CF6),
                          () => HapticFeedback.lightImpact(),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Recent Activity
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(Icons.history_toggle_off, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No recent activity yet',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

// _buildGreetingHeader removed.
  Widget _buildQuickActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, IconData icon, Color color, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeLocationRow extends StatelessWidget {
  const _HomeLocationRow();

  @override
  Widget build(BuildContext context) {
    final tenantState = Provider.of<TenantStateProvider>(context, listen: true);
    final hasProperty = tenantState.propertyId.isNotEmpty;
    final businessId = tenantState.businessId;
    final propertyId = tenantState.propertyId;

    if (!hasProperty || businessId.isEmpty) {
      return Row(
        children: [
          const Icon(Icons.location_on, color: Colors.white70, size: 16),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Location provided upon assignment',
              style: TextStyle(
                color: Colors.white.withAlpha((0.9 * 255).round()),
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('properties')
          .doc(propertyId)
          .snapshots(),
      builder: (context, snapshot) {
        String locationText = 'Location details loading...';
        
        if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final address = data['address'] as String? ?? '';
            final city = data['city'] as String? ?? '';
            locationText = [address, city].where((e) => e.toString().trim().isNotEmpty).join(', ');
            if (locationText.isEmpty) {
                locationText = 'Location details hidden';
            }
        } else if (snapshot.hasError) {
            locationText = 'Location currently unavailable';
        }

        return Row(
          children: [
            const Icon(Icons.location_on, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                locationText,
                style: TextStyle(
                  color: Colors.white.withAlpha((0.9 * 255).round()),
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}

