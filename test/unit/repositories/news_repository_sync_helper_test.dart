import 'package:bdnewsreader/domain/entities/news_article.dart';
import 'package:bdnewsreader/infrastructure/repositories/news/news_repository_sync_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NewsArticle article({
    required String title,
    required String description,
    String category = 'latest',
  }) {
    return NewsArticle(
      title: title,
      description: description,
      url: 'https://example.com/article',
      source: 'Example Source',
      publishedAt: DateTime(2026, 3, 25),
      category: category,
    );
  }

  group('NewsRepositorySyncHelper', () {
    test('sanitizes canonical tags and keeps topic tax internal only once', () {
      final tags = NewsRepositorySyncHelper.resolveCanonicalTags(
        article: article(
          title: 'Dhaka revenue update',
          description: 'National board issued new circular.',
        ),
        matchedTags: const <String>[
          'country:bangladesh',
          'district:dhaka',
          'topic:tax',
          'topic:income-tax',
          'format:breaking',
        ],
        sourceCategory: 'latest',
        primaryCategory: 'national',
      );

      expect(tags, contains('district:dhaka'));
      expect(tags.where((tag) => tag.contains('tax')).length, 1);
      expect(tags.any((tag) => tag.startsWith('format:')), isFalse);
      expect(tags.contains('country:bangladesh'), isFalse);
    });

    test(
      'keeps Bangladesh-heavy stories as national despite weak international hints',
      () {
        final resolved = NewsRepositorySyncHelper.resolveCanonicalCategory(
          article: article(
            title: 'Dhaka ministry holds bilateral briefing',
            description:
                'Bangladesh government discussed local rollout after the meeting.',
          ),
          classifiedCategory: 'international',
          matchedTags: const <String>[
            'international:generic',
            'country:bangladesh',
          ],
          sourceCategory: 'international',
        );

        expect(resolved, 'national');
      },
    );

    test('allows international when foreign context strongly dominates', () {
      final resolved = NewsRepositorySyncHelper.resolveCanonicalCategory(
        article: article(
          title: 'UN Security Council in New York votes on Gaza resolution',
          description:
              'United Nations diplomats and White House officials led negotiations.',
        ),
        classifiedCategory: 'international',
        matchedTags: const <String>[
          'international:security-council',
          'international:new-york',
        ],
        sourceCategory: 'international',
      );

      expect(resolved, 'international');
    });
  });
}
