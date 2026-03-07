import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Enrollment Requests Screen
/// Displays all enrollment requests for the business owner's properties
class EnrollmentRequestsScreen extends StatefulWidget {
  final String? initialPropertyId;
  final String? initialRequestId;

  const EnrollmentRequestsScreen({
    super.key,
    this.initialPropertyId,
    this.initialRequestId,
  });

  @override
  State<EnrollmentRequestsScreen> createState() => _EnrollmentRequestsScreenState();
}

class _EnrollmentRequestsScreenState extends State<EnrollmentRequestsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _businessId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBusinessId();
  }

  Future<void> _loadBusinessId() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _businessId = userDoc.data()?['businessId'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading business ID: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enrollment Requests'),
        backgroundColor: const Color(0xFF06B6D4),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _businessId == null
              ? const Center(child: Text('No business found'))
              : StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('enrollmentRequests')
                    .where('businessId', isEqualTo: _businessId)
                    .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final requests = snapshot.data?.docs ?? [];

                    if (requests.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No enrollment requests yet',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: requests.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final request = requests[index].data() as Map<String, dynamic>;
                        final requestId = requests[index].id;
                        return _buildRequestCard(requestId, request);
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildRequestCard(String requestId, Map<String, dynamic> request) {
    final tenantName = request['tenantName'] as String? ?? 'Unknown';
    final tenantPhone = request['tenantPhone'] as String? ?? '';
    final propertyId = request['propertyId'] as String? ?? '';
    final propertyName = request['propertyName'] as String? ?? '';
    final status = request['status'] as String? ?? 'pending';
    final moveInDate = request['moveInDate'] as Timestamp?;
    final createdAt = request['createdAt'] as Timestamp?;
    final notes = request['notes'] as String? ?? '';

    final isHighlighted = widget.initialRequestId == requestId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isHighlighted ? const Color(0xFFE0F7FA) : null,
      elevation: isHighlighted ? 4 : 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(status).withOpacity(0.2),
          child: Icon(
            _getStatusIcon(status),
            color: _getStatusColor(status),
          ),
        ),
        title: Text(
          tenantName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '📞 $tenantPhone',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '🏠 Property: ${propertyName.isNotEmpty ? propertyName : propertyId}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            if (moveInDate != null) ...[
              const SizedBox(height: 4),
              Text(
                '📅 Move-in: ${DateFormat('MMM d, yyyy').format(moveInDate.toDate())}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                '⏰ ${_formatTimestamp(createdAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '💬 $notes',
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        trailing: Chip(
          label: Text(
            status.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          backgroundColor: _getStatusColor(status).withOpacity(0.2),
          labelStyle: TextStyle(color: _getStatusColor(status)),
        ),
        onTap: () {
          _showRequestDetails(requestId, request);
        },
      ),
    );
  }

  void _showRequestDetails(String requestId, Map<String, dynamic> request) {
    final propertyName = (request['propertyName'] as String?) ?? '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: ListView(
              controller: scrollController,
              children: [
                const Text(
                  'Request Details',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _buildDetailRow('Tenant Name', request['tenantName'] ?? 'Unknown'),
                _buildDetailRow('Phone', request['tenantPhone'] ?? ''),
                if (propertyName.isNotEmpty)
                  _buildDetailRow('Property', propertyName),
                _buildDetailRow('Property ID', request['propertyId'] ?? ''),
                if (request['roomType'] != null)
                  _buildDetailRow('Room Type', request['roomType']),
                if (request['sharingType'] != null)
                  _buildDetailRow('Sharing', request['sharingType']),
                if (request['moveInDate'] != null)
                  _buildDetailRow(
                    'Move-in Date',
                    DateFormat('MMMM d, yyyy').format(
                      (request['moveInDate'] as Timestamp).toDate(),
                    ),
                  ),
                if (request['notes'] != null && (request['notes'] as String).isNotEmpty)
                  _buildDetailRow('Notes', request['notes']),
                _buildDetailRow('Status', request['status'] ?? 'pending'),
                const SizedBox(height: 32),
                if (request['status'] == 'pending') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showApprovalDialog(requestId, request);
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showRejectionDialog(requestId, request);
                          },
                          icon: const Icon(Icons.cancel),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Show approval dialog with room/bed selection
  void _showApprovalDialog(String requestId, Map<String, dynamic> request) {
    final propertyId = request['propertyId'] as String? ?? '';
    
    showDialog(
      context: context,
      builder: (context) => _ApprovalDialog(
        businessId: _businessId!,
        propertyId: propertyId,
        requestId: requestId,
        request: request,
        onApproved: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Tenant approved and room assigned!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  /// Show rejection dialog with reason
  void _showRejectionDialog(String requestId, Map<String, dynamic> request) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject ${request['tenantName']}\'s enrollment request?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g., No rooms available',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateRequestStatus(
                requestId, 
                'rejected',
                rejectionReason: reasonController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateRequestStatus(
    String requestId, 
    String newStatus, {
    String? rejectionReason,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (rejectionReason != null && rejectionReason.isNotEmpty) {
        updateData['rejectionReason'] = rejectionReason;
      }
      
      await _firestore.collection('enrollmentRequests').doc(requestId).update(updateData);

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request ${newStatus == 'approved' ? 'approved' : 'rejected'}!'),
          backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      debugPrint('Error updating request: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.hourglass_empty;
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}

/// Dialog for approving enrollment with room/bed selection
class _ApprovalDialog extends StatefulWidget {
  final String businessId;
  final String propertyId;
  final String requestId;
  final Map<String, dynamic> request;
  final VoidCallback onApproved;

  const _ApprovalDialog({
    required this.businessId,
    required this.propertyId,
    required this.requestId,
    required this.request,
    required this.onApproved,
  });

  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _rentController = TextEditingController();
  
  List<Map<String, dynamic>> _rooms = [];
  Map<String, List<Map<String, dynamic>>> _bedsByRoom = {};
  Map<String, dynamic>? _propertyPricing;
  
  String? _selectedRoomId;
  String? _selectedRoomNumber;
  String? _selectedBedId;
  String? _selectedBedNumber;
  
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  // Tenant's requested occupancy from enrollment request
  String get _requestedSharing => widget.request['sharingType']?.toString() ?? '';
  String get _requestedRoomType => widget.request['roomType']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _loadRoomsAndBeds();
    _loadPropertyDefaults();
    _loadBusinessUpiId();
    _setRentFromRequestedSharing();
  }

  /// Load UPI ID from business document
  Future<void> _loadBusinessUpiId() async {
    try {
      final businessDoc = await _firestore
          .collection('businesses')
          .doc(widget.businessId)
          .get();
      
      if (businessDoc.exists && mounted) {
        // UPI ID is loaded but used only when approving
        final upiId = businessDoc.data()?['upiId'] as String?;
        debugPrint('Business UPI ID loaded: $upiId');
      }
    } catch (e) {
      debugPrint('Error loading business UPI ID: $e');
    }
  }

  /// Set rent based on tenant's requested sharing type
  void _setRentFromRequestedSharing() {
    // Will be called after pricing is loaded
  }

  Future<void> _loadPropertyDefaults() async {
    try {
      final propertyDoc = await _firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('properties')
          .doc(widget.propertyId)
          .get();
      
      if (propertyDoc.exists && mounted) {
        final data = propertyDoc.data();
        final pricing = data?['pricing'] as Map<String, dynamic>?;
        
        setState(() {
          _propertyPricing = pricing;
        });
        
        // Set rent based on tenant's REQUESTED sharing type
        if (pricing != null && _rentController.text.isEmpty) {
          final requestedSharing = _requestedSharing.toLowerCase();
          int? rent;
          
          if (requestedSharing.contains('single') || requestedSharing == '1') {
            rent = pricing['single'] as int?;
          } else if (requestedSharing.contains('double') || requestedSharing.contains('twin') || requestedSharing == '2') {
            rent = pricing['double'] as int?;
          } else if (requestedSharing.contains('triple') || requestedSharing == '3') {
            rent = pricing['triple'] as int?;
          } else if (requestedSharing.contains('4') || requestedSharing.contains('four')) {
            // Check dynamic pricing for 4-sharing
            final sharingList = pricing['sharing'] as List<dynamic>?;
            if (sharingList != null) {
              final entry = sharingList.firstWhere(
                (e) => (e as Map)['sharing'] == 4,
                orElse: () => null,
              );
              if (entry != null) {
                rent = (entry as Map)['nonAc'] as int? ?? (entry)['ac'] as int?;
              }
            }
          }
          
          // Fallback to single if no match
          rent ??= pricing['single'] as int?;
          
          if (rent != null) {
            _rentController.text = rent.toString();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading property defaults: $e');
    }
  }

  Future<void> _loadRoomsAndBeds() async {
    try {
      // Load rooms
      final roomsSnap = await _firestore
          .collection('businesses/${widget.businessId}/properties/${widget.propertyId}/rooms')
          .get();

      final rooms = <Map<String, dynamic>>[];
      final bedsByRoom = <String, List<Map<String, dynamic>>>{};

      for (final roomDoc in roomsSnap.docs) {
        final roomData = roomDoc.data();
        roomData['id'] = roomDoc.id;
        rooms.add(roomData);

        // Load beds for this room
        final bedsSnap = await _firestore
            .collection('businesses/${widget.businessId}/properties/${widget.propertyId}/rooms/${roomDoc.id}/beds')
            .get();

        final beds = <Map<String, dynamic>>[];
        for (final bedDoc in bedsSnap.docs) {
          final bedData = bedDoc.data();
          bedData['id'] = bedDoc.id;
          // Only show available (not occupied) beds
          if (bedData['occupied'] != true) {
            beds.add(bedData);
          }
        }
        bedsByRoom[roomDoc.id] = beds;
      }

      setState(() {
        _rooms = rooms;
        _bedsByRoom = bedsByRoom;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load rooms: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _approve() async {
    if (_selectedRoomId == null || _selectedBedId == null) {
      setState(() => _error = 'Please select a room and bed');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final monthlyRent = double.tryParse(_rentController.text.trim()) ?? 0;
      
      await _firestore.collection('enrollmentRequests').doc(widget.requestId).update({
        'status': 'approved',
        'roomId': _selectedRoomId,
        'roomNumber': _selectedRoomNumber ?? _selectedRoomId,
        'bedId': _selectedBedId,
        'bedNumber': _selectedBedNumber ?? _selectedBedId,
        'monthlyRent': monthlyRent,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onApproved();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to approve: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Approve ${widget.request['tenantName']}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show tenant's requested preferences
                    if (_requestedSharing.isNotEmpty || _requestedRoomType.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '📋 Tenant\'s Request:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            if (_requestedSharing.isNotEmpty)
                              Text('• Occupancy: $_requestedSharing sharing', style: const TextStyle(fontSize: 13)),
                            if (_requestedRoomType.isNotEmpty)
                              Text('• Room Type: $_requestedRoomType', style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    
                    const Text(
                      'Assign Room & Bed',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    
                    // Room dropdown
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Room *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.meeting_room),
                      ),
                      value: _selectedRoomId,
                      items: _rooms.map((room) {
                        final availableBeds = _bedsByRoom[room['id']]?.length ?? 0;
                        return DropdownMenuItem(
                          value: room['id'] as String,
                          child: Text(
                            '${room['roomNumber'] ?? room['name'] ?? room['id']} ($availableBeds beds available)',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        final room = _rooms.firstWhere((r) => r['id'] == value);
                        setState(() {
                          _selectedRoomId = value;
                          _selectedRoomNumber = room['roomNumber'] ?? room['name'] ?? value;
                          _selectedBedId = null;
                          _selectedBedNumber = null;
                          // Note: Rent is already set based on tenant's requested sharing type
                          // Don't override it when room is selected
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Bed dropdown
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Bed *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.bed),
                      ),
                      value: _selectedBedId,
                      items: (_selectedRoomId != null
                              ? _bedsByRoom[_selectedRoomId] ?? []
                              : <Map<String, dynamic>>[])
                          .map((bed) {
                        return DropdownMenuItem(
                          value: bed['id'] as String,
                          child: Text(bed['bedNumber'] ?? bed['name'] ?? 'Bed ${bed['id']}'),
                        );
                      }).toList(),
                      onChanged: _selectedRoomId == null
                          ? null
                          : (value) {
                              final beds = _bedsByRoom[_selectedRoomId] ?? [];
                              final bed = beds.firstWhere((b) => b['id'] == value, orElse: () => {});
                              setState(() {
                                _selectedBedId = value;
                                _selectedBedNumber = bed['bedNumber'] ?? bed['name'] ?? value;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    
                    // Monthly rent
                    TextField(
                      controller: _rentController,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Rent (₹)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.currency_rupee),
                        hintText: 'e.g., 8000',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    
                    if (_rooms.isEmpty && !_isLoading) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No rooms found. Please add rooms to the property first.',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting || _selectedRoomId == null || _selectedBedId == null
              ? null
              : _approve,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Approve & Assign', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _rentController.dispose();
    super.dispose();
  }
}
