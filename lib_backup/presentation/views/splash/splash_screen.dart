import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:onestay360/presentation/views/auth/auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _bgAnimationController;
  late AnimationController _waveController;
  late AnimationController _textAnimationController;

  // Animations
  late Animation<double> _bgAnimation;
  late Animation<double> _textAnimation;

  // State variables
  bool _isVisible = false;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkAuthState();
  }

  void _initializeAnimations() {
    // Background animation
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _bgAnimation = Tween<double>(begin: 0, end: 1).animate(_bgAnimationController);

    // Wave loading animation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Text scaling animation
    _textAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _textAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _textAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Initial fade-in effect
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isVisible = true);
    });
  }

  void _checkAuthState() {
    // Check if Firebase is initialized and user is logged in
    _navigationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AuthWrapper(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _bgAnimationController.dispose();
    _waveController.dispose();
    _textAnimationController.dispose();
    super.dispose();
  }

  Widget _buildFloatingCircle(
      Alignment alignment,
      double size,
      List<Color> colors,
      Animation<double> animation,
      double speedFactor,
      ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double value = animation.value;
        final double offsetY = sin(value * pi * 2 * speedFactor) * size * 0.2;
        final double rotation = value * 2 * pi * speedFactor;

        return Align(
          alignment: alignment,
          child: Transform.translate(
            offset: Offset(0, offsetY),
            child: Transform.rotate(
              angle: rotation,
              child: Opacity(
                opacity: 0.3 + sin(value * pi * 2) * 0.1,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey.shade50,
                  Colors.grey.shade50,
                  Colors.grey.shade100
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Animated decorative elements
          _buildFloatingCircle(Alignment.topLeft, 128, [Colors.teal.shade100, Colors.green.shade100], _bgAnimation, 0.5),
          _buildFloatingCircle(Alignment.topRight, 96, [Colors.pink.shade100, Colors.pink.shade100], _bgAnimation, 0.7),
          _buildFloatingCircle(Alignment.bottomLeft, 160, [Colors.indigo.shade100, Colors.blue.shade100], _bgAnimation, 0.9),
          _buildFloatingCircle(Alignment.bottomRight, 80, [Colors.purple.shade100, Colors.purple.shade100], _bgAnimation, 0.6),

          // Main content with fade-in animation
          AnimatedOpacity(
            opacity: _isVisible ? 1.0 : 0.0,
            duration: const Duration(seconds: 1),
            child: AnimatedContainer(
              duration: const Duration(seconds: 1),
              transform: Matrix4.translationValues(0, _isVisible ? 0 : 30, 0),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Brand logo with animation
                      Column(
                        children: [
                          AnimatedBuilder(
                            animation: _textAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _textAnimation.value,
                                child: child,
                              );
                            },
                            child: ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Colors.grey, Colors.grey, Colors.black],
                              ).createShader(bounds),
                              child: const Text(
                                'OneStay',
                                style: TextStyle(
                                  fontSize: 60,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '360°',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Where Owners meet Tenants',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade600,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Animated loading indicator
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return AnimatedBuilder(
                                animation: _waveController,
                                builder: (context, child) {
                                  final double value = _waveController.value;
                                  final double delay = 0.1 * index;
                                  final double scale = (value >= delay && value < delay + 0.5)
                                      ? 1.0 + sin((value - delay) / 0.5 * pi)
                                      : 1.0;

                                  return Transform.scale(
                                    scaleY: scale,
                                    child: Container(
                                      width: 4,
                                      height: 32,
                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.grey.shade400,
                                            Colors.grey.shade600
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Initializing your experience...',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}