// path: lib/features/home/widgets/shimmer_list_loader.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/theme_skeleton.dart';

import '../../../widgets/adaptive_loading_placeholder.dart';

class ShimmerListLoader extends StatelessWidget {
  const ShimmerListLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: ThemeSkeleton.shared.insetsSymmetric(
        horizontal: 12,
        vertical: 8,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => Padding(
        padding: ThemeSkeleton.shared.insetsSymmetric(vertical: 8),
        child: const AdaptiveLoadingPlaceholder(height: 240),
      ),
    );
  }
}
