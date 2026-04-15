import 'package:flutter/material.dart';
import '../../../../core/theme/theme_skeleton.dart';

import '../../../widgets/adaptive_loading_placeholder.dart';

class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({
    super.key,
    this.height = 150,
    this.width = double.infinity,
    this.borderRadius = 16.0,
    this.margin = ThemeSkeleton.insetsAll8,
    this.period = const Duration(milliseconds: 1500),
  });

  final double height;
  final double width;
  final double borderRadius;
  final EdgeInsetsGeometry margin;
  final Duration period;

  @override
  Widget build(BuildContext context) {
    return AdaptiveLoadingPlaceholder(
      height: height,
      width: width,
      borderRadius: borderRadius,
      margin: margin,
      period: period,
      useCard: true,
      elevation: 6,
    );
  }
}
