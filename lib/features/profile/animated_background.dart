// lib/features/profile/animated_background.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import '../../../presentation/providers/theme_providers.dart';
import '../../../core/theme_provider.dart'; // Fixed relative path
import '../../../core/theme.dart'; // for AppGradients

class AnimatedBackground extends ConsumerWidget {
  const AnimatedBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeMode mode = ref.watch(currentThemeModeProvider);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _buildMetallicBase(mode),
        if (mode == AppThemeMode.dark || mode == AppThemeMode.bangladesh)
          Positioned.fill(child: _buildGlossOverlay(mode)),
        Container(color: _glassTint(mode)),
      ],
    );
  }

  Widget _buildMetallicBase(AppThemeMode mode) {
    // Use getBackgroundGradient for correct Dark Mode colors (Black)
    final List<Color> gradientColors = AppGradients.getBackgroundGradient(mode);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
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
    final Alignment center =
        mode == AppThemeMode.dark
            ? const Alignment(-0.5, -0.5)
            : const Alignment(0.6, -0.6);
    final double radius = mode == AppThemeMode.dark ? 1.5 : 1.4;
    final double opacity = mode == AppThemeMode.dark ? 0.05 : 0.15;

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: radius,
          colors: <Color>[
            Colors.white.withOpacity(opacity),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.7],
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
