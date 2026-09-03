import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/placeholder_images.dart';
import 'onboarding_screen.dart';
import 'registration_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Official GROWBOX brand logo (white planter icon + orange "Growbox"
  /// wordmark on transparent background).
  ///
  /// White art is always correct here: the splash background is the brand
  /// green (AppColors.primary) in both light and dark themes, so there is
  /// no brightness-based variant swap on this screen.
  static String get logoUrl => PlaceholderImages.growboxLogo;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Logo entrance animation (scale + fade).
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  // Subtle looping pulse on the logo glow.
  late final AnimationController _pulseController;
  late final Animation<double> _pulseValue;

  // Footer fade-in.
  late final AnimationController _footerController;
  late final Animation<double> _footerOpacity;

  // Tagline slide-up.
  late final AnimationController _taglineController;
  late final Animation<Offset> _taglineOffset;
  late final Animation<double> _taglineOpacity;

  @override
  void initState() {
    super.initState();

    // ── Logo entrance (0 – 800 ms) ────────────────────────────────
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    // ── Logo glow pulse (loops after entrance) ────────────────────
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // ── Footer fade-in (400 – 900 ms) ─────────────────────────────
    _footerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _footerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _footerController, curve: Curves.easeIn),
    );

    // ── Tagline slide-up (600 – 1100 ms) ──────────────────────────
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _taglineOffset = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeOutCubic),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeIn),
    );

    // ── Kick off entrance animations ──────────────────────────────
    _startAnimations();

    // ── Navigate after 4 seconds ──────────────────────────────────
    Timer(const Duration(seconds: 4), () async {
      if (!mounted) return;
      final hasSeenOnboarding = await OnboardingScreen.hasCompleted();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, _, _) => hasSeenOnboarding
              ? const RegistrationScreen()
              : const OnboardingScreen(),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
        ),
      );
    });
  }

  Future<void> _startAnimations() async {
    // Small initial pause so the screen settles.
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    // Logo scales in.
    _logoController.forward();

    // Footer fades in after logo starts.
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _footerController.forward();

    // Tagline slides up.
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _taglineController.forward();

    // Start the looping pulse after entrance finishes.
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _footerController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final double logoSize = [size.width * 0.85, size.height * 0.55, 380.0]
        .reduce((a, b) => a < b ? a : b);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: SizedBox.expand(
          child: Column(
            children: [
              // ── Logo area with glow ────────────────────────────
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _pulseValue,
                    builder: (context, child) {
                      // Pulse oscillates glow opacity between 0.15 and 0.35.
                      final glowOpacity =
                          0.15 + 0.20 * math.sin(_pulseValue.value * math.pi);
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.white.withValues(alpha: glowOpacity),
                              blurRadius: 60,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _logoController,
                        _pulseController,
                      ]),
                      builder: (context, _) {
                        return Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Image.asset(
                              SplashScreen.logoUrl,
                              width: logoSize,
                              height: logoSize,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Text(
                                  'GROWBOX',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // ── Tagline ────────────────────────────────────────
              SlideTransition(
                position: _taglineOffset,
                child: FadeTransition(
                  opacity: _taglineOpacity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Fresh produce, delivered to your door',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Footer ─────────────────────────────────────────
              FadeTransition(
                opacity: _footerOpacity,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Powered by',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Universal Integrated Agricultural Network Ltd',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
