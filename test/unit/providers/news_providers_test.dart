import 'dart:async';
import 'dart:ui';

import 'package:bdnewsreader/application/ai/ranking/user_interest_service.dart';
import 'package:bdnewsreader/core/architecture/either.dart';
import 'package:bdnewsreader/core/architecture/failure.dart';
import 'package:bdnewsreader/domain/entities/news_article.dart';
import 'package:bdnewsreader/domain/repositories/news_repository.dart';
import 'package:bdnewsreader/infrastructure/ai/engine/quantized_tfidf_engine.dart';
import 'package:bdnewsreader/infrastructure/ai/ranking/pipeline/ranking_pipeline.dart';
import 'package:bdnewsreader/presentation/providers/news_providers.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingWatchRepository implements NewsRepository {
  @override
  Future<Either<AppFailure, void>> bookmarkArticle(String articleId) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<AppFailure, List<NewsArticle>>> getArticlesByCategory(
    String category, {
    int page = 1,
    int limit = 20,
    String? language,
  }) async {
    return const Right(<NewsArticle>[]);
  }

  @override
  Future<Either<AppFailure, NewsArticle>> getArticleById(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<AppFailure, List<NewsArticle>>> getBookmarkedArticles() async {
    throw UnimplementedError();
  }

  @override
  Future<Either<AppFailure, List<NewsArticle>>> getNewsFeed({
    required int page,
    required int limit,
    String? category,
    String? language,
  }) async {
    return const Right(<NewsArticle>[]);
  }

  @override
  Future<Either<AppFailure, void>> markAsRead(String articleId) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<AppFailure, List<NewsArticle>>> searchArticles({
    required String query,
    int limit = 20,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<AppFailure, void>> shareArticle(String articleId) async {
    throw UnimplementedError();
  }

  @override
  Future<Either<AppFailure, int>> syncNews({
    required Locale locale,
    bool force = false,
    String? category,
  }) async {
    return const Right(0);
  }

  @override
  Future<Either<AppFailure, void>> unbookmarkArticle(String articleId) async {
    throw UnimplementedError();
  }

  @override
  Stream<List<NewsArticle>> watchArticles(String category, Locale locale) {
    throw StateError('watch failed');
  }
}

class _PassthroughRankingPipeline extends RankingPipeline {
  _PassthroughRankingPipeline(NewsRepository repository)
    : super(repository, UserInterestService.disabled(QuantizedTfIdfEngine()));

  @override
  Future<List<NewsArticle>> rank(
    List<NewsArticle> articles, {
    bool prioritizeBangladesh = false,
  }) async {
    return articles;
  }
}

class _LocaleSwitchRaceRepository extends _ThrowingWatchRepository {
  final Completer<void> enSyncCompleter = Completer<void>();
  final Completer<void> bnSyncCompleter = Completer<void>();
  final List<String> syncLocales = <String>[];
  final Map<String, StreamController<List<NewsArticle>>> _controllers =
      <String, StreamController<List<NewsArticle>>>{};

  StreamController<List<NewsArticle>> _controllerFor(String key) {
    return _controllers.putIfAbsent(
      key,
      () => StreamController<List<NewsArticle>>.broadcast(),
    );
  }

  @override
  Future<Either<AppFailure, int>> syncNews({
    required Locale locale,
    bool force = false,
    String? category,
  }) async {
    final categoryKey = category ?? 'all';
    final syncKey = '$categoryKey:${locale.languageCode}';
    syncLocales.add(syncKey);

    if (locale.languageCode == 'en') {
      await enSyncCompleter.future;
      _controllerFor(syncKey).add(<NewsArticle>[
        NewsArticle(
          title: 'English latest',
          url: 'https://example.com/en-latest',
          source: 'Example EN',
          publishedAt: DateTime.parse('2026-03-29T12:00:00Z'),
          category: categoryKey,
        ),
      ]);
    } else if (locale.languageCode == 'bn') {
      await bnSyncCompleter.future;
      _controllerFor(syncKey).add(<NewsArticle>[
        NewsArticle(
          title: 'Bangla latest',
          url: 'https://example.com/bn-latest',
          source: 'Example BN',
          publishedAt: DateTime.parse('2026-03-29T12:01:00Z'),
          language: 'bn',
          category: categoryKey,
        ),
      ]);
    } else {
      _controllerFor(syncKey).add(const <NewsArticle>[]);
    }

    return const Right(1);
  }

  @override
  Stream<List<NewsArticle>> watchArticles(String category, Locale locale) {
    return _controllerFor('$category:${locale.languageCode}').stream;
  }

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
  }
}

void main() {
  test(
    'loadNews degrades to a category error when stream setup throws synchronously',
    () async {
      final repository = _ThrowingWatchRepository();
      final notifier = NewsNotifier(
        newsRepository: repository,
        rankingPipeline: _PassthroughRankingPipeline(repository),
        tfIdfEngine: QuantizedTfIdfEngine(),
      );

      await notifier.loadNews('latest', const Locale('en'));

      expect(
        notifier.state.getError('latest'),
        'Unable to load news right now.',
      );
      expect(notifier.state.isLoading('latest'), isFalse);

      notifier.dispose();
    },
  );

  test(
    'locale change starts a fresh latest sync immediately and does not wait for the old locale to finish',
    () async {
      final repository = _LocaleSwitchRaceRepository();
      final notifier = NewsNotifier(
        newsRepository: repository,
        rankingPipeline: _PassthroughRankingPipeline(repository),
        tfIdfEngine: QuantizedTfIdfEngine(),
      );

      await notifier.loadNews('latest', const Locale('en'));
      await pumpEventQueue();

      await notifier.loadNews('latest', const Locale('bn'), force: true);
      await pumpEventQueue();

      expect(repository.syncLocales, <String>['latest:en', 'latest:bn']);
      expect(notifier.state.isLoading('latest'), isTrue);

      repository.bnSyncCompleter.complete();
      await pumpEventQueue();

      expect(notifier.state.getArticles('latest'), hasLength(1));
      expect(notifier.state.getArticles('latest').single.language, 'bn');
      expect(notifier.state.isLoading('latest'), isFalse);

      repository.enSyncCompleter.complete();
      await pumpEventQueue();

      expect(notifier.state.getArticles('latest'), hasLength(1));
      expect(notifier.state.getArticles('latest').single.language, 'bn');
      expect(notifier.state.isLoading('latest'), isFalse);

      notifier.dispose();
      await repository.dispose();
    },
  );
}
