// lib/presentation/views/auth/login_screen.dart
// Unified login/signup screen for both tenants and business users

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:firebase_services/services/ensure_user_document_service.dart';
import '../../../data/providers/business_state_provider.dart';
import '../home_screen.dart';
import 'phone_login_screen.dart';

class LoginScreen extends StatefulWidget {
  final String userType; // 'tenant' or 'business'

  const LoginScreen({
    super.key,
    required this.userType,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late AnimationController _backgroundAnimationController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _backgroundAnimation;

  // Form controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // State variables
  bool _isVisible = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _isSignUp = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _slideAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    // Initialize animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeAnimationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideAnimationController, curve: Curves.easeOut));

    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      _backgroundAnimationController,
    );

    // Start animations
    _startAnimations();
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _isVisible = true;
        });
        _fadeAnimationController.forward();
        _slideAnimationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _backgroundAnimationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Color get _primaryColor => widget.userType == 'tenant'
      ? Colors.blue.shade600
      : Colors.teal.shade600;

  Color get _lightColor => widget.userType == 'tenant'
      ? Colors.blue.shade50
      : Colors.teal.shade50;

  String get _userTypeTitle => widget.userType == 'tenant'
      ? (_isSignUp ? 'Tenant Sign Up' : 'Tenant Login')
      : (_isSignUp ? 'Business Sign Up' : 'Business Login');

  String get _userTypeSubtitle => widget.userType == 'tenant'
      ? (_isSignUp ? 'Create your account to find accommodation' : 'Find your perfect accommodation')
      : (_isSignUp ? 'Register your business to manage properties' : 'Manage your properties efficiently');

  Widget _buildFloatingElement(
      double top,
      double left,
      double size,
      Color color,
      double speed,
      ) {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        final double animationValue = _backgroundAnimation.value;
        final double offsetY = sin(animationValue * 2 * pi * speed) * 30;
        final double offsetX = cos(animationValue * 2 * pi * speed * 0.7) * 20;
        final double opacity = 0.05 + sin(animationValue * 2 * pi * speed * 0.5) * 0.03;

        return Positioned(
          top: top + offsetY,
          left: left + offsetX,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSocialLoginButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: Icon(icon, color: onPressed == null ? Colors.grey : color, size: 20),
        label: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: onPressed == null ? Colors.grey : Colors.grey.shade700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isConfirmPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !(isConfirmPassword ? _isConfirmPasswordVisible : _isPasswordVisible),
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey.shade800,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: _primaryColor),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              (isConfirmPassword ? _isConfirmPasswordVisible : _isPasswordVisible) ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey.shade600,
            ),
            onPressed: () {
              setState(() {
                if (isConfirmPassword) {
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                } else {
                  _isPasswordVisible = !_isPasswordVisible;
                }
              });
            },
          )
              : null,
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade600),
          hintStyle: TextStyle(color: Colors.grey.shade400),
        ),
      ),
    );
  }

  // Helper method to show snackbar with mounted check
  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : _primaryColor,
      ),
    );
  }

  // Handle navigation after successful authentication - UPDATED
  Future<void> _handlePostAuthNavigation(User user) async {
    try {
      print('🔄 [LoginScreen._handlePostAuthNavigation] Starting for user: ${user.uid}');
      
      // ✅ STEP 1: ENSURE USER DOCUMENT EXISTS
      // This must happen FIRST, before any other Firestore access
      // Guarantees /users/{uid} exists before BusinessStateProvider reads it
      print('📝 [LoginScreen] Step 1: Ensuring user document exists...');
      await EnsureUserDocumentService().ensureUserDocumentExists(user);
      print('✅ [LoginScreen] Step 1: User document ensured');
      if (!mounted) return;

      // ✅ STEP 2: LOAD BUSINESS STATE
      // Now that /users/{uid} is guaranteed to exist, load the business state
      // This validates membership and sets businessId (or null if no business)
      print('📝 [LoginScreen] Step 2: Loading business state...');
      final businessState = context.read<BusinessStateProvider>();
      await businessState.loadUserData();
      print('✅ [LoginScreen] Step 2: Business state loaded. businessId=${businessState.businessId}');
      if (!mounted) return;

      // ✅ STEP 3: Determine navigation target
      // businessState.businessId will be:
      // - Non-null and valid → User has active membership, show business UI
      // - null → No business yet, show empty state with "Create Business" button
      final businessId = businessState.businessId ?? user.uid;
      print('📝 [LoginScreen] Step 3: Determined businessId for navigation: $businessId (from state: ${businessState.businessId})');

      // ✅ STEP 4: Navigate to home screen
      // BusinessScaffold will gate UI based on businessId
      if (!mounted) return;
      print('📝 [LoginScreen] Step 4: Navigating to BusinessHomeScreen...');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BusinessHomeScreen(businessId: businessId),
        ),
      );
      print('✅ [LoginScreen] Navigation completed');
    } catch (e) {
      if (mounted) {
        _showSnackbar('Error during authentication: ${e.toString()}', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  // Check if email is already registered with Google
  Future<bool> _isEmailRegisteredWithGoogle(String email) async {
    try {
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      return methods.contains('google.com');
    } catch (e) {
      return false;
    }
  }

  // Sign up or Sign in with email and password
  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      User? user;
      if (_isSignUp) {
        // Check if email is already registered with Google
        final isGoogleUser = await _isEmailRegisteredWithGoogle(_emailController.text);
        if (isGoogleUser) {
          _showSnackbar(
            'This email is already registered with Google. Please sign in with Google or use a different email.',
            isError: true,
          );
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        // Sign up with email and password
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        user = userCredential.user;
      } else {
        // Sign in with email and password
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        user = userCredential.user;
      }

      if (user != null) {
        await _handlePostAuthNavigation(user);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'email-already-in-use' && !_isSignUp) {
          // If trying to sign in but email is registered with Google
          _showSnackbar(
            'This email is registered with Google. Please sign in with Google.',
            isError: true,
          );
        } else {
          _showSnackbar(e.message ?? 'An unknown error occurred.', isError: true);
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('An error occurred: ${e.toString()}', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  // Sign in with Google
  void _handleGoogleSignIn() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (!mounted) return;
      if (googleUser == null) {
        _showSnackbar('Google Sign In was cancelled.');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        await _handlePostAuthNavigation(user);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'account-exists-with-different-credential') {
          _showSnackbar(
            'This email is already registered with email/password. Please sign in with email/password.',
            isError: true,
          );
        } else {
          _showSnackbar(e.message ?? 'An error occurred during Google Sign In.', isError: true);
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        print('Google Sign In error: $e');
        _showSnackbar('An error occurred during Google Sign In: $e', isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _lightColor,
              Colors.white,
              _lightColor.withOpacity(0.3),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Floating background elements
            _buildFloatingElement(80, 50, 100, _primaryColor.withOpacity(0.1), 0.3),
            _buildFloatingElement(200, 280, 80, _primaryColor.withOpacity(0.08), 0.5),
            _buildFloatingElement(400, 100, 120, _primaryColor.withOpacity(0.06), 0.4),
            _buildFloatingElement(500, 250, 90, _primaryColor.withOpacity(0.09), 0.6),

            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back button
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios),
                          color: Colors.grey.shade700,
                        ),

                        const SizedBox(height: 20),

                        // Header
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    widget.userType == 'tenant'
                                        ? Icons.person
                                        : Icons.business,
                                    color: _primaryColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _userTypeTitle,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    Text(
                                      _userTypeSubtitle,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),

                        // Social login options
                        Column(
                          children: [
                            _buildSocialLoginButton(
                              text: 'Continue with Google',
                              icon: Icons.g_mobiledata,
                              color: Colors.red,
                              onPressed: _handleGoogleSignIn,
                            ),
                            const SizedBox(height: 12),
                            _buildSocialLoginButton(
                              text: 'Continue with Phone',
                              icon: Icons.phone,
                              color: Colors.green.shade600,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PhoneLoginScreen(userType: widget.userType),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'or continue with email',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Email/Password form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _emailController,
                                label: 'Email Address',
                                hint: 'Enter your email',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),

                              _buildTextField(
                                controller: _passwordController,
                                label: 'Password',
                                hint: 'Enter your password',
                                icon: Icons.lock_outline,
                                isPassword: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),

                              if (_isSignUp) // Conditionally show confirm password for signup
                                _buildTextField(
                                  controller: _confirmPasswordController,
                                  label: 'Confirm Password',
                                  hint: 'Re-enter your password',
                                  icon: Icons.lock_reset_outlined,
                                  isPassword: true,
                                  isConfirmPassword: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),

                              const SizedBox(height: 16),

                              // Forgot password (only for login mode)
                              if (!_isSignUp)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      print('Forgot password');
                                      // TODO: Implement navigation to a "Forgot Password" screen
                                    },
                                    child: Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: _primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 24),

                              // Login/Signup button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSubmit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                    shadowColor: _primaryColor.withOpacity(0.3),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      strokeWidth: 2,
                                    ),
                                  )
                                      : Text(
                                    _isSignUp ? 'Create Account' : 'Sign In',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Sign up/Sign in toggle
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _isSignUp ? 'Already have an account? ' : 'Don\'t have an account? ',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _isLoading ? null : () {
                                      setState(() {
                                        _isSignUp = !_isSignUp;
                                        // Clear password fields when toggling
                                        _emailController.clear();
                                        _passwordController.clear();
                                        _confirmPasswordController.clear();
                                        _formKey.currentState?.reset(); // Reset form validation state
                                      });
                                    },
                                    child: Text(
                                      _isSignUp ? 'Sign In' : 'Sign Up',
                                      style: TextStyle(
                                        color: _primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Terms and privacy
                        Text(
                          'By continuing, you agree to our Terms of Service and Privacy Policy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}