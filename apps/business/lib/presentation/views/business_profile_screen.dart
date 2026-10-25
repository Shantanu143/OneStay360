// lib/presentation/views/business/business_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'widgets/business_scaffold.dart';
import 'payment_methods_screen.dart';
import '../../data/providers/business_state_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth/login_screen.dart';
import 'member_profile_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

class BusinessProfileScreen extends StatelessWidget {
  const BusinessProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF0891B2);
    final role = context.watch<BusinessStateProvider>().role;
    final isOwner = role == 'owner';
    final isManager = role == 'manager';

    final tabs = <Tab>[const Tab(text: 'Overview')];
    final views = <Widget>[_BusinessOverviewTab(role: role)];

    if (isOwner) {
      tabs.addAll(const [Tab(text: 'KYC'), Tab(text: 'Team')]);
      views.addAll([
        _BusinessKYCTab(role: role),
        _BusinessTeamTab(role: role),
      ]);
    }

    tabs.add(const Tab(text: 'Settings'));
    views.add(_BusinessSettingsTab(role: role));

    return DefaultTabController(
      length: tabs.length,
      child: BusinessScaffold(
        currentTab: BusinessTab.profile,
        appBarBottom: TabBar(
          labelColor: primary,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: primary,
          isScrollable: true,
          tabs: tabs,
        ),
        body: TabBarView(
          children: views,
        ),
      ),
    );
  }
}

class _BusinessOverviewTab extends StatefulWidget {
  final String role;
  const _BusinessOverviewTab({required this.role});

  @override
  State<_BusinessOverviewTab> createState() => _BusinessOverviewTabState();
}

class _BusinessOverviewTabState extends State<_BusinessOverviewTab> {
  bool get isOwner => widget.role == 'owner';
  bool get isManager => widget.role == 'manager';
  bool get isStaff => widget.role == 'staff';

  @override
  Widget build(BuildContext context) {
    final businessState = context.watch<BusinessStateProvider>();
    final profileCompleted = businessState.profileCompleted;
    final businessName = businessState.businessName;
    final currentUser = FirebaseAuth.instance.currentUser;
    final contactEmail = currentUser?.email ?? 'Not set';
    final contactPhone = currentUser?.phoneNumber ?? 'Not set';
    final hasEmail = (currentUser?.email?.isNotEmpty ?? false);
    final hasPhone = (currentUser?.phoneNumber?.isNotEmpty ?? false);
    final canManageContact = isOwner || isManager || isStaff;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroCard(role: widget.role, businessName: businessName),
        const SizedBox(height: 14),
        if (!profileCompleted)
          _InfoBanner(
            text: 'Complete profile: add and verify both email and phone to finish setup.',
          ),
        const SizedBox(height: 10),
        _CardSection(
          title: 'Company',
          child: _InfoRow(icon: Icons.apartment_rounded, label: 'Name', value: businessName.isNotEmpty ? businessName : 'Not set'),
        ),
        const SizedBox(height: 16),
        _CardSection(
          title: 'Contact',
          child: Column(
            children: [
              _InfoRow(icon: Icons.email_outlined, label: 'Email', value: contactEmail),
              if (canManageContact)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!hasEmail)
                      TextButton(
                        onPressed: () => _showAddEmailSheet(context),
                        child: const Text('Add email & verify'),
                      ),
                    if (hasEmail)
                      TextButton(
                        onPressed: () => _syncEmailToFirestore(context),
                        child: const Text('Refresh & sync'),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: contactPhone),
              if (canManageContact)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!hasPhone)
                      TextButton(
                        onPressed: () => _showAddPhoneSheet(context),
                        child: const Text('Add phone & verify'),
                      ),
                    if (hasPhone)
                      TextButton(
                        onPressed: () => _syncPhoneToFirestore(context),
                        child: const Text('Refresh & sync'),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _CardSection(
          title: 'Access',
          child: Column(
            children: [
              _InfoRow(icon: Icons.badge_outlined, label: 'Role', value: widget.role.isNotEmpty ? widget.role : 'Not set'),
              if (isOwner || isManager)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemberProfileScreen(
                          businessId: businessState.businessId ?? '',
                          memberId: currentUser?.uid ?? '',
                          initialName: businessState.fullName,
                          initialEmail: currentUser?.email ?? '',
                          initialPhone: currentUser?.phoneNumber ?? '',
                          role: widget.role,
                          status: 'active',
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit my details'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (isOwner)
          _LiveBusinessStats(businessId: businessState.businessId)
        else
          _LockedSection(title: 'Business stats', reason: 'Owners see the full analytics.'),
      ],
    );
  }

  Future<void> _showAddEmailSheet(BuildContext context) async {
    final emailController = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add email & verify', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Send verification'),
                  onPressed: () async {
                    final email = emailController.text.trim();
                    if (email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter an email')), 
                      );
                      return;
                    }
                    Navigator.of(ctx).pop();

                    Future<void> sendVerification({bool afterReauth = false}) async {
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) throw Exception('Not signed in');
                        await user.verifyBeforeUpdateEmail(email);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Verification email sent. Check your inbox.')),
                        );
                      } catch (e, st) {
                        debugPrint('verifyBeforeUpdateEmail failed: $e');
                        debugPrintStack(label: 'verifyBeforeUpdateEmail stack', stackTrace: st);
                        if (!mounted) return;

                        final needsReauth = _needsReauth(e);
                        if (needsReauth && !afterReauth) {
                          final reauthed = await _reauthenticateWithPhone(context);
                          if (reauthed) {
                            await sendVerification(afterReauth: true);
                            return;
                          }
                        }

                        String message = 'Failed to send verification: $e';
                        if (needsReauth) {
                          message = 'Session expired. Reauthenticate with OTP to continue.';
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(message)),
                        );
                      }
                    }

                    await sendVerification();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddPhoneSheet(BuildContext context) async {
    final phoneController = TextEditingController();
    final otpController = TextEditingController();
    String? verificationId;
    bool codeSent = false;
    bool sending = false;
    bool verifying = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> sendCode() async {
              final phone = phoneController.text.trim();
              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter phone number with country code')), 
                );
                return;
              }
              setSheetState(() => sending = true);
              await FirebaseAuth.instance.verifyPhoneNumber(
                phoneNumber: phone,
                verificationCompleted: (cred) async {
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;
                    await user.linkWithCredential(cred);
                    await _syncPhoneToFirestore(context);
                    if (mounted) Navigator.of(ctx).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Phone linked successfully')),
                      );
                    }
                  } catch (e) {
                    final needsReauth = _needsReauth(e);
                    if (needsReauth) {
                      final reauthed = await _reauthenticateWithGoogle(context);
                      if (reauthed) {
                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await user.linkWithCredential(cred);
                            await _syncPhoneToFirestore(context);
                            if (mounted) Navigator.of(ctx).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Phone linked successfully')),
                              );
                            }
                            return;
                          }
                        } catch (_) {}
                      }
                    }

                    if (mounted) {
                      final msg = needsReauth
                          ? 'Session expired. Reauthenticate with Google, then retry.'
                          : 'Link failed: $e';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg)),
                      );
                    }
                  } finally {
                    setSheetState(() => sending = false);
                  }
                },
                verificationFailed: (e) {
                  setSheetState(() => sending = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message ?? 'Verification failed')),
                  );
                },
                codeSent: (vid, _) {
                  setSheetState(() {
                    verificationId = vid;
                    codeSent = true;
                    sending = false;
                  });
                },
                codeAutoRetrievalTimeout: (vid) {
                  verificationId = vid;
                },
                timeout: const Duration(seconds: 60),
              );
            }

            Future<void> verifyCode({bool afterReauth = false}) async {
              if (verificationId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Send OTP first')), 
                );
                return;
              }
              final otp = otpController.text.trim();
              if (otp.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter 6-digit OTP')), 
                );
                return;
              }
              setSheetState(() => verifying = true);
              try {
                final cred = PhoneAuthProvider.credential(
                  verificationId: verificationId!,
                  smsCode: otp,
                );
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception('Not signed in');
                await user.linkWithCredential(cred);
                await _syncPhoneToFirestore(context);
                if (mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Phone linked successfully')),
                  );
                }
              } catch (e) {
                final needsReauth = _needsReauth(e);
                if (needsReauth && !afterReauth) {
                  final reauthed = await _reauthenticateWithGoogle(context);
                  if (reauthed) {
                    await verifyCode(afterReauth: true);
                    return;
                  }
                }

                if (mounted) {
                  final msg = needsReauth
                      ? 'Session expired. Reauthenticate with Google, then retry.'
                      : 'OTP verification failed: $e';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg)),
                  );
                }
              } finally {
                setSheetState(() => verifying = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add phone & verify', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone (+91XXXXXXXXXX)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (codeSent)
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'OTP',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLength: 6,
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: sending ? null : sendCode,
                          icon: sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.sms_outlined),
                          label: Text(sending ? 'Sending...' : codeSent ? 'Resend OTP' : 'Send OTP'),
                        ),
                      ),
                      if (codeSent) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: verifying ? null : verifyCode,
                            icon: verifying
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.verified_outlined),
                            label: Text(verifying ? 'Verifying...' : 'Verify'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _syncEmailToFirestore(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      final email = refreshed?.email;
      setState(() {});
      if (email == null || email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not set on account yet. Complete verification.')),
        );
        return;
      }

      final businessId = context.read<BusinessStateProvider>().businessId;
      if (businessId != null && businessId.isNotEmpty) {
        if (isOwner) {
          await FirebaseFirestore.instance
              .collection('businesses')
              .doc(businessId)
              .set({'contactEmail': email}, SetOptions(merge: true));
        }

        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .collection('members')
            .doc(refreshed!.uid)
            .set({'email': email}, SetOptions(merge: true));
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(refreshed!.uid)
          .set({'email': email}, SetOptions(merge: true));

      await _updateProfileCompletedIfEligible(refreshed);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email synced to business and user docs.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sync email: $e')),
        );
      }
    }
  }

  Future<void> _syncPhoneToFirestore(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      final phone = refreshed?.phoneNumber;
      setState(() {});
      if (phone == null || phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone not linked yet. Link and verify first.')),
        );
        return;
      }

      final businessId = context.read<BusinessStateProvider>().businessId;
      if (businessId != null && businessId.isNotEmpty) {
        if (isOwner) {
          await FirebaseFirestore.instance
              .collection('businesses')
              .doc(businessId)
              .set({'contactPhone': phone}, SetOptions(merge: true));
        }

        await FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .collection('members')
            .doc(refreshed!.uid)
            .set({'phone': phone}, SetOptions(merge: true));
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(refreshed!.uid)
          .set({'phoneNumber': phone}, SetOptions(merge: true));

      await _updateProfileCompletedIfEligible(refreshed);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone synced to business and user docs.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sync phone: $e')),
        );
      }
    }
  }

  bool _needsReauth(Object? e) {
    return e is FirebaseAuthException &&
        (e.code == 'user-token-expired' || e.code == 'requires-recent-login');
  }

  Future<bool> _reauthenticateWithPhone(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final phone = user?.phoneNumber;
    if (user == null || phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reauthentication failed: no phone on account.')),
      );
      return false;
    }

    final otpController = TextEditingController();
    String? verificationId;
    bool codeSent = false;
    bool sending = false;
    bool verifying = false;
    bool success = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          Future<void> sendCode() async {
            setSheetState(() => sending = true);
            await FirebaseAuth.instance.verifyPhoneNumber(
              phoneNumber: phone,
              verificationCompleted: (cred) async {
                try {
                  await user.reauthenticateWithCredential(cred);
                  success = true;
                  if (mounted) Navigator.of(ctx).pop();
                } catch (_) {} finally {
                  setSheetState(() => sending = false);
                }
              },
              verificationFailed: (e) {
                setSheetState(() => sending = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message ?? 'Reauth failed')),
                );
              },
              codeSent: (vid, _) {
                setSheetState(() {
                  verificationId = vid;
                  codeSent = true;
                  sending = false;
                });
              },
              codeAutoRetrievalTimeout: (vid) {
                verificationId = vid;
              },
              timeout: const Duration(seconds: 60),
            );
          }

          Future<void> verifyOtp() async {
            if (verificationId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Send OTP first')), 
              );
              return;
            }
            final otp = otpController.text.trim();
            if (otp.length != 6) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter 6-digit OTP')), 
              );
              return;
            }
            setSheetState(() => verifying = true);
            try {
              final cred = PhoneAuthProvider.credential(
                verificationId: verificationId!,
                smsCode: otp,
              );
              await user.reauthenticateWithCredential(cred);
              success = true;
              if (mounted) Navigator.of(ctx).pop();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Reauth failed: $e')),
              );
            } finally {
              setSheetState(() => verifying = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reauthenticate with OTP ($phone)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 12),
                if (codeSent)
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'OTP',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLength: 6,
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: sending ? null : sendCode,
                        icon: sending
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.sms_outlined),
                        label: Text(sending ? 'Sending...' : codeSent ? 'Resend OTP' : 'Send OTP'),
                      ),
                    ),
                    if (codeSent) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: verifying ? null : verifyOtp,
                          icon: verifying
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.verified_outlined),
                          label: Text(verifying ? 'Verifying...' : 'Verify'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        });
      },
    );

    return success;
  }

  Future<bool> _reauthenticateWithGoogle(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return false;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google reauth failed: $e')),
      );
      return false;
    }
  }

  Future<void> _updateProfileCompletedIfEligible(User? user) async {
    if (user == null) return;
    final hasPhone = user.phoneNumber?.isNotEmpty ?? false;
    final hasVerifiedEmail = user.emailVerified && (user.email?.isNotEmpty ?? false);
    if (hasPhone && hasVerifiedEmail) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'profileCompleted': true}, SetOptions(merge: true));
    }
  }
}

class _BusinessKYCTab extends StatelessWidget {
  final String role;
  const _BusinessKYCTab({required this.role});

  bool get isOwner => role == 'owner';

  @override
  Widget build(BuildContext context) {
    if (!isOwner) {
      return const _LockedSection(title: 'KYC', reason: 'Only owners can manage KYC.');
    }

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CardSection(
          title: 'Business KYC',
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'GSTIN',
                  hintText: '22ABCDE1234F1Z5',
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(
                    borderSide: const BorderSide(color: Color(0xFF0891B2)),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'PAN (Company)',
                  hintText: 'ABCDE1234F',
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(
                    borderSide: const BorderSide(color: Color(0xFF0891B2)),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Registered Address',
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(
                    borderSide: const BorderSide(color: Color(0xFF0891B2)),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => HapticFeedback.lightImpact(),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save KYC'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _CardSection(
          title: 'Compliance Documents',
          child: Column(
            children: [
              OutlinedButton.icon(
                onPressed: () => HapticFeedback.lightImpact(),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload Incorporation Certificate'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => HapticFeedback.lightImpact(),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload GST Certificate'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BusinessTeamTab extends StatelessWidget {
  final String role;
  const _BusinessTeamTab({required this.role});

  bool get isOwnerOrManager => role == 'owner' || role == 'manager';

  @override
  Widget build(BuildContext context) {
    final businessId = context.watch<BusinessStateProvider>().businessId;

    if (businessId == null || businessId.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text('No business context found. Please create or select a business.'),
          ),
        ],
      );
    }

    if (!isOwnerOrManager) {
      return const _LockedSection(title: 'Team', reason: 'Team management is limited to owners and managers.');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .collection('members')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading members: ${snapshot.error}'),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final members = docs.map((d) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          return {
            'uid': data['uid'] ?? d.id,
            'role': data['role'] ?? '',
            'status': data['status'] ?? '',
            'name': data['name'] ?? '',
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? '',
          };
        }).toList();

        members.sort((a, b) {
          final aOwner = (a['role'] as String).toLowerCase() == 'owner';
          final bOwner = (b['role'] as String).toLowerCase() == 'owner';
          if (aOwner == bOwner) return 0;
          return aOwner ? -1 : 1;
        });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: () => HapticFeedback.lightImpact(),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add Member'),
                ),
              ),
            ),
            if (members.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('No team members yet', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    Text('Invite your team to collaborate on properties and tenants.'),
                  ],
                ),
              ),
            for (final member in members)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0891B2).withOpacity(0.1),
                    child: const Icon(Icons.person_outline, color: Color(0xFF0891B2)),
                  ),
                  title: Text(
                    (member['name'] as String).isNotEmpty
                        ? member['name'] as String
                        : ((member['role'] as String).toLowerCase() == 'owner'
                            ? 'Owner details pending'
                            : 'Member details pending'),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${member['role'] ?? ''} • ${member['status'] ?? ''}'),
                      if ((member['email'] as String).isNotEmpty)
                        Text(member['email'] as String),
                      if ((member['phone'] as String).isNotEmpty)
                        Text(member['phone'] as String),
                      if ((member['email'] as String).isEmpty || (member['phone'] as String).isEmpty || (member['name'] as String).isEmpty)
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MemberProfileScreen(
                                  businessId: businessId,
                                  memberId: member['uid'] as String,
                                  initialName: member['name'] as String? ?? '',
                                  initialEmail: member['email'] as String? ?? '',
                                  initialPhone: member['phone'] as String? ?? '',
                                  role: member['role'] as String? ?? '',
                                  status: member['status'] as String? ?? '',
                                ),
                              ),
                            );
                          },
                          child: const Text('Add details'),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MemberProfileScreen(
                            businessId: businessId,
                            memberId: member['uid'] as String,
                            initialName: member['name'] as String? ?? '',
                            initialEmail: member['email'] as String? ?? '',
                            initialPhone: member['phone'] as String? ?? '',
                            role: member['role'] as String? ?? '',
                            status: member['status'] as String? ?? '',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BusinessSettingsTab extends StatelessWidget {
  final String role;
  const _BusinessSettingsTab({required this.role});

  @override
  Widget build(BuildContext context) {
    final isOwner = role == 'owner';
    return isOwner ? _buildOwnerSettings(context) : _buildMemberSettings(context);
  }

  Widget _buildOwnerSettings(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsCard(
          children: [
            _SettingRow(
              icon: Icons.payment_outlined,
              title: 'Payment Methods',
              subtitle: 'Manage UPI, Bank, Cash',
              color: const Color(0xFF8b5cf6),
              onTap: () {
                final businessState = context.read<BusinessStateProvider>();
                final businessId = businessState.businessId;

                if (businessId == null || businessId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No active business access')),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentMethodsScreen(
                      businessId: businessId,
                    ),
                  ),
                );
              },
            ),
            const _RowDivider(),
            const _SettingRow(
              icon: Icons.password_outlined,
              title: 'Change Password',
              subtitle: 'Update account password',
              color: Color(0xFF3b82f6),
            ),
            const _RowDivider(),
            const _SettingRow(
              icon: Icons.notifications_active_outlined,
              title: 'Notifications',
              subtitle: 'Manage alerts & emails',
              color: Color(0xFFf59e0b),
            ),
            const _RowDivider(),
            const _SettingRow(
              icon: Icons.verified_user_outlined,
              title: 'Access Control',
              subtitle: 'Manage team permissions',
              color: Color(0xFF10b981),
            ),
            const _RowDivider(),
            const _SettingRow(
              icon: Icons.description_outlined,
              title: 'Billing',
              subtitle: 'Invoices & payments',
              color: Color(0xFF6366f1),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SettingsCard(
          children: [
            _SettingRow(
              icon: Icons.logout_outlined,
              title: 'Logout',
              subtitle: 'Sign out of business account',
              color: Color(0xFFef4444),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemberSettings(BuildContext context) {
    final businessState = context.watch<BusinessStateProvider>();
    final businessId = businessState.businessId ?? '';
    final fullName = businessState.fullName;
    final currentUser = FirebaseAuth.instance.currentUser;

    void showSnack(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsCard(
          children: [
            _SettingRow(
              icon: Icons.person_outline,
              title: 'My Profile',
              subtitle: 'Update your name, email & phone',
              color: const Color(0xFF0891B2),
              onTap: () {
                if (currentUser == null || businessId.isEmpty) {
                  showSnack('No active business access');
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberProfileScreen(
                      businessId: businessId,
                      memberId: currentUser.uid,
                      initialName: fullName,
                      initialEmail: currentUser.email ?? '',
                      initialPhone: currentUser.phoneNumber ?? '',
                      role: role,
                      status: 'active',
                    ),
                  ),
                );
              },
            ),
            const _RowDivider(),
            _SettingRow(
              icon: Icons.notifications_active_outlined,
              title: 'Notifications',
              subtitle: 'Manage alerts & reminders',
              color: const Color(0xFFf59e0b),
              onTap: () => showSnack('Notification preferences coming soon.'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsCard(
          children: [
            _SettingRow(
              icon: Icons.help_outline,
              title: 'Support',
              subtitle: 'Contact OneStay360 support',
              color: const Color(0xFF0ea5e9),
              onTap: () => showSnack('Support channel coming soon.'),
            ),
            const _RowDivider(),
            _SettingRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'Read our privacy practices',
              color: const Color(0xFF8b5cf6),
              onTap: () => _openPrivacyPolicy(context),
            ),
            const _RowDivider(),
            _SettingRow(
              icon: Icons.logout_outlined,
              title: 'Logout',
              subtitle: 'Sign out of this account',
              color: const Color(0xFFef4444),
              onTap: () => _confirmSignOut(context),
            ),
            const _RowDivider(),
            _SettingRow(
              icon: Icons.delete_forever_outlined,
              title: 'Delete Account',
              subtitle: 'Permanently remove your account and data',
              color: Colors.red.shade700,
              onTap: () => _confirmDeleteAccount(context),
            ),
          ],
        ),
      ],
    );
  }

  static Future<void> _openPrivacyPolicy(BuildContext context) async {
    final uri = Uri.parse('https://onestay360.brandedpatil.in/privacy');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please visit https://onestay360.brandedpatil.in/privacy')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open privacy policy.')),
      );
    }
  }

  static Future<void> _confirmSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFef4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen(userType: 'business')),
        (route) => false,
      );
    }
  }

  static Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'This action is irreversible. Your credentials and profile data will be permanently deleted.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Permanently Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('deleteUserAccount');
      await callable.call();
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen(userType: 'business')),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete account: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

class _LockedSection extends StatelessWidget {
  final String title;
  final String reason;
  const _LockedSection({required this.title, required this.reason});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFF0F766E), size: 32),
            const SizedBox(height: 10),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              reason,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String role;
  final String businessName;
  const _HeroCard({required this.role, required this.businessName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0F2F1), Color(0xFFF0FDFA)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0F766E).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName.isNotEmpty ? businessName : 'Your business',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user, size: 16, color: Color(0xFF0F766E)),
                      const SizedBox(width: 6),
                      Text('Role: $role', style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _CardSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF164e63),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0891B2).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF0891B2)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<_Stat> items;
  const _StatsRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map((e) => Expanded(
                child: Column(
                  children: [
                    Text(
                      e.value,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Color(0xFF164e63),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _Stat {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});
}

/// Fetches live property count, active tenant count, and occupancy rate
/// from Firestore and renders them in the same style as the old hardcoded stats.
class _LiveBusinessStats extends StatelessWidget {
  final String? businessId;
  const _LiveBusinessStats({required this.businessId});

  @override
  Widget build(BuildContext context) {
    if (businessId == null || businessId!.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<_BusinessStatsData>(
      future: _fetchStats(businessId!),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final loading = snapshot.connectionState == ConnectionState.waiting;

        final properties = loading ? '…' : data!.properties.toString();
        final tenants    = loading ? '…' : data!.tenants.toString();
        final occupancy  = loading
            ? '…'
            : data!.totalBeds == 0
                ? '0%'
                : '${((data.tenants / data.totalBeds) * 100).clamp(0, 100).toStringAsFixed(0)}%';

        return _CardSection(
          title: 'Business Stats',
          child: _StatsRow(
            items: [
              _Stat(value: properties, label: 'Properties'),
              _Stat(value: tenants,    label: 'Tenants'),
              _Stat(value: occupancy,  label: 'Occupancy'),
            ],
          ),
        );
      },
    );
  }

  Future<_BusinessStatsData> _fetchStats(String businessId) async {
    final db = FirebaseFirestore.instance;

    // Properties + total bed count
    final propsSnap = await db
        .collection('businesses')
        .doc(businessId)
        .collection('properties')
        .get();

    int totalBeds = 0;
    for (final doc in propsSnap.docs) {
      totalBeds += ((doc.data()['totalBeds'] as num?)?.toInt() ?? 0);
    }

    // Active tenants (business-scoped collection)
    final tenantsSnap = await db
        .collection('businesses')
        .doc(businessId)
        .collection('tenants')
        .where('status', isEqualTo: 'active')
        .count()
        .get();

    final tenantCount = tenantsSnap.count ?? 0;

    return _BusinessStatsData(
      properties: propsSnap.docs.length,
      tenants: tenantCount,
      totalBeds: totalBeds,
    );
  }
}

class _BusinessStatsData {
  final int properties;
  final int tenants;
  final int totalBeds;
  const _BusinessStatsData({
    required this.properties,
    required this.tenants,
    required this.totalBeds,
  });
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
      child: Column(children: children),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: onTap ?? () => HapticFeedback.lightImpact(),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: Colors.grey.shade200);
  }
}

