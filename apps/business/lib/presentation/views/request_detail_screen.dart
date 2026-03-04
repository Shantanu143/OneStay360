// lib/presentation/views/business/request_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:models/tenant/tenant_request_model.dart';
import 'widgets/business_scaffold.dart';

class RequestDetailScreen extends StatefulWidget {
  final String propertyId;
  final TenantRequest request;

  const RequestDetailScreen({
    super.key,
    required this.propertyId,
    required this.request,
  });

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  bool _isUpdating = false;
  final _firestore = FirebaseFirestore.instance;

  /// Show approval dialog with room/bed selection
  Future<void> _showApprovalDialog(TenantRequest request) async {
    // Get businessId from the enrollment request
    final requestDoc = await _firestore.collection('enrollmentRequests').doc(request.id).get();
    final data = requestDoc.data();
    final businessId = data?['businessId'] as String?;
    
    if (businessId == null || !mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ApprovalDialog(
        businessId: businessId,
        propertyId: widget.propertyId,
        requestId: request.id,
        tenantName: request.tenantName,
        onApproved: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Tenant approved and room assigned!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateStatus(String status) async {
    HapticFeedback.lightImpact();
    setState(() => _isUpdating = true);
    try {
      // Update request status in Firestore directly
      await _firestore
          .collection('enrollmentRequests')
          .doc(widget.request.id)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request ${status.toUpperCase()}'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateOnly(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return BusinessScaffold(
      currentTab: BusinessTab.properties,
      showBackButton: true,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('enrollmentRequests').doc(widget.request.id).snapshots(),
        builder: (context, snapshot) {
          // Use stream data if available, otherwise fall back to initial data
          TenantRequest r;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            r = TenantRequest.fromMap(data, snapshot.data!.id);
          } else {
            r = widget.request;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Request Status Badge
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _getStatusColor(r.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(r.status).withOpacity(0.3),
                      width: 1,
                    ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(r.status),
                    color: _getStatusColor(r.status),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status: ${r.status.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(r.status),
                          ),
                        ),
                        if (r.updatedAt != null)
                          Text(
                            'Updated: ${_formatDate(r.updatedAt!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _infoCard('Personal Information', [
              _row('Full Name', r.tenantName),
              _row('Phone Number', r.phone),
              if (r.email != null && r.email!.isNotEmpty) _row('Email Address', r.email!),
            ]),

            _infoCard('Accommodation Preferences', [
              if (r.sharingType != null) _row('Room Type', '${r.sharingType}-Sharing'),
              if (r.hasAC != null) _row('AC Preference', r.hasAC! ? 'Air Conditioned' : 'Non-AC'),
              if (r.preferredMoveIn != null) _row('Preferred Move-in', _formatDateOnly(r.preferredMoveIn!)),
            ]),

            if (r.source != null)
              _infoCard('Request Source', [
                _row('Source', _formatSource(r.source!)),
              ]),

            if (r.message != null && r.message!.isNotEmpty)
              _infoCard('Additional Message', [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    r.message!,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),
                ),
              ]),

            _infoCard('Request Timeline', [
              _row('Requested On', _formatDate(r.createdAt)),
              if (r.updatedAt != null) _row('Last Updated', _formatDate(r.updatedAt!)),
            ]),

            const SizedBox(height: 24),

            // Action Buttons - Only show for pending requests
            if (r.status == 'pending') ...[
              Text(
                'Manage Request',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUpdating ? null : () => _showApprovalDialog(r),
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text(
                        'Approve Request',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUpdating ? null : () => _updateStatus('rejected'),
                      icon: const Icon(Icons.cancel_outlined, size: 20),
                      label: const Text(
                        'Reject Request',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isUpdating)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
            ] else if (r.status == 'approved') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This request has been approved',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (r.status == 'rejected') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This request has been rejected',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
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
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.pending;
    }
  }

  String _formatSource(String source) {
    switch (source.toLowerCase()) {
      case 'qr code':
        return 'QR Code Scan';
      case 'website':
        return 'Website Form';
      case 'referral':
        return 'Referral';
      default:
        return source;
    }
  }

  Widget _infoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for approving enrollment with room/bed selection
class _ApprovalDialog extends StatefulWidget {
  final String businessId;
  final String propertyId;
  final String requestId;
  final String tenantName;
  final VoidCallback onApproved;

  const _ApprovalDialog({
    required this.businessId,
    required this.propertyId,
    required this.requestId,
    required this.tenantName,
    required this.onApproved,
  });

  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _rentController = TextEditingController();
  final TextEditingController _depositController = TextEditingController();
  final TextEditingController _advanceController = TextEditingController();
  
  List<Map<String, dynamic>> _rooms = [];
  Map<String, List<Map<String, dynamic>>> _bedsByRoom = {};
  
  String? _selectedRoomId;
  String? _selectedRoomNumber;
  String? _selectedBedId;
  String? _selectedBedNumber;
  
  final TextEditingController _upiIdController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoomsAndBeds();
    _loadBusinessUpiId();
  }

  @override
  void dispose() {
    _rentController.dispose();
    _depositController.dispose();
    _advanceController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessUpiId() async {
    try {
      final businessDoc = await _firestore.collection('businesses').doc(widget.businessId).get();
      if (businessDoc.exists) {
        final upiId = businessDoc.data()?['upiId'] as String?;
        if (upiId != null && upiId.isNotEmpty) {
          _upiIdController.text = upiId;
        }
      }
    } catch (e) {
      // Ignore - UPI ID is optional for existing businesses
    }
  }

  Future<void> _loadRoomsAndBeds() async {
    try {
      final roomsSnap = await _firestore
          .collection('businesses/${widget.businessId}/properties/${widget.propertyId}/rooms')
          .get();

      final rooms = <Map<String, dynamic>>[];
      final bedsByRoom = <String, List<Map<String, dynamic>>>{};

      for (final roomDoc in roomsSnap.docs) {
        final roomData = roomDoc.data();
        roomData['id'] = roomDoc.id;
        rooms.add(roomData);

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

  Future<void> _approveImmediate() async {
    if (_selectedRoomId == null || _selectedBedId == null) {
      setState(() => _error = 'Please select a room and bed');
      return;
    }

    final monthlyRent = double.tryParse(_rentController.text.trim()) ?? 0;
    final deposit = double.tryParse(_depositController.text.trim()) ?? 0;
    final advance = double.tryParse(_advanceController.text.trim()) ?? 0;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // Save UPI ID to business if provided
      final upiId = _upiIdController.text.trim();
      if (upiId.isNotEmpty) {
        await _firestore.collection('businesses').doc(widget.businessId).update({
          'upiId': upiId,
        });
      }
      
      await _firestore.collection('enrollmentRequests').doc(widget.requestId).update({
        'status': 'approved',
        'roomId': _selectedRoomId,
        'roomNumber': _selectedRoomNumber ?? _selectedRoomId,
        'bedId': _selectedBedId,
        'bedNumber': _selectedBedNumber ?? _selectedBedId,
        'monthlyRent': monthlyRent,
        'depositAmount': deposit,
        'advanceAmount': advance,
        'paymentMode': 'immediate',
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

  Future<void> _sendBill() async {
    if (_selectedRoomId == null || _selectedBedId == null) {
      setState(() => _error = 'Please select a room and bed');
      return;
    }

    final monthlyRent = double.tryParse(_rentController.text.trim()) ?? 0;
    final deposit = double.tryParse(_depositController.text.trim()) ?? 0;
    final advance = double.tryParse(_advanceController.text.trim()) ?? 0;
    final upiId = _upiIdController.text.trim();

    if (deposit == 0 && advance == 0) {
      setState(() => _error = 'Enter deposit or advance amount for bill');
      return;
    }

    if (upiId.isEmpty) {
      setState(() => _error = 'Enter your UPI ID to receive payment');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // Save UPI ID to business
      await _firestore.collection('businesses').doc(widget.businessId).update({
        'upiId': upiId,
      });
      
      // Update request with bill_sent status - Cloud Function will notify tenant
      await _firestore.collection('enrollmentRequests').doc(widget.requestId).update({
        'status': 'bill_sent',
        'roomId': _selectedRoomId,
        'roomNumber': _selectedRoomNumber ?? _selectedRoomId,
        'bedId': _selectedBedId,
        'bedNumber': _selectedBedNumber ?? _selectedBedId,
        'monthlyRent': monthlyRent,
        'depositAmount': deposit,
        'advanceAmount': advance,
        'totalBillAmount': deposit + advance,
        'paymentMode': 'upi_manual',
        'ownerUpiId': upiId,
        'billSentAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill sent! Tenant will be notified to pay via UPI.'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onApproved();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to send bill: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableBeds = _selectedRoomId != null ? (_bedsByRoom[_selectedRoomId] ?? []) : <Map<String, dynamic>>[];
    
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Approve ${widget.tenantName}',
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
                      ),
                      value: _selectedRoomId,
                      items: _rooms.map((room) {
                        final roomNum = room['roomNumber'] ?? room['id'];
                        final availableCount = (_bedsByRoom[room['id']] ?? []).length;
                        return DropdownMenuItem(
                          value: room['id'] as String,
                          child: Text('Room $roomNum ($availableCount beds available)'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRoomId = value;
                          _selectedRoomNumber = _rooms.firstWhere((r) => r['id'] == value)['roomNumber']?.toString() ?? value;
                          _selectedBedId = null;
                          _selectedBedNumber = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Bed dropdown
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Bed *',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedBedId,
                      items: availableBeds.map((bed) {
                        final bedNum = bed['bedNumber'] ?? bed['id'];
                        return DropdownMenuItem(
                          value: bed['id'] as String,
                          child: Text('Bed $bedNum'),
                        );
                      }).toList(),
                      onChanged: _selectedRoomId == null ? null : (value) {
                        setState(() {
                          _selectedBedId = value;
                          _selectedBedNumber = availableBeds.firstWhere((b) => b['id'] == value)['bedNumber']?.toString() ?? value;
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
                        prefixText: '₹ ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    
                    // Payment amounts
                    const Text(
                      'Payment Details',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _depositController,
                            decoration: const InputDecoration(
                              labelText: 'Security Deposit (₹)',
                              border: OutlineInputBorder(),
                              prefixText: '₹ ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _advanceController,
                            decoration: const InputDecoration(
                              labelText: 'Advance Rent (₹)',
                              border: OutlineInputBorder(),
                              prefixText: '₹ ',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // UPI ID field
                    TextField(
                      controller: _upiIdController,
                      decoration: const InputDecoration(
                        labelText: 'Your UPI ID (for payment)',
                        border: OutlineInputBorder(),
                        hintText: 'yourname@upi',
                        prefixIcon: Icon(Icons.account_balance_wallet),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '💡 Tenant will pay directly to your UPI. No platform fees!',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                    ),
                    
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
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
        // Accept Immediately - for cash or payment collected offline
        OutlinedButton(
          onPressed: _isSubmitting ? null : _approveImmediate,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green,
            side: const BorderSide(color: Colors.green),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Accept Now'),
        ),
        const SizedBox(width: 8),
        // Send Bill - for UPI payment with confirmation
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _sendBill,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          icon: const Icon(Icons.send, color: Colors.white, size: 18),
          label: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Send Bill', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}