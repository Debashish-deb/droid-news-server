// File: lib/features/splash/splash_screen.dart

import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/splash_service.dart';
import '../../core/theme_provider.dart';
import '../../core/security/security_service.dart';
import '../../core/security/root_detector.dart';
import '../../core/app_paths.dart';
import '../../presentation/providers/theme_providers.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/offline_service.dart';
import '../../core/utils/analytics_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _redirect();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      // Reduced duration for snappier feel (1.8s -> 1.2s)
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
  }

  Future<void> _redirect() async {
    // 🔒 Enforce Security Check immediately
    if (!SecurityService().isDeviceSecure) {
      if (!mounted) return;
      context.go(AppPaths.securityLockout);
      return;
    }

    // 🚨 Root Detection Check (non-blocking)
    // Run in background, don't block splash screen
    RootDetector.detect().then((rootStatus) {
      if (rootStatus.isRooted && rootStatus.confidence > 0.6) {
        debugPrint('⚠️ ROOTED DEVICE DETECTED');
        debugPrint('   Confidence: ${(rootStatus.confidence * 100).toStringAsFixed(1)}%');
        debugPrint('   Indicators: ${rootStatus.detectedIndicators.join(", ")}');
        
        if (mounted) {
          _showRootWarningDialog(rootStatus);
        }
      }
    }).catchError((e) {
      debugPrint('Failed to check root status: $e');
      // Continue anyway - don't block user if check fails
    });

    // Parallelize heavy initializations
    // We wait for the longest of: Animation OR Services
    // This ensures splash is seen but we don't wait IF services take longer
    final List<Future<void>> tasks = [
      // Minimum splash display time (matches animation)
      Future<void>.delayed(const Duration(milliseconds: 1200)),

      // Heavy services moved from main.dart
      OfflineService.initialize(),
      NotificationService.initialize(),
      MobileAds.instance.initialize(),
      AnalyticsService.logAppOpen(),
    ];

    await Future.wait(tasks);

    if (!mounted) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final SplashService splashService = SplashService(prefs: prefs);
    final String next = await splashService.resolveInitialRoute();

    if (mounted) context.go(next);
  }
  
  Future<void> _showRootWarningDialog(dynamic rootStatus) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('Security Warning'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This device appears to be rooted/jailbroken.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'For your security, some features may be restricted:',
              ),
              const SizedBox(height: 8),
              const Text('• In-app purchases'),
              const Text('• Saved payment methods'),
              const Text('• Biometric authentication'),
              const SizedBox(height: 12),
              Text(
                'Confidence: ${(rootStatus.confidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue Anyway'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeMode themeMode = ref.watch(currentThemeModeProvider);
    final bool isDark = themeMode == AppThemeMode.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _getThemeDecoration(themeMode),
        child: Stack(
          children: <Widget>[
            // Subtle grid pattern
            _buildAnimatedBackground(isDark),
            // Main content
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _opacityAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: _buildGlassmorphicCard(themeMode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Theme-aware gradient background
  BoxDecoration _getThemeDecoration(AppThemeMode mode) {
    // 🔒 Always use Premium Dark background for Splash to match native launch screen
    // This prevents the "White Flash" and ensures a premium "Cinema" feel.
    return const BoxDecoration(
      gradient: RadialGradient(
        radius: 1.5,
        colors: <Color>[
          Color(0xFF1E1E2C), // Lighter center (matching native #1A1A2E roughly)
          Color(0xFF000000), // Dark edges
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground(bool isDark) {
    // A subtle moving light orb or shimmer could be nice, but for "crystal clear",
    // a clean background is best. We'll use a very subtle animated glow.
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double glow = sin(_controller.value * 2 * pi);
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2), // Behind the card
                radius: 0.8 + (glow * 0.1), // Pulping radius
                colors:
                    isDark
                        ? <Color>[
                          Colors.blueAccent.withOpacity(0.05),
                          Colors.transparent,
                        ]
                        : <Color>[
                          Colors.blueAccent.withOpacity(0.03),
                          Colors.transparent,
                        ],
                stops: const <double>[0.0, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlassmorphicCard(AppThemeMode themeMode) {
    // Force Dark Glossy look for Splash
    const bool isDark = true;

    return Container(
      width: 300,
      height: 380, // Taller for elegance
      decoration: const BoxDecoration(
        color: Colors.transparent,
        // No solid color, rely on blur and gradients
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // 1. Back Light (The "light coming behind")
          _buildBackLight(isDark),

          // 2. Glass Layer
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  // Border removed for cleaner look
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors:
                        isDark
                            ? <Color>[
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
                            ]
                            : <Color>[
                              Colors.white.withOpacity(
                                0.8,
                              ), // Crystal clear gloss
                              Colors.white.withOpacity(0.3),
                            ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Hero(tag: 'app_logo', child: _buildLogo()),
              const SizedBox(height: 30),
              _buildAppTitle(isDark),
              const SizedBox(height: 24),
              _buildLoadingIndicator(isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackLight(bool isDark) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Transform.scale(
          scale: 1.0 + (_controller.value * 0.1), // Slight pulse
          child: Container(
            width: 140,
            height: 140,
            margin: const EdgeInsets.only(
              bottom: 60,
            ), // Align behind logo mostly
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color:
                      isDark
                          ? Colors.blue.withOpacity(0.4)
                          : Colors.amber.withOpacity(
                            0.4,
                          ), // Warm light for white bg, blue for dark
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo() {
    // Glassy Logo Container
    return Container(
      width: 110,
      height: 110,
      padding: const EdgeInsets.all(4), // Border spacing
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        // gradient: LinearGradient(...) // border gradient
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(12),
        child: ClipOval(
          child: Image.asset(
            'assets/icon.png',
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) => const Icon(
                  Icons.article,
                  size: 50,
                  color: Color(0xFF1A1A2E),
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppTitle(bool isDark) {
    // SF Pro-inspired typography using Inter font
    return Text(
      'BD NewsReader',
      style: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700, // SF Pro Bold equivalent
        letterSpacing: -0.5, // Apple's tight letter-spacing
        color: isDark ? Colors.white : const Color(0xFF1C1C1E),
        shadows:
            isDark
                ? <Shadow>[const Shadow(color: Colors.black38, blurRadius: 12)]
                : null,
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isDark) {
    // Apple-style activity indicator
    return const CupertinoActivityIndicator(
      radius: 14, // Slightly larger for splash visibility
      color: Colors.white70, // Subtle white for elegance
    );
  }
}
