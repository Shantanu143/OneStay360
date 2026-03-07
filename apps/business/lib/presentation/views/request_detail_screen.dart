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
    final requestDoc = await _firestore
        .collection('enrollmentRequests')
        .doc(request.id)
        .get();
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
        request: request,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update request: $e')));
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
        stream: _firestore
            .collection('enrollmentRequests')
            .doc(widget.request.id)
            .snapshots(),
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
                  if (r.email != null && r.email!.isNotEmpty)
                    _row('Email Address', r.email!),
                ]),

                _infoCard('Accommodation Preferences', [
                  if (r.sharingType != null)
                    _row('Room Type', '${r.sharingType}-Sharing'),
                  if (r.hasAC != null)
                    _row(
                      'AC Preference',
                      r.hasAC! ? 'Air Conditioned' : 'Non-AC',
                    ),
                  if (r.preferredMoveIn != null)
                    _row(
                      'Preferred Move-in',
                      _formatDateOnly(r.preferredMoveIn!),
                    ),
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
                  if (r.updatedAt != null)
                    _row('Last Updated', _formatDate(r.updatedAt!)),
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
                          onPressed: _isUpdating
                              ? null
                              : () => _showApprovalDialog(r),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 20,
                          ),
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
                          onPressed: _isUpdating
                              ? null
                              : () => _updateStatus('rejected'),
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
  final TenantRequest request;
  final VoidCallback onApproved;

  const _ApprovalDialog({
    required this.businessId,
    required this.propertyId,
    required this.requestId,
    required this.tenantName,
    required this.request,
    required this.onApproved,
  });

  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _rentController = TextEditingController();
  final TextEditingController _depositController = TextEditingController();
  final TextEditingController _proratedRentController = TextEditingController();
  final TextEditingController _maintenanceController = TextEditingController();
  final TextEditingController _foodDeductionController =
      TextEditingController();

  List<Map<String, dynamic>> _rooms = [];
  Map<String, List<Map<String, dynamic>>> _bedsByRoom = {};

  String? _selectedRoomId;
  String? _selectedRoomNumber;
  String? _selectedBedId;
  String? _selectedBedNumber;

  // Billing options
  bool _paySecurityDepositNow = true;
  bool _foodAddon = true;
  bool _maintenanceDeductedFromDeposit = false;
  DateTime? _moveInDate;

  // Payment methods
  List<Map<String, dynamic>> _paymentMethods = [];
  String? _selectedPaymentMethodId;
  final TextEditingController _upiIdController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoomsAndBeds();
    _loadPaymentMethods();
    _loadPropertyDefaults();
    // Initialize move-in date from request if available
    _moveInDate = widget.request.preferredMoveIn ?? DateTime.now();
  }

  @override
  void dispose() {
    _rentController.dispose();
    _depositController.dispose();
    _proratedRentController.dispose();
    _maintenanceController.dispose();
    _foodDeductionController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  /// Calculate prorated rent based on move-in date
  /// Rule: 1-15 = full month, 16-31 = half month
  double _calculateProratedRent() {
    final monthlyRent = double.tryParse(_rentController.text.trim()) ?? 0.0;
    double foodDeduction = 0.0;
    if (!_foodAddon) {
      foodDeduction =
          double.tryParse(_foodDeductionController.text.trim()) ?? 0.0;
    }
    final adjustedRent = (monthlyRent - foodDeduction).clamp(
      0.0,
      double.infinity,
    );

    if (_moveInDate == null || adjustedRent <= 0) return adjustedRent;

    final moveInDay = _moveInDate!.day;
    if (moveInDay >= 1 && moveInDay <= 15) {
      return adjustedRent; // Full month
    } else {
      return adjustedRent / 2; // Half month
    }
  }

  String _getProratedExplanation() {
    if (_moveInDate == null) return '';
    final moveInDay = _moveInDate!.day;
    final dateStr =
        '${_moveInDate!.day}/${_moveInDate!.month}/${_moveInDate!.year}';
    if (moveInDay >= 1 && moveInDay <= 15) {
      return 'Full month rent (move-in: $dateStr - between 1st to 15th)';
    } else {
      return 'Half month rent (move-in: $dateStr - between 16th to end of month)';
    }
  }

  double _calculateTotalFirstMonth() {
    final proratedRent =
        double.tryParse(_proratedRentController.text.trim()) ??
        _calculateProratedRent();
    final deposit = double.tryParse(_depositController.text.trim()) ?? 0.0;

    double total = proratedRent;
    if (_paySecurityDepositNow) {
      total += deposit;
    }
    return total;
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .doc(widget.businessId)
          .collection('paymentMethods')
          .where('isActive', isEqualTo: true)
          .get();

      final methods = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        methods.add(data);
      }

      // Sort: preferred first
      methods.sort((a, b) {
        final aPreferred = a['isPreferred'] == true ? 0 : 1;
        final bPreferred = b['isPreferred'] == true ? 0 : 1;
        return aPreferred.compareTo(bPreferred);
      });

      if (mounted) {
        setState(() {
          _paymentMethods = methods;
          // Auto-select preferred method or first one
          if (methods.isNotEmpty) {
            final preferred = methods.firstWhere(
              (m) => m['isPreferred'] == true,
              orElse: () => methods.first,
            );
            _selectedPaymentMethodId = preferred['id'] as String?;
            // Pre-fill UPI controller if it's UPI type
            if (preferred['type'] == 'upi' && preferred['upiId'] != null) {
              _upiIdController.text = preferred['upiId'] as String;
            }
          }
        });
      }
      debugPrint('✅ Loaded ${methods.length} payment methods');
    } catch (e) {
      debugPrint('Error loading payment methods: $e');
    }
  }

  /// Get the sharing type label from the string value
  String get _requestedSharingLabel {
    final sharing = widget.request.sharingType?.toLowerCase();
    if (sharing == null || sharing.isEmpty) return 'Not specified';

    // Handle string values like "single", "double", "triple"
    switch (sharing) {
      case 'single':
      case '1':
        return 'Single Sharing';
      case 'double':
      case '2':
        return 'Double Sharing';
      case 'triple':
      case '3':
        return 'Triple Sharing';
      case 'quad':
      case '4':
        return 'Quad Sharing';
      default:
        return '$sharing Sharing';
    }
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

        if (pricing != null) {
          // Set security deposit from property
          final securityDeposit = pricing['securityDeposit'];
          if (securityDeposit != null && _depositController.text.isEmpty) {
            _depositController.text = securityDeposit.toString();
          }

          // Set monthly rent based on tenant's REQUESTED sharing type
          if (_rentController.text.isEmpty) {
            final requestedSharing = widget.request.sharingType?.toLowerCase();
            double? rentAmount;

            // Handle both string values ("single", "double") and numeric strings ("1", "2")
            switch (requestedSharing) {
              case 'single':
              case '1':
                rentAmount = (pricing['single'] as num?)?.toDouble();
                break;
              case 'double':
              case '2':
                rentAmount = (pricing['double'] as num?)?.toDouble();
                break;
              case 'triple':
              case '3':
                rentAmount = (pricing['triple'] as num?)?.toDouble();
                break;
              case 'quad':
              case '4':
                rentAmount = (pricing['quad'] as num?)?.toDouble();
                break;
              default:
                // Default to single if not specified
                rentAmount = (pricing['single'] as num?)?.toDouble();
            }

            if (rentAmount != null) {
              _rentController.text = rentAmount.toStringAsFixed(0);
              // Auto-calculate prorated rent
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _proratedRentController.text.isEmpty) {
                  _proratedRentController.text = _calculateProratedRent()
                      .toStringAsFixed(0);
                }
              });
            }
          }

          // Set maintenance from property
          final maintenance = pricing['maintenance'];
          if (maintenance != null && _maintenanceController.text.isEmpty) {
            _maintenanceController.text = maintenance.toString();
          }

          // Check if maintenance is deducted from deposit
          final maintenanceFromDeposit =
              pricing['maintenanceDeductedFromDeposit'];
          if (maintenanceFromDeposit == true) {
            _maintenanceDeductedFromDeposit = true;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading property defaults: $e');
    }
  }

  Future<void> _loadRoomsAndBeds() async {
    try {
      final roomsSnap = await _firestore
          .collection(
            'businesses/${widget.businessId}/properties/${widget.propertyId}/rooms',
          )
          .get();

      final rooms = <Map<String, dynamic>>[];
      final bedsByRoom = <String, List<Map<String, dynamic>>>{};

      for (final roomDoc in roomsSnap.docs) {
        final roomData = roomDoc.data();
        roomData['id'] = roomDoc.id;
        rooms.add(roomData);

        final bedsSnap = await _firestore
            .collection(
              'businesses/${widget.businessId}/properties/${widget.propertyId}/rooms/${roomDoc.id}/beds',
            )
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
    final proratedRent =
        double.tryParse(_proratedRentController.text.trim()) ??
        _calculateProratedRent();
    final maintenance =
        double.tryParse(_maintenanceController.text.trim()) ?? 0;
    final foodDeduction = _foodAddon
        ? 0.0
        : (double.tryParse(_foodDeductionController.text.trim()) ?? 0);
    final totalFirstMonth = _calculateTotalFirstMonth();

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // Save UPI ID to business if provided
      final upiId = _upiIdController.text.trim();
      if (upiId.isNotEmpty) {
        await _firestore.collection('businesses').doc(widget.businessId).update(
          {'upiId': upiId},
        );
      }

      await _firestore
          .collection('enrollmentRequests')
          .doc(widget.requestId)
          .update({
            'status': 'approved',
            'roomId': _selectedRoomId,
            'roomNumber': _selectedRoomNumber ?? _selectedRoomId,
            'bedId': _selectedBedId,
            'bedNumber': _selectedBedNumber ?? _selectedBedId,
            'monthlyRent': monthlyRent,
            'proratedRent': proratedRent,
            'depositAmount': deposit,
            'maintenanceAmount': maintenance,
            'foodAddon': _foodAddon,
            'foodDeduction': foodDeduction,
            'paySecurityDepositNow': _paySecurityDepositNow,
            'totalFirstMonth': totalFirstMonth,
            'moveInDate': _moveInDate != null
                ? Timestamp.fromDate(_moveInDate!)
                : null,
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
    final proratedRent =
        double.tryParse(_proratedRentController.text.trim()) ??
        _calculateProratedRent();
    final maintenance =
        double.tryParse(_maintenanceController.text.trim()) ?? 0;
    final foodDeduction = _foodAddon
        ? 0.0
        : (double.tryParse(_foodDeductionController.text.trim()) ?? 0);
    final totalFirstMonth = _calculateTotalFirstMonth();

    // Get payment method info
    final upiId = _upiIdController.text.trim();
    Map<String, dynamic>? selectedMethod;
    if (_selectedPaymentMethodId != null) {
      selectedMethod = _paymentMethods.firstWhere(
        (m) => m['id'] == _selectedPaymentMethodId,
        orElse: () => <String, dynamic>{},
      );
    }

    if (totalFirstMonth <= 0) {
      setState(
        () => _error = 'Total first month charges must be greater than 0',
      );
      return;
    }

    // Validate payment method
    if (_paymentMethods.isEmpty && upiId.isEmpty) {
      setState(
        () => _error = 'Enter UPI ID or add a payment method in Settings',
      );
      return;
    }

    if (_paymentMethods.isNotEmpty && _selectedPaymentMethodId == null) {
      setState(() => _error = 'Please select a payment method');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // Build payment info based on selected method
      String paymentMode = 'upi_manual';
      Map<String, dynamic> paymentInfo = {};

      if (selectedMethod != null && selectedMethod.isNotEmpty) {
        final methodType = selectedMethod['type'] as String? ?? 'upi';
        if (methodType == 'upi') {
          paymentMode = 'upi_manual';
          paymentInfo = {
            'ownerUpiId': selectedMethod['upiId'] ?? upiId,
            'paymentMethodId': _selectedPaymentMethodId,
          };
        } else if (methodType == 'bank') {
          paymentMode = 'bank_transfer';
          paymentInfo = {
            'bankName': selectedMethod['bankName'],
            'accountNumber': selectedMethod['accountNumber'],
            'ifscCode': selectedMethod['ifscCode'],
            'accountHolderName': selectedMethod['accountHolderName'],
            'paymentMethodId': _selectedPaymentMethodId,
          };
        } else {
          paymentMode = 'cash';
          paymentInfo = {'paymentMethodId': _selectedPaymentMethodId};
        }
      } else if (upiId.isNotEmpty) {
        paymentInfo = {'ownerUpiId': upiId};
      }

      // Update request with bill_sent status - Cloud Function will notify tenant
      await _firestore
          .collection('enrollmentRequests')
          .doc(widget.requestId)
          .update({
            'status': 'bill_sent',
            'roomId': _selectedRoomId,
            'roomNumber': _selectedRoomNumber ?? _selectedRoomId,
            'bedId': _selectedBedId,
            'bedNumber': _selectedBedNumber ?? _selectedBedId,
            'monthlyRent': monthlyRent,
            'proratedRent': proratedRent,
            'depositAmount': deposit,
            'maintenanceAmount': maintenance,
            'foodAddon': _foodAddon,
            'foodDeduction': foodDeduction,
            'paySecurityDepositNow': _paySecurityDepositNow,
            'totalFirstMonth': totalFirstMonth,
            'totalBillAmount': totalFirstMonth,
            'moveInDate': _moveInDate != null
                ? Timestamp.fromDate(_moveInDate!)
                : null,
            'paymentMode': paymentMode,
            ...paymentInfo,
            'billSentAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill sent! Tenant will be notified.'),
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
    final availableBeds = _selectedRoomId != null
        ? (_bedsByRoom[_selectedRoomId] ?? [])
        : <Map<String, dynamic>>[];

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
                    // Tenant's Request Info Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Tenant's Request",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text('Occupancy: $_requestedSharingLabel'),
                            ],
                          ),
                          if (widget.request.hasAC != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.ac_unit,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'AC Room: ${widget.request.hasAC! ? 'Yes' : 'No'}',
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Assign Room & Bed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Room dropdown
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Room *',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _selectedRoomId,
                      items: _rooms.map((room) {
                        final roomNum = room['roomNumber'] ?? room['id'];
                        final availableCount =
                            (_bedsByRoom[room['id']] ?? []).length;
                        return DropdownMenuItem(
                          value: room['id'] as String,
                          child: Text(
                            'Room $roomNum ($availableCount beds available)',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        final room = _rooms.firstWhere((r) => r['id'] == value);
                        setState(() {
                          _selectedRoomId = value;
                          _selectedRoomNumber =
                              room['roomNumber']?.toString() ?? value;
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
                      ),
                      initialValue: _selectedBedId,
                      items: availableBeds.map((bed) {
                        final bedNum = bed['bedNumber'] ?? bed['id'];
                        return DropdownMenuItem(
                          value: bed['id'] as String,
                          child: Text('Bed $bedNum'),
                        );
                      }).toList(),
                      onChanged: _selectedRoomId == null
                          ? null
                          : (value) {
                              setState(() {
                                _selectedBedId = value;
                                _selectedBedNumber =
                                    availableBeds
                                        .firstWhere(
                                          (b) => b['id'] == value,
                                        )['bedNumber']
                                        ?.toString() ??
                                    value;
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

                    // ===== FIRST MONTH CHARGES =====
                    const Text(
                      'First Month Charges',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Move-in date picker
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _moveInDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 30),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (date != null) {
                          setState(() {
                            _moveInDate = date;
                            // Recalculate prorated rent
                            _proratedRentController.text =
                                _calculateProratedRent().toStringAsFixed(0);
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Move-in Date *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _moveInDate != null
                              ? '${_moveInDate!.day}/${_moveInDate!.month}/${_moveInDate!.year}'
                              : 'Select date',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Prorated Rent - Editable
                    TextField(
                      controller: _proratedRentController,
                      decoration: const InputDecoration(
                        labelText: 'Prorated Rent (₹) *',
                        border: OutlineInputBorder(),
                        prefixText: '₹ ',
                        helperText: 'First month rent amount',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),

                    // Prorated rent explanation
                    if (_moveInDate != null &&
                        _getProratedExplanation().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getProratedExplanation(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    const Divider(),

                    // Food Addon checkbox
                    CheckboxListTile(
                      title: const Text('Food Addon'),
                      subtitle: Text(
                        _foodAddon
                            ? 'Food included in rent'
                            : 'Food not included - deduction applied',
                      ),
                      value: _foodAddon,
                      onChanged: (value) {
                        setState(() {
                          _foodAddon = value ?? true;
                          if (!_foodAddon &&
                              _foodDeductionController.text.isEmpty) {
                            // Default 10% of monthly rent
                            final monthlyRent =
                                double.tryParse(_rentController.text.trim()) ??
                                0.0;
                            if (monthlyRent > 0) {
                              _foodDeductionController.text =
                                  (monthlyRent * 0.1).toStringAsFixed(0);
                            }
                          }
                          // Recalculate prorated rent
                          _proratedRentController.text =
                              _calculateProratedRent().toStringAsFixed(0);
                        });
                      },
                      secondary: Icon(
                        _foodAddon
                            ? Icons.restaurant
                            : Icons.restaurant_outlined,
                        color: _foodAddon ? Colors.green : Colors.grey,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),

                    // Food deduction field when unchecked
                    if (!_foodAddon) ...[
                      TextField(
                        controller: _foodDeductionController,
                        decoration: const InputDecoration(
                          labelText: 'Food Deduction Amount (₹)',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          setState(() {
                            _proratedRentController.text =
                                _calculateProratedRent().toStringAsFixed(0);
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.restaurant,
                              size: 16,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Monthly ₹${_rentController.text} - Food ₹${_foodDeductionController.text} = Adjusted ₹${((double.tryParse(_rentController.text) ?? 0) - (double.tryParse(_foodDeductionController.text) ?? 0)).toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Divider(),

                    // Security Deposit with pay now/later option
                    CheckboxListTile(
                      title: const Text('Security Deposit'),
                      subtitle: Text(
                        _paySecurityDepositNow
                            ? '₹${_depositController.text} (Pay now)'
                            : '₹${_depositController.text} (Pay later)',
                      ),
                      value: _paySecurityDepositNow,
                      onChanged: (value) {
                        setState(() {
                          _paySecurityDepositNow = value ?? true;
                        });
                      },
                      secondary: Icon(
                        _paySecurityDepositNow
                            ? Icons.payment
                            : Icons.payment_outlined,
                        color: _paySecurityDepositNow
                            ? Colors.green
                            : Colors.grey,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),

                    // Security deposit field
                    TextField(
                      controller: _depositController,
                      decoration: const InputDecoration(
                        labelText: 'Security Deposit (₹)',
                        border: OutlineInputBorder(),
                        prefixText: '₹ ',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),

                    // Maintenance info if applicable
                    if (_maintenanceController.text.isNotEmpty &&
                        (double.tryParse(_maintenanceController.text) ?? 0) >
                            0) ...[
                      const Divider(),
                      ListTile(
                        title: const Text('Maintenance'),
                        subtitle: Text(
                          _maintenanceDeductedFromDeposit
                              ? 'Deducted from deposit refund at vacating'
                              : 'Monthly charge',
                        ),
                        trailing: Text(
                          '₹${_maintenanceController.text}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],

                    // Total First Month
                    const Divider(height: 24, thickness: 2),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total First Month',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₹${_calculateTotalFirstMonth().toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ===== PAYMENT METHOD =====
                    const Text(
                      'Payment Method',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_paymentMethods.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  color: Colors.orange.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'No payment methods configured',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _upiIdController,
                              decoration: const InputDecoration(
                                labelText: 'Enter UPI ID',
                                border: OutlineInputBorder(),
                                hintText: 'yourname@upi',
                                prefixIcon: Icon(Icons.account_balance_wallet),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add payment methods in Settings for easier billing',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Payment Method',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...(_paymentMethods.map((method) {
                            final methodId = method['id'] as String;
                            final type = method['type'] as String? ?? 'cash';
                            final isSelected =
                                _selectedPaymentMethodId == methodId;

                            String label;
                            String subtitle;
                            IconData icon;

                            if (type == 'upi') {
                              final upiId = method['upiId'] as String? ?? '';
                              label = 'UPI';
                              subtitle = upiId;
                              icon = Icons.account_balance_wallet;
                            } else if (type == 'bank') {
                              final bankName =
                                  method['bankName'] as String? ?? '';
                              final accountNum =
                                  method['accountNumber'] as String? ?? '';
                              final lastFour = accountNum.length > 4
                                  ? accountNum.substring(accountNum.length - 4)
                                  : accountNum;
                              label = bankName.isNotEmpty
                                  ? bankName
                                  : 'Bank Account';
                              subtitle = '****$lastFour';
                              icon = Icons.account_balance;
                            } else {
                              label = 'Cash';
                              subtitle = 'Manual collection';
                              icon = Icons.money;
                            }

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPaymentMethodId = methodId;
                                  if (type == 'upi' &&
                                      method['upiId'] != null) {
                                    _upiIdController.text =
                                        method['upiId'] as String;
                                  }
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.green.shade50
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.green
                                        : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      icon,
                                      color: isSelected
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                label,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected
                                                      ? Colors.green.shade800
                                                      : Colors.black87,
                                                ),
                                              ),
                                              if (method['isPreferred'] ==
                                                  true) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'Preferred',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          Colors.blue.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          Text(
                                            subtitle,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          })),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '💡 Tenant will pay directly. No platform fees!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ===== ACTION BUTTONS EXPLANATION =====
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.help_outline,
                                color: Colors.grey.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Choose how to proceed:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Accept Now (Cash/Offline)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    Text(
                                      'Use when payment is collected in person or already received',
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
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.send,
                                  size: 14,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Send Bill (Notify Tenant)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                    Text(
                                      'Tenant will receive notification with payment details',
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
                        ],
                      ),
                    ),
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
        OutlinedButton.icon(
          onPressed: _isSubmitting ? null : _approveImmediate,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green.shade700,
            side: BorderSide(color: Colors.green.shade400),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Accept Now'),
        ),
        const SizedBox(width: 8),
        // Send Bill - for UPI payment with confirmation
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _sendBill,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send, color: Colors.white, size: 18),
          label: const Text('Send Bill', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
