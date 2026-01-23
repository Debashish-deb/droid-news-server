import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({
    super.key,
    this.height = 150,
    this.width = double.infinity,
    this.borderRadius = 16.0,
    this.margin = const EdgeInsets.all(8.0),
    this.period = const Duration(milliseconds: 1500),
  });

  final double height;
  final double width;
  final double borderRadius;
  final EdgeInsetsGeometry margin;
  final Duration period;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color baseColor =
        isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final Color highlightColor =
        isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return Card(
      elevation: 6,
      margin: margin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: period,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
