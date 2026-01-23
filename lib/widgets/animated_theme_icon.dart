import 'package:flutter/material.dart';

/// High-performance animated icon widget that smoothly transitions
/// color during theme changes
class AnimatedThemeIcon extends StatelessWidget {
  const AnimatedThemeIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 500), // Match theme transition
      curve: Curves.easeInOutCubic, // Apple-style curve
      tween: ColorTween(begin: color, end: color),
      builder: (context, animatedColor, child) {
        return Icon(
          icon,
          size: size,
          color: animatedColor ?? color,
          semanticLabel: semanticLabel,
        );
      },
    );
  }
}
