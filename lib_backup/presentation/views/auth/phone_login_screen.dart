// lib/presentation/views/auth/phone_login_screen.dart
// Phone number login screen with OTP verification

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onestay360/presentation/views/auth/profile_setup_screen.dart';
import 'package:onestay360/presentation/views/tenant/home_screen.dart';
import 'package:onestay360/presentation/services/firestore_service.dart';

class PhoneLoginScreen extends StatefulWidget {
  final String userType;

  const PhoneLoginScreen({
    super.key,
    required this.userType,
  });

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
  List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
  List.generate(6, (index) => FocusNode());

  String? _verificationId;
  bool _isOtpSent = false;
  bool _isLoading = false;
  int _resendTimer = 30;

  Color get _primaryColor => widget.userType == 'tenant'
      ? Colors.blue.shade600
      : Colors.teal.shade600;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // Helper method to show snackbar
  void _showSnackbar(String message, {Color? color}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color ?? _primaryColor,
        ),
      );
    }
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
        _startResendTimer();
      }
    });
  }

  // Send OTP to the user's phone number using Firebase
  void _sendOtp() async {
    // Add country code if not present. Assuming +91 for India as an example.
    final String phoneNumber = _phoneController.text.startsWith('+')
        ? _phoneController.text
        : '+91${_phoneController.text}';

    if (phoneNumber.length < 13) {
      _showSnackbar('Please enter a valid 10-digit phone number.', color: Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // This is called when the verification is completed automatically
        try {
          final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
          final user = userCredential.user;

          if (user != null) {
            _showSnackbar('Phone number verified successfully!', color: Colors.green);
            await FirestoreService().initializeUser(user, widget.userType);
            _navigatePostAuth();
          }
        } on FirebaseAuthException catch (e) {
          _showSnackbar(e.message ?? 'Auto-verification failed.', color: Colors.red);
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackbar(e.message ?? 'Failed to send OTP.', color: Colors.red);
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _isOtpSent = true;
            _isLoading = false;
            _resendTimer = 30; // Reset timer
            _startResendTimer();
          });
          _showSnackbar('OTP sent to your phone!', color: Colors.green);
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (mounted) {
          _verificationId = verificationId;
        }
      },
      timeout: const Duration(seconds: 60),
    );
  }

  // Verify the OTP entered by the user
  void _verifyOtp() async {
    final String otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      _showSnackbar('Please enter the 6-digit OTP.', color: Colors.red);
      return;
    }
    if (_verificationId == null) {
      _showSnackbar('Verification ID not available. Please resend the OTP.', color: Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        _showSnackbar('Signed in successfully!', color: Colors.green);
        await FirestoreService().initializeUser(user, widget.userType);
        _navigatePostAuth();
      }
    } on FirebaseAuthException catch (e) {
      _showSnackbar(e.message ?? 'Invalid OTP. Please try again.', color: Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigatePostAuth() async {
    if (widget.userType == 'tenant') {
      final user = FirebaseAuth.instance.currentUser;
      final existingData = await FirestoreService().getUserData(user!.uid);
      final displayName = (existingData?['fullName'] as String?)
          ?? (user.displayName?.isNotEmpty == true ? user.displayName : user.email?.split('@').first)
          ?? 'Tenant';
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TenantHomeScreen(tenantName: displayName),
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileSetupScreen(userType: widget.userType),
        ),
      );
    }
  }

  Widget _buildOtpField(int index) {
    return Container(
      width: 50,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextFormField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primaryColor, width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _otpFocusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _otpFocusNodes[index - 1].requestFocus();
          }
        },
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios, color: Colors.grey.shade700),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                _isOtpSent ? 'Verify Phone Number' : 'Enter Phone Number',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isOtpSent
                    ? 'Enter the 6-digit code sent to ${_phoneController.text}'
                    : 'We\'ll send you a verification code',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 40),

              if (!_isOtpSent) ...[
                // Phone number input
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '9876543210',
                    prefixIcon: Icon(Icons.phone, color: _primaryColor),
                    prefixText: '+91 ', // Assuming Indian number format
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _primaryColor, width: 2),
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
              ] else ...[
                // OTP input
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) => _buildOtpField(index)),
                ),

                const SizedBox(height: 24),

                // Resend OTP
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Didn\'t receive code? ',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    if (_resendTimer > 0)
                      Text(
                        'Resend in ${_resendTimer}s',
                        style: TextStyle(color: Colors.grey.shade500),
                      )
                    else
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _resendTimer = 30;
                          });
                          _sendOtp();
                        },
                        child: Text(
                          'Resend OTP',
                          style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              const Spacer(),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : _isOtpSent
                      ? _verifyOtp
                      : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                      : Text(
                    _isOtpSent ? 'Verify & Continue' : 'Send OTP',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
