import 'package:flutter/material.dart';

/// High-performance animated container that smoothly transitions
/// colors during theme changes with zero jank
class AnimatedThemeContainer extends StatelessWidget {
  const AnimatedThemeContainer({
    super.key,
    this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.decoration,
    this.color,
    this.alignment,
    this.constraints,
  });

  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxDecoration? decoration;
  final Color? color;
  final AlignmentGeometry? alignment;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500), // Match theme transition
      curve: Curves.easeInOutCubic, // Apple-style curve
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      decoration: decoration,
      color: color,
      alignment: alignment,
      constraints: constraints,
      child: child,
    );
  }
}
