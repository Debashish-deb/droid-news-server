// lib/features/profile/animated_background.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/core/theme_provider.dart';

class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({super.key});

  Color _getGlassColor(BuildContext context) {
    final mode = Provider.of<ThemeProvider>(context).appThemeMode;
    switch (mode) {
      case AppThemeMode.light:
        return const Color(0xFFE3F2FD).withOpacity(0.1); // Light mode: Light blue shade
      case AppThemeMode.dark:
        return const Color(0xFF1C1F26).withOpacity(0.1); // Dark mode: Dark blue grey
      case AppThemeMode.bangladesh:
        return const Color(0xFF00512C).withOpacity(0.2); // Bangladesh: Darker green glass
      case AppThemeMode.system:
      default:
        final brightness = Theme.of(context).brightness;
        return brightness == Brightness.dark
            ? const Color(0xFF1C1F26).withOpacity(0.1)
            : const Color(0xFFE3F2FD).withOpacity(0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glassColor = _getGlassColor(context);

    final themeMode = Provider.of<ThemeProvider>(context).appThemeMode;
    List<Color> lightColors;
    switch (themeMode) {
      case AppThemeMode.light:
        lightColors = [Color(0xFF8EC5FC).withOpacity(0.05), Color(0xFFE0C3FC).withOpacity(0.05)];
        break;
      case AppThemeMode.dark:
        lightColors = [Color(0xFF0A0F1F).withOpacity(0.05), Color(0xFF1A1D20).withOpacity(0.05)];
        break;
      case AppThemeMode.bangladesh:
        lightColors = [Color(0xFF00512C).withOpacity(0.08), Color(0xFF007B4E).withOpacity(0.08)];
        break;
      case AppThemeMode.system:
      default:
        final brightness = Theme.of(context).brightness;
        lightColors = brightness == Brightness.dark
            ? [Color(0xFF0A0F1F).withOpacity(0.05), Color(0xFF1A1D20).withOpacity(0.05)]
            : [Color(0xFF8EC5FC).withOpacity(0.05), Color(0xFFE0C3FC).withOpacity(0.05)];
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/theme/profile1.png',
          fit: BoxFit.cover,
        ),
        Container(color: glassColor),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: lightColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ],
    );
  }
}