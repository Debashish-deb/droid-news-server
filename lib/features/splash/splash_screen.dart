// lib/features/splash/splash_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/splash_service.dart';
import '../../core/theme_provider.dart';
import '../../core/theme.dart'; // for AppGradients

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  bool _showLogo = false;
  bool _showText = false;
  late final AnimationController _zoomController;
  late final Animation<double> _zoomAnimation;

  @override
  void initState() {
    super.initState();
    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );
    _zoomAnimation = Tween<double>(begin: 0.7, end: 1.2).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeInOutBack),
    );
    _runAnimations();
    _navigateToNext();
  }

  @override
  void dispose() {
    _zoomController.dispose();
    super.dispose();
  }

  Future<void> _runAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _showLogo = true);
    _zoomController.forward();
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _showText = true);
  }

  Future<void> _navigateToNext() async {
    // wait for splash animations
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final next = await SplashService(prefs: prefs).resolveInitialRoute();

    // defer navigation until after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = context.watch<ThemeProvider>().appThemeMode;
    final gradientColors = AppGradients.getGradientColors(mode);
    final startColor = gradientColors[0];
    final endColor = gradientColors[1];

    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        // tinted backdrop
        Container(color: theme.colorScheme.background.withOpacity(0.4)),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: const SizedBox.expand(),
        ),
        Center(
          child: AnimatedOpacity(
            opacity: _showLogo ? 1 : 0,
            duration: const Duration(milliseconds: 800),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _zoomAnimation,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/icon.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedOpacity(
                  opacity: _showText ? 1 : 0,
                  duration: const Duration(milliseconds: 600),
                  child: Column(
                    children: [
                      Text(
                        'BD News Reader',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary.withOpacity(0.8),
                        ),
                        backgroundColor:
                            theme.colorScheme.onBackground.withOpacity(0.2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
