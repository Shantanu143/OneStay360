import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:models/business/tenant_invitation_model.dart';
import 'package:firebase_services/services/tenant_invitation_service.dart';
import 'widgets/tenant_scaffold.dart';

class TenantInvitationApprovalScreen extends StatefulWidget {
  final String invitationId;

  const TenantInvitationApprovalScreen({
    super.key,
    required this.invitationId,
  });

  @override
  State<TenantInvitationApprovalScreen> createState() =>
      _TenantInvitationApprovalScreenState();
}

class _TenantInvitationApprovalScreenState
    extends State<TenantInvitationApprovalScreen> {
  final _invitationService = TenantInvitationService();
  TenantInvitation? _invitation;
  bool _isLoading = true;
  bool _isProcessing = false;
  User? _currentUser;
  late final Stream<User?> _authStateChanges;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _loadInvitation();
    _authStateChanges = FirebaseAuth.instance.authStateChanges();
    _authSub = _authStateChanges.listen((u) {
      if (mounted) {
        setState(() {
          _currentUser = u;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadInvitation() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('tenant_invitations')
          .doc(widget.invitationId)
          .get();

      if (doc.exists) {
        setState(() {
          _invitation = TenantInvitation.fromMap(doc.data()!, doc.id);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invitation not found')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error loading invitation: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _approveInvitation() async {
    if (_invitation == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _invitationService.approveInvitation(widget.invitationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation approved! You are now part of this PG.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving invitation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _rejectInvitation() async {
    if (_invitation == null) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Invitation'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _invitationService.rejectInvitation(
        widget.invitationId,
        reason.isEmpty ? null : reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation rejected')),
        );
        Navigator.pop(context, false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting invitation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return TenantScaffold(
        currentTab: TenantTab.profile,
        showBackButton: true,
        titleText: 'Review Invitation',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_invitation == null) {
      return TenantScaffold(
        currentTab: TenantTab.profile,
        showBackButton: true,
        titleText: 'Review Invitation',
        body: const Center(child: Text('Invitation not found')),
      );
    }

    if (_invitation!.status != TenantInvitationStatus.pending) {
      return TenantScaffold(
        currentTab: TenantTab.profile,
        showBackButton: true,
        titleText: 'Invitation Details',
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _invitation!.status == TenantInvitationStatus.approved
                    ? Icons.check_circle
                    : Icons.cancel,
                size: 64,
                color: _invitation!.status == TenantInvitationStatus.approved
                    ? Colors.green
                    : Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _invitation!.statusText,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final firstMonthCharge = (_invitation!.proratedRent != null && _invitation!.proratedRent! > 0)
      ? _invitation!.proratedRent! // use persisted prorated if provided
      : _invitation!.monthlyRent;
    // If maintenance is deducted from deposit, it should not be added to tenant's billed total now.
    final maintenanceDeducted = _invitation!.maintenanceDeductedFromDeposit ?? false;
    double totalBilling = firstMonthCharge + (_invitation!.deposit ?? 0);
    if (!maintenanceDeducted && (_invitation!.maintenance ?? 0) > 0) {
      totalBilling += _invitation!.maintenance!;
    }

    return TenantScaffold(
      currentTab: TenantTab.profile,
      showBackButton: true,
      titleText: 'Review PG Invitation',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.apartment, size: 40, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _invitation!.propertyName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'PG Property',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
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
            ),
            const SizedBox(height: 20),
            const Text(
              'Room Assignment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    'Floor',
                    _invitation!.floor,
                    Icons.layers,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    'Room',
                    _invitation!.roomNumber,
                    Icons.door_front_door,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    'Bed',
                    _invitation!.bedNumber,
                    Icons.single_bed,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Move-in Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDetailCard(
                    'Move-in Date',
                    '${_invitation!.moveInDate.day}/${_invitation!.moveInDate.month}/${_invitation!.moveInDate.year}',
                    Icons.calendar_today,
                  ),
                ),
                if (_invitation!.moveOutDate != null)
                  const SizedBox(width: 12),
                if (_invitation!.moveOutDate != null)
                  Expanded(
                    child: _buildDetailCard(
                      'Move-out Date',
                      '${_invitation!.moveOutDate!.day}/${_invitation!.moveOutDate!.month}/${_invitation!.moveOutDate!.year}',
                      Icons.calendar_today,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_invitation!.tenantDetails?['foodPreference'] != null) ...[
              const Text(
                'Your Preferences',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.orange.shade50,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant, size: 24, color: Colors.orange),
                    const SizedBox(width: 12),
                    Text(
                      _invitation!.tenantDetails?['foodPreference'] ?? 'Not specified',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              'Billing Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBillingRow(
                      'Billing Date',
                      _invitation!.billingDay != null
                          ? '${_formatDayOrdinal(_invitation!.billingDay!)} of every month'
                          : '1st of every month',
                      Colors.blue,
                    ),
                    const Divider(height: 20),
                    _buildBillingRow(
                      'Monthly Rent',
                      '?${_invitation!.monthlyRent.toStringAsFixed(0)}',
                      Colors.green,
                    ),
                    const SizedBox(height: 8),
                    if (_invitation!.proratedRent != null)
                      _buildBillingRow(
                        'Prorated Rent (First month)',
                        '?${_invitation!.proratedRent!.toStringAsFixed(0)}',
                        Colors.teal,
                      ),
                    const SizedBox(height: 12),
                    if (_invitation!.deposit != null) ...[
                      _buildBillingRow(
                        'Security Deposit',
                        '?${_invitation!.deposit!.toStringAsFixed(0)}',
                        Colors.purple,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_invitation!.maintenance != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          border: Border.all(color: Colors.amber.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.home_repair_service,
                                    size: 20, color: Colors.amber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Maintenance Fee',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    maintenanceDeducted
                                        ? '?${_invitation!.maintenance!.toStringAsFixed(0)} (will be deducted from deposit)'
                                        : '?${_invitation!.maintenance!.toStringAsFixed(0)}/month',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (maintenanceDeducted)
                              Text(
                                '?? Will be deducted from Security Deposit',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildBillingRow(
                      'Payment Cycle',
                      _invitation!.paymentCycle,
                      Colors.indigo,
                    ),
                    const Divider(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Total One-time + Monthly',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 0,
                            child: Text(
                              '?${totalBilling.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_invitation!.lockInPeriodMonths != null ||
                _invitation!.noticePeriodDays != null) ...[
              const Text(
                'Lease Terms',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_invitation!.lockInPeriodMonths != null)
                    Expanded(
                      child: _buildTermCard(
                        'Lock-in Period',
                        '${_invitation!.lockInPeriodMonths} months',
                        Icons.lock,
                        Colors.red,
                      ),
                    ),
                  if (_invitation!.lockInPeriodMonths != null &&
                      _invitation!.noticePeriodDays != null)
                    const SizedBox(width: 12),
                  if (_invitation!.noticePeriodDays != null)
                    Expanded(
                      child: _buildTermCard(
                        'Notice Period',
                        '${_invitation!.noticePeriodDays} days',
                        Icons.schedule,
                        Colors.orange,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _isProcessing ? null : _rejectInvitation,
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: (_isProcessing || _currentUser == null) ? null : _approveInvitation,
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Approve & Join'),
                  ),
                ),
              ],
            ),
            if (_currentUser == null) ...[
              const SizedBox(height: 12),
              Text(
                'You must be signed in to approve this invitation.',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withAlpha((0.3 * 255).round())),
        borderRadius: BorderRadius.circular(8),
        color: color.withAlpha((0.05 * 255).round()),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBillingRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTermCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withAlpha((0.3 * 255).round())),
        borderRadius: BorderRadius.circular(8),
        color: color.withAlpha((0.05 * 255).round()),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  String _formatDayOrdinal(int day) {
    if (day <= 0) return day.toString();
    final int mod100 = day % 100;
    final int mod10 = day % 10;
    String suffix;
    if (mod10 == 1 && mod100 != 11) {
      suffix = 'st';
    } else if (mod10 == 2 && mod100 != 12) {
      suffix = 'nd';
    } else if (mod10 == 3 && mod100 != 13) {
      suffix = 'rd';
    } else {
      suffix = 'th';
    }
    return '$day$suffix';
  }
}


