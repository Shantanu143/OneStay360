// lib/presentation/profile/contact_verification.dart
//
// Adding and verifying the account's email and phone, and copying them to the
// business, member and user documents. Moved out of the old profile screen
// unchanged in behaviour: these flows talk to Firebase Auth (verification
// emails, SMS codes, re-authentication) and only really run against it.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../../data/providers/business_state_provider.dart';

class ContactVerifier {
  ContactVerifier({required this.isOwner, this.onChanged});

  /// Owners also copy the contact details onto the business document.
  final bool isOwner;

  /// Called after the account was reloaded so the screen can redraw.
  final VoidCallback? onChanged;

  Future<void> addEmail(BuildContext context) async {
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
              const Text(
                'Add email & verify',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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

                    Future<void> sendVerification({
                      bool afterReauth = false,
                    }) async {
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) throw Exception('Not signed in');
                        await user.verifyBeforeUpdateEmail(email);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Verification email sent. Check your inbox.',
                            ),
                          ),
                        );
                      } catch (e, st) {
                        debugPrint('verifyBeforeUpdateEmail failed: $e');
                        debugPrintStack(
                          label: 'verifyBeforeUpdateEmail stack',
                          stackTrace: st,
                        );
                        if (!context.mounted) return;

                        final needsReauth = _needsReauth(e);
                        if (needsReauth && !afterReauth) {
                          final reauthed = await _reauthenticateWithPhone(
                            context,
                          );
                          if (reauthed) {
                            await sendVerification(afterReauth: true);
                            return;
                          }
                        }

                        String message = 'Failed to send verification: $e';
                        if (needsReauth) {
                          message =
                              'Session expired. Reauthenticate with OTP to continue.';
                        }

                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> addPhone(BuildContext context) async {
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
                  const SnackBar(
                    content: Text('Enter phone number with country code'),
                  ),
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
                    await refreshPhone(context);
                    if (context.mounted) Navigator.of(ctx).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Phone linked successfully'),
                        ),
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
                            await refreshPhone(context);
                            if (context.mounted) Navigator.of(ctx).pop();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Phone linked successfully'),
                                ),
                              );
                            }
                            return;
                          }
                        } catch (_) {}
                      }
                    }

                    if (context.mounted) {
                      final msg = needsReauth
                          ? 'Session expired. Reauthenticate with Google, then retry.'
                          : 'Link failed: $e';
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(msg)));
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Send OTP first')));
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
                await refreshPhone(context);
                if (context.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
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

                if (context.mounted) {
                  final msg = needsReauth
                      ? 'Session expired. Reauthenticate with Google, then retry.'
                      : 'OTP verification failed: $e';
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(msg)));
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
                  const Text(
                    'Add phone & verify',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone (+91XXXXXXXXXX)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (codeSent)
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'OTP',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.sms_outlined),
                          label: Text(
                            sending
                                ? 'Sending...'
                                : codeSent
                                ? 'Resend OTP'
                                : 'Send OTP',
                          ),
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
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

  Future<void> refreshEmail(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      final email = refreshed?.email;
      onChanged?.call();
      if (email == null || email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email not set on account yet. Complete verification.',
            ),
          ),
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email synced to business and user docs.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to sync email: $e')));
      }
    }
  }

  Future<void> refreshPhone(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      final phone = refreshed?.phoneNumber;
      onChanged?.call();
      if (phone == null || phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone not linked yet. Link and verify first.'),
          ),
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone synced to business and user docs.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to sync phone: $e')));
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
        const SnackBar(
          content: Text('Reauthentication failed: no phone on account.'),
        ),
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
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> sendCode() async {
              setSheetState(() => sending = true);
              await FirebaseAuth.instance.verifyPhoneNumber(
                phoneNumber: phone,
                verificationCompleted: (cred) async {
                  try {
                    await user.reauthenticateWithCredential(cred);
                    success = true;
                    if (context.mounted) Navigator.of(ctx).pop();
                  } catch (_) {
                  } finally {
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Send OTP first')));
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
                if (context.mounted) Navigator.of(ctx).pop();
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Reauth failed: $e')));
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
                  Text(
                    'Reauthenticate with OTP ($phone)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (codeSent)
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'OTP',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.sms_outlined),
                          label: Text(
                            sending
                                ? 'Sending...'
                                : codeSent
                                ? 'Resend OTP'
                                : 'Send OTP',
                          ),
                        ),
                      ),
                      if (codeSent) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: verifying ? null : verifyOtp,
                            icon: verifying
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google reauth failed: $e')));
      return false;
    }
  }

  Future<void> _updateProfileCompletedIfEligible(User? user) async {
    if (user == null) return;
    final hasPhone = user.phoneNumber?.isNotEmpty ?? false;
    final hasVerifiedEmail =
        user.emailVerified && (user.email?.isNotEmpty ?? false);
    if (hasPhone && hasVerifiedEmail) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'profileCompleted': true,
      }, SetOptions(merge: true));
    }
  }
}
