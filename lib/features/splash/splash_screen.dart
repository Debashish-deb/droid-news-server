// splash_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/splash_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  bool _showLogo = false;
  bool _showText = false;
  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;

  @override
  void initState() {
    super.initState();

    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );
    _zoomAnimation = Tween<double>(begin: 0.7, end: 1.4).animate(
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
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _showText = true);
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 2));

    final splashService = SplashService();
    final nextRoute = await splashService.resolveInitialRoute();

    if (!mounted) return;
    context.go(nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Center(
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
                    'assets/app-icon.png',
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
                      'BDNews',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(strokeWidth: 2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
