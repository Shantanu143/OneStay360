// lib/presentation/views/business/request_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onestay360/data/models/tenant/tenant_request_model.dart';
import 'package:provider/provider.dart';
import 'package:onestay360/presentation/view_models/business/view_property_viewmodel.dart';
import 'package:onestay360/presentation/views/business/widgets/business_scaffold.dart';

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

  Future<void> _updateStatus(String status) async {
    HapticFeedback.lightImpact();
    setState(() => _isUpdating = true);
    try {
      // Use ViewModel to update the request status with dummy data
      final viewModel = Provider.of<ViewPropertyViewModel>(context, listen: false);

      // For demo purposes, we'll simulate the update
      // In a real app, you would call: viewModel.updateRequestStatus(widget.request.id, status);

      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request ${status.toUpperCase()} (Demo Mode)')),
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
    final r = widget.request;

    return BusinessScaffold(
      currentTab: BusinessTab.properties,
      //titleText: 'Request Details',
      showBackButton: true,
      body: SingleChildScrollView(
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
                      onPressed: _isUpdating ? null : () => _updateStatus('accepted'),
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text(
                        'Accept Request',
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
            ] else if (r.status == 'accepted') ...[
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
                        'This request has been accepted',
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
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
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
      case 'accepted':
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