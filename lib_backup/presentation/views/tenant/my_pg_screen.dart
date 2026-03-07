import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/tenant_scaffold.dart';
import 'pg_detail_screen.dart';
import 'package:onestay360/data/providers/tenant_state_provider.dart';

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
                  FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: tenantState.tenantId.isNotEmpty
                        ? FirebaseFirestore.instance.collection('tenants').doc(tenantState.tenantId).get()
                        : null,
                    builder: (context, snapshot) {
                      final data = snapshot.hasData && (snapshot.data?.exists ?? false)
                          ? snapshot.data!.data()!
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
              child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: tenantState.tenantId.isNotEmpty
                    ? FirebaseFirestore.instance
                        .collection('tenants')
                        .doc(tenantState.tenantId)
                        .get()
                    : null,
                builder: (context, snapshot) {
                  final tenantData = snapshot.hasData && (snapshot.data?.exists ?? false)
                      ? snapshot.data!.data()
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
                        debugPrint('[MyPG] Loaded room data: ' + roomData.toString());
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
                              debugPrint('[MyPG] Fallback room query data: ' + fbRoomData.toString());
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
                            final fbSharingText = fbCapacity != null ? '${fbCapacity} Person' : '—';

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

                      final sharingText = capacity != null ? '${capacity} Person' : '—';

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

            _buildPaymentItem('November 2024', '₹12,000', 'Paid', true),
            _buildPaymentItem('October 2024', '₹12,000', 'Paid', true),
            _buildPaymentItem('September 2024', '₹12,000', 'Paid', true),
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

  Widget _buildPaymentItem(String month, String amount, String status, bool isPaid) {
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
              color: isPaid
                  ? const Color(0xFF34d399).withOpacity(0.1)
                  : const Color(0xFFf97316).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
              color: isPaid ? const Color(0xFF34d399) : const Color(0xFFf97316),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  month,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF164e63),
                    fontFamily: 'Geist',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: isPaid ? const Color(0xFF34d399) : const Color(0xFFf97316),
                    fontFamily: 'Manrope',
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF164e63),
              fontFamily: 'Geist',
            ),
          ),
        ],
      ),
    );
  }
}