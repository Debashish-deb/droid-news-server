import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../bootstrap/config/feature_flags/feature_flag_service.dart';
import '../../../bootstrap/config/feature_flags/app_features.dart';
import '../../../bootstrap/di/injection_container.dart';
import 'widgets/smart_feed_view.dart';
// Import your existing Classic Feed widget here. 
// Assuming it exists as 'NewsFeed' or similar in features/home/widgets/news_list.dart
// Since I can't see the file structure perfectly for the classic feed, I will assume a placeholder or standard list.

class SmartFeedScreen extends ConsumerWidget {

  const SmartFeedScreen({required this.category, super.key});
  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureFlagService = sl<IFeatureFlagService>();
    final isThreadingEnabled = featureFlagService.isEnabled(AppFeatures.enable_news_threading);

    if (isThreadingEnabled) {
      return SmartFeedView(category: category);
    } else {
      return const Center(
        child: Text('Classic Feed (Feature Flag OFF)\nEnable "news_threading" to see Smart UI'),
      );
    }
  }
}
