import 'package:flutter/material.dart';

import 'adaptive_loading_placeholder.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({
    super.key,
    this.height = 150,
    this.width = double.infinity,
    this.radius = 16,
  });

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AdaptiveLoadingPlaceholder(
      height: height,
      width: width,
      borderRadius: radius,
    );
  }
}
