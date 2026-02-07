// File: lib/features/splash/splash_screen.dart

import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../core/splash_service.dart';
import '../../../core/security/security_service.dart';
import '../../../core/security/root_detector.dart';
import '../../../core/app_paths.dart';
import '../../providers/theme_providers.dart';
import '../../../infrastructure/services/notification_service.dart';
import '../../../core/enums/theme_mode.dart';
import '../../../core/constants.dart' show AppPerformance;
import '../../../core/performance_config.dart';
import '../../../core/theme.dart';
import '../../../infrastructure/observability/analytics_service.dart' show AnalyticsService;
import '../../../infrastructure/persistence/offline_service.dart' show OfflineService;
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/particle_background.dart';

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
  late Animation<double> _glowAnimation;
  late Animation<double> _particleAnimation;
  List<Particle> _particles = [];
  bool _reduceMotion = false;
  bool _reduceEffects = false;

  @override
  void initState() {
    super.initState();
    _initializeParticles();
    _initializeAnimations();
    _redirect();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final perf = PerformanceConfig.of(context);
    if (perf.reduceMotion != _reduceMotion || perf.reduceEffects != _reduceEffects) {
      _reduceMotion = perf.reduceMotion;
      _reduceEffects = perf.reduceEffects;
      _controller.duration = _reduceMotion
          ? AppPerformance.animationDuration
          : const Duration(milliseconds: 1800);
      if (_reduceEffects) {
        _particles = [];
      } else if (_particles.isEmpty) {
        _initializeParticles();
      }
    }
  }

  void _initializeParticles() {
    if (_reduceEffects) return;
    final Random random = Random();
    _particles = List.generate(25, (index) {
      final double size = random.nextDouble() * 4 + 2;
      final double speed = random.nextDouble() * 0.5 + 0.2;
      return Particle(
        x: random.nextDouble() * 1.0,
        y: random.nextDouble() * 1.0,
        size: size,
        speed: speed,
        color: Colors.white.withOpacity(random.nextDouble() * 0.3 + 0.1),
      );
    });
  }

  void _initializeAnimations() {
    const Duration duration = AppPerformance.reduceMotion
        ? AppPerformance.animationDuration
        : Duration(milliseconds: 1800);
    const Curve scaleCurve =
        AppPerformance.reduceMotion ? Curves.easeOutCubic : Curves.elasticOut;
    _controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.7, curve: scaleCurve),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.9, curve: Curves.easeInOutSine),
      ),
    );

    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0),
      ),
    );

    _controller.forward();
  }

  Future<void> _redirect() async {
    if (!SecurityService().isDeviceSecure) {
      if (!mounted) return;
      context.go(AppPaths.securityLockout);
      return;
    }

    RootDetector.detect().then((rootStatus) {
      if (rootStatus.isRooted && rootStatus.confidence > 0.6) {
        debugPrint('⚠️ ROOTED DEVICE DETECTED');
        debugPrint('   Confidence: ${(rootStatus.confidence * 100).toStringAsFixed(1)}%');
        debugPrint('   Indicators: ${rootStatus.detectedIndicators.join(", ")}');
        
        if (mounted) {
          _showPremiumRootWarningDialog(rootStatus);
        }
      }
    }).catchError((e) {
      debugPrint('Failed to check root status: $e');
    });

    final List<Future<void>> tasks = [
      Future<void>.delayed(const Duration(milliseconds: 1500)),

      _safeInit(OfflineService.initialize(), 'OfflineService'),
      _safeInit(NotificationService.initialize(), 'NotificationService'),
      _safeInit(MobileAds.instance.initialize(), 'MobileAds'),
      _safeInit(AnalyticsService.logAppOpen(), 'Analytics'),
    ];

    try {
      await Future.wait(tasks).timeout(
        const Duration(milliseconds: 4500),
        onTimeout: () {
          debugPrint('⚠️ Splash services timed out - forcing navigation');
          return [];
        },
      );
    } catch (e) {
      debugPrint('Splash initialization error: $e');
      
    }

    if (!mounted) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final SplashService splashService = SplashService(prefs: prefs);
    final String next = await splashService.resolveInitialRoute();

    if (mounted) context.go(next);
  }

  Future<void> _safeInit(Future<void> future, String label) async {
    try {
      await future;
    } catch (e) {
      debugPrint('❌ $label initialization failed: $e');
    }
  }
  
  Future<void> _showPremiumRootWarningDialog(dynamic rootStatus) async {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: theme.colorScheme.surface.withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 20,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.orange.withOpacity(0.1),
                  theme.colorScheme.surface.withOpacity(0.95),
                ],
              ),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.orange, width: 2),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 32,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    loc.securityWarning,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.orange,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.rootedDeviceWarning,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onBackground,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          loc.restrictedFeaturesInfo,
                          style: TextStyle(
                            color: theme.colorScheme.onBackground.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureRow(Icons.payment_rounded, loc.inAppPurchases),
                        _buildFeatureRow(Icons.credit_card_rounded, loc.savedPaymentMethods),
                        _buildFeatureRow(Icons.fingerprint_rounded, loc.biometricAuth),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Confidence: ${(rootStatus.confidence * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 8,
                      shadowColor: Colors.orange.withOpacity(0.4),
                    ),
                    child: Text(
                      loc.continueAnyway,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.orange.withOpacity(0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onBackground.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
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
    final bool reduceEffects = PerformanceConfig.of(context).reduceEffects;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _getPremiumBackground(themeMode),
        child: Stack(
          children: <Widget>[
            // Animated background particles
            if (!reduceEffects)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _particleAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ParticlePainter(
                        particles: _particles,
                        animationValue: _particleAnimation.value,
                      ),
                    );
                  },
                ),
              ),

            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      isDark
                          ? const Color(0xFF000000).withOpacity(
                              reduceEffects ? 0.18 : 0.3,
                            )
                          : const Color(0xFFFFFFFF).withOpacity(
                              reduceEffects ? 0.06 : 0.1,
                            ),
                    ],
                  ),
                ),
              ),
            ),

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
                child: _buildPremiumSplashCard(themeMode),
              ),
            ),

            // Bottom loading text
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: _buildLoadingText(isDark),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _getPremiumBackground(AppThemeMode mode) {
    final List<Color> colors = AppGradients.getBackgroundGradient(mode);
    
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors[0].withOpacity(0.85),
          colors[1].withOpacity(0.85),
        ],
      ),
    );
  }

  Widget _buildPremiumSplashCard(AppThemeMode themeMode) {
    final bool isDark = themeMode == AppThemeMode.dark;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: 320,
          height: 420,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              // Outer glow
              BoxShadow(
                color: isDark
                    ? Colors.blueAccent.withOpacity(_glowAnimation.value * 0.15)
                    : Colors.blue.withOpacity(_glowAnimation.value * 0.1),
                blurRadius: 40,
                spreadRadius: 5,
              ),
              // Inner glow
              BoxShadow(
                color: Colors.white.withOpacity(_glowAnimation.value * 0.05),
                blurRadius: 20,
                spreadRadius: -10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            Colors.white.withOpacity(0.12),
                            Colors.white.withOpacity(0.06),
                            Colors.white.withOpacity(0.02),
                          ]
                        : [
                            Colors.white.withOpacity(0.85),
                            Colors.white.withOpacity(0.65),
                            Colors.white.withOpacity(0.45),
                          ],
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.15)
                        : Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    // Hero logo with gradient border
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  Colors.blueAccent.withOpacity(0.8),
                                  Colors.indigoAccent.withOpacity(0.8),
                                ]
                              : [
                                  Colors.blue,
                                  Colors.lightBlueAccent,
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.blueAccent.withOpacity(0.4)
                                : Colors.blue.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Hero(
                        tag: 'app_logo',
                        child: Container(
                          width: 120,
                          height: 120,
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/app_logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isDark
                                        ? [
                                            const Color(0xFF1A1A2E),
                                            const Color(0xFF16213E),
                                          ]
                                        : [
                                            const Color(0xFF2196F3),
                                            const Color(0xFF21CBF3),
                                          ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.article_rounded,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // App title with gradient text
                    ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  Colors.blueAccent,
                                  Colors.indigoAccent,
                                ]
                              : [
                                  const Color(0xFF1A237E),
                                  const Color(0xFF283593),
                                ],
                        ).createShader(bounds);
                      },
                      child: Text(
                        'BD NewsReader',
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    Text(
                      'Stay Informed. Stay Connected.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white.withOpacity(0.7)
                            : Colors.grey[700],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Premium loading indicator
                    _buildPremiumLoadingIndicator(isDark),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumLoadingIndicator(bool isDark) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 80 * _controller.value,
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              Colors.blueAccent,
                              Colors.indigoAccent,
                            ]
                          : [
                              const Color(0xFF1A237E),
                              const Color(0xFF283593),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: (sin(_controller.value * 2 * pi) + 1) / 2,
                  child: child,
                );
              },
              child: Icon(
                Icons.circle,
                size: 6,
                color: isDark ? Colors.blueAccent : Colors.blue,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: (sin(_controller.value * 2 * pi + 0.5) + 1) / 2,
                  child: child,
                );
              },
              child: Icon(
                Icons.circle,
                size: 6,
                color: isDark ? Colors.blueAccent : Colors.blue,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: (sin(_controller.value * 2 * pi + 1.0) + 1) / 2,
                  child: child,
                );
              },
              child: Icon(
                Icons.circle,
                size: 6,
                color: isDark ? Colors.blueAccent : Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingText(bool isDark) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value > 0.5 ? 1.0 : 0.0,
          child: child,
        );
      },
      child: Column(
        children: [
          Text(
            'Initializing...',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withOpacity(0.6)
                  : Colors.grey[700]!.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version 1.0.0',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withOpacity(0.4)
                  : Colors.grey[600]!.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
