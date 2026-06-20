import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/auth_controller.dart';
import '../../dashboard/views/dashboard_layout_view.dart';
import 'login_view.dart';

class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  late AnimationController _scannerController;
  late Animation<double> _scannerOffset;

  late AnimationController _textController;
  late Animation<double> _textOpacity;

  bool _animationCompleted = false;

  @override
  void initState() {
    super.initState();

    // Logo scale & fade animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    // Scanning line animation
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scannerOffset = Tween<double>(begin: -30.0, end: 30.0).animate(
      CurvedAnimation(parent: _scannerController, curve: Curves.easeInOut),
    );

    // Text fade-in animation
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    // Start animations sequentially
    _logoController.forward().then((_) {
      _textController.forward();
    });

    // Hold splash screen for at least 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _animationCompleted = true;
        });
        _checkAuthAndNavigate();
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _scannerController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _checkAuthAndNavigate() {
    if (!_animationCompleted) return;

    final authState = ref.read(authControllerProvider);
    if (authState.isLoading) {
      // If auth is still loading, wait and retry when notifyListeners fires
      return;
    }

    Widget targetView;
    if (authState.profile != null) {
      targetView = const DashboardLayoutView();
    } else {
      targetView = const LoginView();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetView,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth changes. Once it completes loading and animation is done, navigate.
    ref.listen(authControllerProvider, (previous, next) {
      if (!next.isLoading && _animationCompleted) {
        _checkAuthAndNavigate();
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF312E81), // Deep Indigo 900
              Color(0xFF1E1B4B), // Deep Indigo 950
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background ambient particles or glow
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.15),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Scanner / Logo Container
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: child,
                        ),
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glowing circle
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.06),
                            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                          ),
                        ),
                        // Inner card scanner container
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 44,
                            color: AppColors.primary,
                          ),
                        ),
                        // Animated Scanning green laser line
                        AnimatedBuilder(
                          animation: _scannerOffset,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _scannerOffset.value),
                              child: child,
                            );
                          },
                          child: Container(
                            width: 70,
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withOpacity(0.8),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Animated Text (Title and Tagline)
                  FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      children: [
                        const Text(
                          'BillBook',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Smart Camera Scan Billing',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom premium loading bar
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    color: AppColors.primaryLight,
                    minHeight: 2.5,
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
