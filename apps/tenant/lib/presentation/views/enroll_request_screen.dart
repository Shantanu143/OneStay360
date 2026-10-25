import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/tenant_scaffold.dart';

class EnrollRequestScreen extends StatefulWidget {
  final String? propertyId;
  final String? businessId;
  final String? pgName;
  final String? location;

  const EnrollRequestScreen({
    super.key,
    this.propertyId,
    this.businessId,
    this.pgName,
    this.location,
  });

  @override
  State<EnrollRequestScreen> createState() => _EnrollRequestScreenState();
}

class _EnrollRequestScreenState extends State<EnrollRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _sharingType = 'Single';
  DateTime? _moveIn;
  bool _isSubmitting = false;

  bool get _hasPropertyContext =>
      (widget.propertyId?.isNotEmpty ?? false) &&
      (widget.businessId?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _fullNameCtrl.text = user.displayName ?? '';
      _loadUserProfile(user.uid);
    }
  }

  Future<void> _loadUserProfile(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists || !mounted) return;
      final data = doc.data()!;
      setState(() {
        if (_fullNameCtrl.text.isEmpty) {
          _fullNameCtrl.text =
              data['fullName'] ?? data['name'] ?? '';
        }
        if (_phoneCtrl.text.isEmpty) {
          _phoneCtrl.text =
              data['phone'] ?? data['mobileNumber'] ?? '';
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMoveInDate() async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _moveIn ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _moveIn = picked);
  }

  Future<void> _submit() async {
    HapticFeedback.lightImpact();
    if (_formKey.currentState?.validate() != true) return;
    if (_moveIn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a preferred move-in date.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('submitEnrollmentRequest');

      await callable.call({
        'propertyId': widget.propertyId,
        'businessId': widget.businessId,
        'tenantName': _fullNameCtrl.text.trim(),
        'tenantPhone': _phoneCtrl.text.trim(),
        'moveInDate': _moveIn!.toIso8601String(),
        'propertyName': widget.pgName ?? '',
        'sharingType': _sharingType,
        'notes': _noteCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enrollment request sent! The owner will review it shortly.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to send request. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TenantScaffold(
      currentTab: TenantTab.home,
      showBackButton: true,
      body: _hasPropertyContext
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildForm(),
            )
          : _buildNoPGContext(),
    );
  }

  Widget _buildNoPGContext() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.apartment_outlined,
                size: 56,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Browse a PG First',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF164e63),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'To send an enrollment request, first find a PG you like in the Explore tab, then tap "Request to Join" on its detail page.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Go to Explore'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.primaryColor),
    );

    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (widget.pgName != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.primaryColor, theme.colorScheme.secondary],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.apartment, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.pgName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (widget.location != null)
                          Text(
                            widget.location!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          _card(children: [
            _sectionTitle('Your Details'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fullNameCtrl,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline,
                    color: theme.primaryColor),
                border: border,
                enabledBorder: border,
                focusedBorder: focusedBorder,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined,
                    color: theme.primaryColor),
                border: border,
                enabledBorder: border,
                focusedBorder: focusedBorder,
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 10)
                      ? 'Enter a valid phone number'
                      : null,
            ),
          ]),

          const SizedBox(height: 16),

          _card(children: [
            _sectionTitle('Preferences'),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Sharing Preference',
                prefixIcon: Icon(Icons.group_outlined,
                    color: theme.primaryColor),
                border: border,
                enabledBorder: border,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sharingType,
                  isExpanded: true,
                  items: const ['Single', 'Double', 'Triple']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _sharingType = v ?? _sharingType),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickMoveInDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Preferred Move-in Date',
                  prefixIcon: Icon(Icons.event_outlined,
                      color: theme.primaryColor),
                  border: border,
                  enabledBorder: border,
                ),
                child: Text(
                  _moveIn != null
                      ? '${_moveIn!.day}/${_moveIn!.month}/${_moveIn!.year}'
                      : 'Tap to choose a date',
                  style: TextStyle(
                    color: _moveIn != null
                        ? Colors.black87
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 16),

          _card(children: [
            _sectionTitle('Additional Notes'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Any special requests or questions...',
                prefixIcon: Icon(Icons.notes_outlined,
                    color: theme.primaryColor),
                border: border,
                enabledBorder: border,
                focusedBorder: focusedBorder,
              ),
            ),
          ]),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                  _isSubmitting ? 'Sending...' : 'Send Enrollment Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF164e63),
      ),
    );
  }
}
