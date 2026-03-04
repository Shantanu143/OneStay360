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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFF92400E)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Complete your profile',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Add your details once to speed up bookings and verifications.',
                                    style: TextStyle(color: Color(0xFF92400E)),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const TenantProfileScreen()),
                                        );
                                      },
                                      icon: const Icon(Icons.edit_outlined, size: 16),
                                      label: const Text('Complete Profile'),
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
                                ),
                                child: const Text('Pay Now'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                
                // Current Accommodation Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0891B2), Color(0xFF06B6D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF0891B2).withAlpha((0.3 * 255).round()),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Accommodation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tenantState.currentPG.isNotEmpty ? tenantState.currentPG : 'No PG Assigned',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _HomeLocationRow(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    _buildQuickActionCard(
                      'Payments',
                      Icons.payment,
                      const Color(0xFF10B981),
                          () => HapticFeedback.lightImpact(),
                    ),
                    _buildQuickActionCard(
                      'Complaints',
                      Icons.report_problem_outlined,
                      const Color(0xFFF59E0B),
                          () => HapticFeedback.lightImpact(),
                    ),
                    _buildQuickActionCard(
                      'Support',
                      Icons.support_agent,
                      const Color(0xFF8B5CF6),
                          () => HapticFeedback.lightImpact(),
                    ),
                    _buildQuickActionCard(
                      'Maintenance',
                      Icons.build_outlined,
                      const Color(0xFFEF4444),
                          () => HapticFeedback.lightImpact(),
                    ),
                    _buildQuickActionCard(
                      'Enroll Request',
                      Icons.assignment_turned_in_outlined,
                      const Color(0xFF06B6D4),
                      _openEnrollRequest,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

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
                _buildActivityItem(
                  'Rent Payment',
                  'Paid ₹12,000 for December',
                  Icons.payment,
                  const Color(0xFF10B981),
                  '2 days ago',
                ),
                _buildActivityItem(
                  'Complaint Resolved',
                  'WiFi connectivity issue fixed',
                  Icons.check_circle,
                  const Color(0xFF0891B2),
                  '1 week ago',
                ),
                _buildActivityItem(
                  'Maintenance Request',
                  'AC repair scheduled for tomorrow',
                  Icons.build,
                  const Color(0xFFF59E0B),
                  '3 days ago',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.05 * 255).round()),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
              color: color.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
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
    return Row(
      children: [
        const Icon(Icons.location_on, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Text(
          'Andheri West, Mumbai',
            style: TextStyle(
            color: Colors.white.withAlpha((0.9 * 255).round()),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

