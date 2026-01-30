import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/team_invitation_service.dart';
import 'invite_welcome_screen.dart';
import 'auth/phone_login_screen.dart';

class InviteLandingScreen extends StatefulWidget {
  final String inviteId;
  const InviteLandingScreen({super.key, required this.inviteId});

  @override
  State<InviteLandingScreen> createState() => _InviteLandingScreenState();
}

class _InviteLandingScreenState extends State<InviteLandingScreen> {
  Map<String, dynamic>? _invite;
  bool _loading = true;
  bool _accepting = false;
  String? _error;

  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  String _maskPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 4) return digits;
    final last4 = digits.substring(digits.length - 4);
    return '••••••$last4';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = context.read<TeamInvitationService>();
    try {
      final data = await svc.fetchInvitation(widget.inviteId);
      if (!mounted) return;
      setState(() {
        _invite = data;
        _loading = false;
        if (data == null) {
          _error = 'Invitation not found';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load invite';
        _loading = false;
      });
    }
  }

  Future<void> _accept() async {
    final invitePhone = (_invite?['phone'] as String?) ?? '';
    final authed = await _ensureSignedIn(invitePhone);
    if (!authed) return;

    setState(() {
      _accepting = true;
      _error = null;
    });
    try {
      final result = await context.read<TeamInvitationService>().acceptInvitation(widget.inviteId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => InviteWelcomeScreen(
            businessId: result['businessId'] as String,
            role: result['role'] as String,
            propertyIds: List<String>.from(result['propertyIds'] as List),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _accepting = false;
      });
    }
  }

  Future<bool> _ensureSignedIn(String invitePhone) async {
    final user = FirebaseAuth.instance.currentUser;
    final userPhone = user?.phoneNumber ?? '';

    final normalizedInvite = _normalizePhone(invitePhone);
    final normalizedUser = _normalizePhone(userPhone);
    final phoneMatches = normalizedInvite.isNotEmpty && normalizedInvite == normalizedUser;

    if (user != null && phoneMatches) return true;

    if (!mounted) return false;
    
    // Navigate directly to phone login with prefilled invite phone
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PhoneLoginScreen(
          userType: 'business',
          initialPhone: invitePhone,
          returnToCaller: true,
        ),
      ),
    );

    if (result == true) {
      final updatedUser = FirebaseAuth.instance.currentUser;
      final updatedPhone = updatedUser?.phoneNumber ?? '';
      final normalizedInviteAfter = _normalizePhone(invitePhone);
      final normalizedUpdated = _normalizePhone(updatedPhone);
      if (normalizedInviteAfter.isNotEmpty && normalizedInviteAfter == normalizedUpdated) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = (_invite?['role'] ?? '') as String;
    final businessId = (_invite?['businessId'] ?? '') as String;
    final properties = ((_invite?['propertyIds'] as List?) ?? []).cast<String>();
    final invitePhone = (_invite?['phone'] as String?) ?? '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE6F4F1), Color(0xFFF7FBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
              : _error != null
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87)),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white70),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F766E).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.mail_outline, color: Color(0xFF0F766E), size: 24),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'You are invited',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        color: const Color(0xFF0F172A),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Join the team on OneStay360',
                                      style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 12,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Business ID', style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey[600])),
                                                const SizedBox(height: 4),
                                                Text(businessId, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE0F2F1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.verified_user, size: 18, color: Color(0xFF0F766E)),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    role.isEmpty ? 'Role' : role,
                                                    style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.w700),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 18),
                                        if (invitePhone.isNotEmpty) ...[
                                          Text('Invited phone', style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey[600])),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE0F2F1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.phone_iphone, size: 18, color: Color(0xFF0F766E)),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _maskPhone(invitePhone),
                                                  style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.w700),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                        ],
                                        Text('Assigned properties', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 10),
                                        if (properties.isEmpty)
                                          Text('No properties assigned', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]))
                                        else
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: properties
                                                .map(
                                                  (p) => Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF0F766E).withOpacity(0.08),
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(color: const Color(0xFF0F766E).withOpacity(0.35)),
                                                    ),
                                                    child: Text(p, style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.w600)),
                                                  ),
                                                )
                                                .toList(),
                                          ),

                                        const SizedBox(height: 18),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.lock_open, color: Color(0xFF0F766E), size: 18),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  'Use the phone number from this invite to continue. We will verify it before granting access.',
                                                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[800]),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _accepting ? null : _accept,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _accepting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Accept & Continue', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
