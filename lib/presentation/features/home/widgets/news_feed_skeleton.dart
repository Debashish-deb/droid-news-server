import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/theme_skeleton.dart';
import '../../../../core/config/performance_config.dart' show PerformanceConfig;

class NewsFeedSkeleton extends StatelessWidget {
  const NewsFeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    final listView = ListView.builder(
      itemCount: 6,
      padding: ThemeSkeleton.shared.insetsSymmetric(
        horizontal: 16,
        vertical: 8,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Container(
          margin: ThemeSkeleton.shared.insetsSymmetric(vertical: 6),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.5),
            borderRadius: ThemeSkeleton.shared.circular(24),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!PerformanceConfig.of(context).dataSaver)
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: ThemeSkeleton.shared.circular(24),
                  ),
                ),
              Padding(
                padding: ThemeSkeleton.shared.insetsSymmetric(
                  horizontal: 12.0,
                  vertical: 10.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      margin: ThemeSkeleton.shared.insetsOnly(bottom: 4),
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: ThemeSkeleton.shared.circular(4),
                      ),
                    ),
                    Container(
                      height: 16,
                      width: 250,
                      margin: ThemeSkeleton.shared.insetsOnly(bottom: 12),
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: ThemeSkeleton.shared.circular(4),
                      ),
                    ),
                    Container(
                      height: 12,
                      margin: ThemeSkeleton.shared.insetsOnly(bottom: 4),
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: ThemeSkeleton.shared.circular(4),
                      ),
                    ),
                    Container(
                      height: 12,
                      width: 180,
                      margin: ThemeSkeleton.shared.insetsOnly(bottom: 12),
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: ThemeSkeleton.shared.circular(4),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          height: 20, width: 20,
                          decoration: BoxDecoration(color: baseColor, borderRadius: ThemeSkeleton.shared.circular(6)),
                        ),
                        const SizedBox(width: ThemeSkeleton.size8),
                        Container(
                          height: 12, width: 80,
                          decoration: BoxDecoration(color: baseColor, borderRadius: ThemeSkeleton.shared.circular(4)),
                        ),
                        const Spacer(),
                        Container(
                          height: 24, width: 24,
                          decoration: BoxDecoration(color: baseColor, borderRadius: ThemeSkeleton.shared.circular(8)),
                        ),
                        const SizedBox(width: ThemeSkeleton.size6),
                        Container(
                          height: 24, width: 24,
                          decoration: BoxDecoration(color: baseColor, borderRadius: ThemeSkeleton.shared.circular(8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    final shouldAnimate = !PerformanceConfig.of(context).reduceEffects &&
        !PerformanceConfig.of(context).lowPowerMode &&
        !PerformanceConfig.of(context).isLowEndDevice;

    if (!shouldAnimate) return listView;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1500),
      child: listView,
    );
  }
}
