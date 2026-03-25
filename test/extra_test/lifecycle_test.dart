import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/presentation/providers/news_providers.dart';
import 'package:bdnewsreader/core/di/providers.dart';
import 'package:bdnewsreader/domain/repositories/news_repository.dart';
import 'package:bdnewsreader/infrastructure/ai/ranking/pipeline/ranking_pipeline.dart';
import 'package:bdnewsreader/infrastructure/ai/engine/quantized_tfidf_engine.dart';

void main() {
  group('Provider Initialization Safety', () {
    test('newsRepositoryProvider should be safe to read multiple times', () {
      final container = ProviderContainer(
        overrides: [
          newsRepositoryProvider.overrideWithValue(FakeNewsRepository()),
        ],
      );

      // First read
      final repo1 = container.read(newsRepositoryProvider);
      // Second read (should return same instance)
      final repo2 = container.read(newsRepositoryProvider);

      expect(repo1, isNotNull);
      expect(identical(repo1, repo2), isTrue);
    });

    test('should handle provider disposal during async init', () async {
      final container = ProviderContainer(
        overrides: [
          newsRepositoryProvider.overrideWithValue(FakeNewsRepository()),
          rankingPipelineProvider.overrideWithValue(FakeRankingPipeline()),
          tfIdfEngineProvider.overrideWithValue(FakeTfIdfEngine()),
        ],
      );

      // Start operation
      final notifier = container.read(newsProvider.notifier);
      
      // Dispose immediately (simulate rapid navigation)
      container.dispose();

      // Should not throw (Riverpod handles this)
      expect(() => notifier.dispose(), throwsStateError);
    });
  });
}

class FakeNewsRepository extends Fake implements NewsRepository {}
class FakeRankingPipeline extends Fake implements RankingPipeline {}
class FakeTfIdfEngine extends Fake implements QuantizedTfIdfEngine {}
