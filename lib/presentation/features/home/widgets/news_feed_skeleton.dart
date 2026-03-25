import 'package:flutter/material.dart';
import '../../../../core/config/performance_config.dart' show PerformanceConfig;
import 'shimmer_loading.dart';

class NewsFeedSkeleton extends StatelessWidget {
  const NewsFeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!PerformanceConfig.of(context).dataSaver)
                const ShimmerLoading(
                  height: 100,
                  borderRadius: 24,
                  margin: EdgeInsets.zero,
                ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerLoading(
                      height: 16,
                      borderRadius: 4,
                      margin: EdgeInsets.only(bottom: 4),
                    ),
                    ShimmerLoading(
                      height: 16,
                      width: 250,
                      borderRadius: 4,
                      margin: EdgeInsets.only(bottom: 12),
                    ),
                    ShimmerLoading(
                      height: 12,
                      borderRadius: 4,
                      margin: EdgeInsets.only(bottom: 4),
                    ),
                    ShimmerLoading(
                      height: 12,
                      width: 180,
                      borderRadius: 4,
                      margin: EdgeInsets.only(bottom: 12),
                    ),
                    Row(
                      children: [
                        ShimmerLoading(
                          height: 20,
                          width: 20,
                          borderRadius: 6,
                        ),
                        SizedBox(width: 8),
                        ShimmerLoading(
                          height: 12,
                          width: 80,
                          borderRadius: 4,
                        ),
                        Spacer(),
                        ShimmerLoading(
                          height: 24,
                          width: 24,
                          borderRadius: 8,
                        ),
                        SizedBox(width: 6),
                        ShimmerLoading(
                          height: 24,
                          width: 24,
                          borderRadius: 8,
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
  }
}
