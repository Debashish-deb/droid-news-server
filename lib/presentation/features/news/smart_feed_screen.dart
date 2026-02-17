import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/feature_providers.dart';
import 'widgets/smart_feed_view.dart';
import '../../../l10n/generated/app_localizations.dart';

class SmartFeedScreen extends ConsumerWidget {

  const SmartFeedScreen({required this.category, super.key});
  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureFlagService = ref.watch(featureFlagServiceProvider);
    final isThreadingEnabled = featureFlagService.remoteConfig.getBool('enable_news_threading');

    if (isThreadingEnabled) {
      return SmartFeedView(category: category);
    } else {
      // The provided snippet for AppLocalizations.of(context).noUrlAvailable and restartApp
      // seems to be for a different part of the code or a future addition.
      // For now, I will only apply the change to the existing classicFeedLabel usage.
      return Center(
        child: Text(AppLocalizations.of(context).classicFeedLabel),
      );
    }
  }
}
