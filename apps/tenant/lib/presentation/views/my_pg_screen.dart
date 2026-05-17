import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/tenant_scaffold.dart';
import 'pg_detail_screen.dart';
import 'rent_payment_screen.dart';
import '../../data/providers/tenant_state_provider.dart';

class MyPGScreen extends StatelessWidget {
  const MyPGScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tenantState = Provider.of<TenantStateProvider>(context, listen: true);

    return TenantScaffold(
      currentTab: TenantTab.mypg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PG Details Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFF3b82f6).withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          color: Color(0xFF3b82f6),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tenantState.currentPG.isNotEmpty ? tenantState.currentPG : 'No PG Assigned',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF164e63),
                                fontFamily: 'Geist',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tenantState.propertyId.isNotEmpty ? 'Assigned • Tap for details' : 'Not assigned yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontFamily: 'Manrope',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    future: tenantState.tenantId.isNotEmpty
                        ? FirebaseFirestore.instance.collection('tenants').doc(tenantState.tenantId).collection('stays').where('status', isEqualTo: 'active').limit(1).get()
                        : null,
                    builder: (context, snapshot) {
                      final data = snapshot.hasData && snapshot.data!.docs.isNotEmpty
                          ? snapshot.data!.docs.first.data()
                          : null;
                      final rent = (data != null ? (data['monthlyRent'] as num?)?.toInt() : null);
                      final checkInTs = data != null ? data['checkInDate'] : null;
                      DateTime? checkIn;
                      if (checkInTs is Timestamp) checkIn = checkInTs.toDate();
                      final dueLabel = checkIn != null ? 'Every ${checkIn.day}' : '—';

                      return Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              'Monthly Rent',
                              rent != null ? '₹$rent' : '—',
                              Icons.payment_rounded,
                              const Color(0xFF3b82f6),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoItem(
                              'Due Date',
                              dueLabel,
                              Icons.calendar_today_rounded,
                              const Color(0xFFf97316),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: tenantState.propertyId.isNotEmpty
                          ? () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PGDetailScreen(
                                    propertyId: tenantState.propertyId,
                                  ),
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3b82f6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        tenantState.propertyId.isNotEmpty ? 'View PG Details' : 'Awaiting Assignment',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Geist',
                        ),
                      ),
                    ),
                  ),
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
                color: Color(0xFF164e63),
                fontFamily: 'Geist',
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'Payment History',
                    Icons.history_rounded,
                    const Color(0xFF34d399),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: tenantState.propertyId.isNotEmpty
                        ? () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PGDetailScreen(
                                  propertyId: tenantState.propertyId,
                                ),
                              ),
                            );
                          }
                        : null,
                    child: _buildActionCard(
                      'PG Details',
                      Icons.info_rounded,
                      const Color(0xFF3b82f6),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    'Contact',
                    Icons.phone_rounded,
                    const Color(0xFFec4899),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Room Details
            const Text(
              'Room Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF164e63),
                fontFamily: 'Geist',
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
                    color: Colors.black.withAlpha((0.05 * 255).round()),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                future: tenantState.tenantId.isNotEmpty
                    ? FirebaseFirestore.instance
                        .collection('tenants')
                        .doc(tenantState.tenantId)
                        .collection('stays')
                        .where('status', isEqualTo: 'active')
                        .limit(1)
                        .get()
                    : null,
                builder: (context, snapshot) {
                  final tenantData = snapshot.hasData && snapshot.data!.docs.isNotEmpty
                      ? snapshot.data!.docs.first.data()
                      : null;
                  final roomId = tenantData != null ? (tenantData['roomId']?.toString() ?? '') : '';
                  final bedId = tenantData != null ? (tenantData['bedId']?.toString() ?? '') : '';

                  final businessId = tenantData != null ? (tenantData['businessId']?.toString() ?? '') : '';
                  Future<DocumentSnapshot<Map<String, dynamic>>>? roomDocFuture;
                  // Fallback: derive businessId from propertyId if missing (e.g. BUS0000001PNR001 -> BUS0000001)
                  String derivedBusinessId = '';
                  if (businessId.isEmpty && tenantState.propertyId.isNotEmpty) {
                    final prop = tenantState.propertyId;
                    final match = RegExp(r'^(BUS\d+)').firstMatch(prop);
                    if (match != null) derivedBusinessId = match.group(1)!;
                  }
                  final effectiveBusinessId = businessId.isNotEmpty ? businessId : derivedBusinessId;
                  if (effectiveBusinessId.isNotEmpty && tenantState.propertyId.isNotEmpty && roomId.isNotEmpty) {
                    debugPrint('[MyPG] Room fetch params businessId=$effectiveBusinessId propertyId=${tenantState.propertyId} roomId=$roomId');
                    roomDocFuture = FirebaseFirestore.instance
                        .collection('businesses')
                        .doc(effectiveBusinessId)
                        .collection('properties')
                        .doc(tenantState.propertyId)
                        .collection('rooms')
                        .doc(roomId)
                        .get();
                  } else {
                    debugPrint('[MyPG] Skipping room fetch businessId="$businessId" derived="$derivedBusinessId" propertyId="${tenantState.propertyId}" roomId="$roomId"');
                  }

                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: roomDocFuture,
                    builder: (context, roomSnap) {
                      if (roomDocFuture == null) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDetailItem('Room', roomId.isNotEmpty ? roomId : '—'),
                                ),
                                Expanded(
                                  child: _buildDetailItem('Bed', bedId.isNotEmpty ? bedId : '—'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: const [
                                Expanded(child: Text('Room Type —')),
                                Expanded(child: Text('Sharing —')),
                              ],
                            ),
                          ],
                        );
                      }

                      if (roomSnap.connectionState == ConnectionState.waiting) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDetailItem('Room', roomId.isNotEmpty ? roomId : '—'),
                                ),
                                Expanded(
                                  child: _buildDetailItem('Bed', bedId.isNotEmpty ? bedId : '—'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Room Type',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF475569),
                                          fontFamily: 'Manrope',
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Sharing',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF475569),
                                          fontFamily: 'Manrope',
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      Map<String, dynamic>? roomData;
                      if (roomSnap.hasData && (roomSnap.data?.exists ?? false)) {
                        roomData = roomSnap.data!.data();
                        debugPrint('[MyPG] Loaded room data: $roomData');
                      }
                      if (roomSnap.hasError) {
                        roomData = null;
                        debugPrint('[MyPG] Room load error: ${roomSnap.error}');
                      }

                      // Fallback: if direct doc didn't return data, try querying by roomNumber within the property path
                      if (roomData == null && effectiveBusinessId.isNotEmpty && tenantState.propertyId.isNotEmpty && roomId.isNotEmpty) {
                        final fbFuture = FirebaseFirestore.instance
                            .collection('businesses')
                            .doc(effectiveBusinessId)
                            .collection('properties')
                            .doc(tenantState.propertyId)
                            .collection('rooms')
                            .where('roomNumber', isEqualTo: roomId)
                            .limit(1)
                            .get();
                        return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          future: fbFuture,
                          builder: (context, fbSnap) {
                            Map<String, dynamic>? fbRoomData;
                            if (fbSnap.hasData && fbSnap.data != null && fbSnap.data!.docs.isNotEmpty) {
                              fbRoomData = fbSnap.data!.docs.first.data();
                              debugPrint('[MyPG] Fallback room query data: $fbRoomData');
                            }

                            final fbCapacity = fbRoomData != null ? (fbRoomData['sharingType'] as num?)?.toInt() : null;
                            final fbHasAc = fbRoomData != null ? (fbRoomData['hasAC'] as bool?) == true : null;
                            final fbTypeRaw = fbRoomData != null ? (fbRoomData['occupancyType']?.toString() ?? '') : '';

                            String fbRoomTypeText;
                            if (fbTypeRaw.isNotEmpty) {
                              fbRoomTypeText = fbTypeRaw.toLowerCase();
                            } else if (fbCapacity != null) {
                              fbRoomTypeText = fbCapacity == 1 ? 'single' : fbCapacity == 2 ? 'double' : 'triple';
                            } else {
                              fbRoomTypeText = '—';
                            }
                            if (fbHasAc == true && fbRoomTypeText != '—') {
                              fbRoomTypeText = '$fbRoomTypeText AC';
                            }
                            final fbSharingText = fbCapacity != null ? '$fbCapacity Person' : '—';

                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailItem('Room', roomId.isNotEmpty ? roomId : '—'),
                                    ),
                                    Expanded(
                                      child: _buildDetailItem('Bed', bedId.isNotEmpty ? bedId : '—'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailItem(
                                        'Room Type',
                                        fbRoomTypeText != '—'
                                            ? fbRoomTypeText[0].toUpperCase() + fbRoomTypeText.substring(1)
                                            : '—',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildDetailItem('Sharing', fbSharingText),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        );
                      }

                      final capacity = roomData != null ? (roomData['sharingType'] as num?)?.toInt() : null;
                      final hasAc = roomData != null ? (roomData['hasAC'] as bool?) == true : null;
                      final typeRaw = roomData != null ? (roomData['occupancyType']?.toString() ?? '') : '';

                      String roomTypeText;
                      if (typeRaw.isNotEmpty) {
                        roomTypeText = typeRaw.toLowerCase();
                      } else if (capacity != null) {
                        roomTypeText = capacity == 1 ? 'single' : capacity == 2 ? 'double' : 'triple';
                      } else {
                        roomTypeText = '—';
                      }
                      if (hasAc == true && roomTypeText != '—') {
                        roomTypeText = '$roomTypeText AC';
                      }

                      // If we have no roomData but params are correct, surface a hint
                      final showHint = roomData == null && effectiveBusinessId.isNotEmpty && tenantState.propertyId.isNotEmpty && roomId.isNotEmpty;

                      final sharingText = capacity != null ? '$capacity Person' : '—';

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailItem('Room', roomId.isNotEmpty ? roomId : '—'),
                              ),
                              Expanded(
                                child: _buildDetailItem('Bed', bedId.isNotEmpty ? bedId : '—'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailItem(
                                  'Room Type',
                                  roomTypeText != '—'
                                      ? roomTypeText[0].toUpperCase() + roomTypeText.substring(1)
                                      : '—',
                                ),
                              ),
                              Expanded(
                                child: _buildDetailItem('Sharing', sharingText),
                              ),
                            ],
                          ),
                          if (showHint) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Room details unavailable. Verify tenant doc fields (businessId, propertyId, roomId) and room doc path.',
                              style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Amenities
            const Text(
              'Amenities',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF164e63),
                fontFamily: 'Geist',
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
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildAmenityChip('WiFi', Icons.wifi_rounded),
                  _buildAmenityChip('AC', Icons.ac_unit_rounded),
                  _buildAmenityChip('Meals', Icons.restaurant_rounded),
                  _buildAmenityChip('Laundry', Icons.local_laundry_service_rounded),
                  _buildAmenityChip('Parking', Icons.local_parking_rounded),
                  _buildAmenityChip('Security', Icons.security_rounded),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Rent Invoice Status (Dynamic) ──
            if (tenantState.businessId.isNotEmpty && tenantState.tenantId.isNotEmpty)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('businesses')
                    .doc(tenantState.businessId)
                    .collection('tenants')
                    .doc(tenantState.tenantId)
                    .collection('rent_invoices')
                    .where('status', whereIn: ['unpaid', 'overdue'])
                    .snapshots(),
                builder: (context, invoiceSnap) {
                  if (invoiceSnap.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }

                  final invoiceDocs = invoiceSnap.data?.docs ?? [];

                  if (invoiceDocs.isEmpty) {
                    // All caught up!
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF10b981), Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF10b981).withAlpha(60),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'All Caught Up! ✅',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Geist',
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'No pending rent payments',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                    fontFamily: 'Manrope',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // There is an unpaid or overdue invoice
                  final invoiceData = invoiceDocs.first.data() as Map<String, dynamic>;
                  final invoiceId = invoiceDocs.first.id;
                  final amount = (invoiceData['amount'] as num?)?.toInt() ?? 0;
                  final month = invoiceData['month'] ?? '';
                  final isOverdue = invoiceData['status'] == 'overdue';

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isOverdue
                            ? [Color(0xFFef4444), Color(0xFFdc2626)]
                            : [Color(0xFFf97316), Color(0xFFea580c)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (isOverdue ? Color(0xFFef4444) : Color(0xFFf97316)).withAlpha(60),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(40),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isOverdue ? Icons.warning_rounded : Icons.payment_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isOverdue ? '⚠️ Rent Overdue!' : '💰 Rent Due',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontFamily: 'Geist',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹$amount for $month',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      fontFamily: 'Geist',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RentPaymentScreen(
                                    prefilledAmount: amount,
                                    prefilledMonth: month,
                                    rentInvoiceId: invoiceId,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: isOverdue ? Color(0xFFef4444) : Color(0xFFf97316),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              isOverdue ? 'Pay Now — Overdue!' : 'Pay Rent',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Geist',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            // Recent Payments
            const Text(
              'Recent Payments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF164e63),
                fontFamily: 'Geist',
              ),
            ),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: tenantState.businessId.isNotEmpty && tenantState.tenantId.isNotEmpty
                  ? FirebaseFirestore.instance
                      .collection('businesses')
                      .doc(tenantState.businessId)
                      .collection('tenants')
                      .doc(tenantState.tenantId)
                      .collection('payments')
                      .orderBy('date', descending: true)
                      .limit(5)
                      .snapshots()
                  : null,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(),
                  ));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'No payment history yet',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontFamily: 'Manrope',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: List.generate(docs.length, (index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _buildPaymentItem(data, index, docs.length);
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              fontFamily: 'Manrope',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'Geist',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
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
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF164e63),
                fontFamily: 'Geist',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF475569),
            fontFamily: 'Manrope',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF164e63),
            fontFamily: 'Geist',
          ),
        ),
      ],
    );
  }

  Widget _buildAmenityChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFecfeff),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFe5e7eb)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF3b82f6)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              fontFamily: 'Manrope',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(Map<String, dynamic> payment, int index, int totalCount) {
    final isPaid = payment['status'] == 'Paid' || payment['status'] == 'paid';
    final status = payment['status'] ?? 'pending';

    Color getStatusColor() {
      if (isPaid) return Colors.green;
      if (status.toLowerCase() == 'pending_verification') return Colors.orange;
      if (status.toLowerCase() == 'rejected') return Colors.red;
      return Colors.blue;
    }

    String formatStatus() {
      if (status == 'pending_verification') return 'Pending';
      if (isPaid) return 'Paid';
      if (status.toLowerCase() == 'rejected') return 'Rejected';
      return status.toString()[0].toUpperCase() + status.toString().substring(1);
    }

    String formattedDate = '';
    if (payment['date'] != null) {
      if (payment['date'] is Timestamp) {
        final date = (payment['date'] as Timestamp).toDate();
        final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        formattedDate = '${date.day} ${months[date.month - 1]} ${date.year}';
      }
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPaid ? Colors.green : Colors.orange,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isPaid ? Icons.check : Icons.schedule,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
                if (index < totalCount - 1)
                  Container(width: 2, height: 100, color: Colors.grey.shade300),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: getStatusColor().withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          payment['month'] ?? 'Unknown',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: getStatusColor(),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            formatStatus(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹${payment['amount'] ?? 0}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'via ${payment['method'] ?? 'N/A'}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        if (formattedDate.isNotEmpty)
                          Text(
                            formattedDate,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                    if (payment['status'] == 'rejected' && payment['rejectionReason'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Reason: ${payment['rejectionReason']}',
                        style: const TextStyle(fontSize: 12, color: Colors.red, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

