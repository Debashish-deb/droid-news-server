// lib/features/news/widgets/animated_background.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme_provider.dart';
import '../../../core/theme.dart';

/// A full-screen overlay that can optionally blur the backdrop
/// and apply a semi-transparent animated gradient tint based on theme.
class AnimatedBackground extends StatelessWidget {
  final Duration duration;
  final Widget? child;
  final double blurSigma;
  final double overlayOpacity;

  const AnimatedBackground({
    super.key,
    this.duration = const Duration(seconds: 20),
    this.child,
    this.blurSigma = 20,
    this.overlayOpacity = 0.3,
  });

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ThemeProvider>().appThemeMode;
    final colors = _gradientColors(mode);

    return Stack(fit: StackFit.expand, children: [
      if (blurSigma > 0)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: const SizedBox.shrink(),
          ),
        ),
      if (overlayOpacity > 0)
        Positioned.fill(
          child: AnimatedContainer(
            duration: duration,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors
                    .map((c) => c.withOpacity(overlayOpacity))
                    .toList(),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
      if (child != null) child!,
    ]);
  }

  List<Color> _gradientColors(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.dark => [Colors.black87, Colors.grey.shade900],
      AppThemeMode.bangladesh => [const Color(0xFF004D40), const Color(0xFF26A69A)],
      AppThemeMode.light => [Colors.white, Colors.grey.shade100],
    };
  }
}
