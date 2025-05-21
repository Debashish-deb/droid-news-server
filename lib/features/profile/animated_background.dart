// lib/features/profile/animated_background.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme_provider.dart'; // Fixed relative path
import '../../../core/theme.dart'; // for AppGradients

class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = Provider.of<ThemeProvider>(context).appThemeMode;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildMetallicBase(mode),
        if (mode == AppThemeMode.dark || mode == AppThemeMode.bangladesh)
          Positioned.fill(child: _buildGlossOverlay(mode)),
        Container(color: _glassTint(mode)),
      ],
    );
  }

  Widget _buildMetallicBase(AppThemeMode mode) {
  final gradientColors = AppGradients.getGradientColors(mode);
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          gradientColors[0].withOpacity(0.9),
          gradientColors[1].withOpacity(0.9),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  );
}
  Widget _buildGlossOverlay(AppThemeMode mode) {
    final center = mode == AppThemeMode.dark
        ? const Alignment(-0.5, -0.5)
        : const Alignment(0.6, -0.6);
    final radius = mode == AppThemeMode.dark ? 1.5 : 1.4;
    final opacity = mode == AppThemeMode.dark ? 0.05 : 0.15;

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: radius,
          colors: [
            Colors.white.withOpacity(opacity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7],
        ),
      ),
    );
  }

  Color _glassTint(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.dark:
        return const Color(0xFF1C1F26).withOpacity(0.1);
      case AppThemeMode.light:
        return Colors.white.withOpacity(0.1);
      case AppThemeMode.bangladesh:
      default:
        return const Color(0xFF6E7B75).withOpacity(0.15);
    }
  }
}
