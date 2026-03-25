import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/smart_feed_provider.dart';
import '../../home/widgets/news_card.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_paths.dart' show AppPaths;
import '../../../../l10n/generated/app_localizations.dart'
    show AppLocalizations;
import '../../common/news_detail_args.dart';
// import 'package:bdnewsreader/application/ai/ranking/user_interest_service.dart';

class SmartFeedView extends ConsumerWidget {
  const SmartFeedView({required this.category, super.key});
  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(smartFeedProvider);
    final articles = state.articles;

    if (state.isPersonalizing && articles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (articles.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context).noPersonalizedNews),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        return Future.value();
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 16),
        itemCount: articles.length,
        cacheExtent: 1500, // Pre-render cards for smoother scrolling
        addRepaintBoundaries: false, // NewsCard already has a RepaintBoundary
        itemBuilder: (context, index) {
          final article = articles[index];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: NewsCard(
              article: article,
              onTap: () {
                context.push(
                  AppPaths.newsDetail,
                  extra: NewsDetailArgs(
                    article: article,
                    articles: articles,
                    initialIndex: index,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
