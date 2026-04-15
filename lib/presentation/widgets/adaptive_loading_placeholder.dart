import 'dart:io';
import '../../core/theme/theme_skeleton.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/config/performance_config.dart';

class AdaptiveLoadingPlaceholder extends StatelessWidget {
  const AdaptiveLoadingPlaceholder({
    super.key,
    this.height = 150,
    this.width = double.infinity,
    this.borderRadius = 16,
    this.margin = EdgeInsets.zero,
    this.period = const Duration(milliseconds: 1500),
    this.elevation = 0,
    this.useCard = false,
    this.semanticsLabel = 'Loading content',
  });

  final double height;
  final double width;
  final double borderRadius;
  final EdgeInsetsGeometry margin;
  final Duration period;
  final double elevation;
  final bool useCard;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perf = PerformanceConfig.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTest =
        kDebugMode && Platform.environment.containsKey('FLUTTER_TEST');
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    final shouldAnimate =
        !isTest &&
        !perf.reduceEffects &&
        !perf.lowPowerMode &&
        !perf.isLowEndDevice;
    final actualPeriod = shouldAnimate
        ? period
        : const Duration(milliseconds: 2500);

    Widget child = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: useCard ? baseColor : theme.cardColor,
        borderRadius: ThemeSkeleton.shared.circular(borderRadius),
      ),
    );

    if (shouldAnimate) {
      child = Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: actualPeriod,
        child: child,
      );
    }

    if (useCard) {
      child = Card(
        elevation: elevation,
        margin: margin,
        shape: RoundedRectangleBorder(
          borderRadius: ThemeSkeleton.shared.circular(borderRadius),
        ),
        child: child,
      );
    } else if (margin != EdgeInsets.zero) {
      child = Padding(padding: margin, child: child);
    }

    return Semantics(label: semanticsLabel, child: child);
  }
}
