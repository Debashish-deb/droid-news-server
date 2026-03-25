import 'package:bdnewsreader/application/ai/ai_service.dart';
import 'package:bdnewsreader/presentation/features/search/providers/search_intelligence_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI latest/trending alignment', () {
    test('extractTrendingTopics favors recent latest/trending signals', () {
      final service = AIServiceImpl();
      final now = DateTime.now();

      final topics = service.extractTrendingTopics(<Map<String, String>>[
        <String, String>{
          'title': 'Delta outbreak hits city neighborhoods',
          'description': 'Hospitals report a fast rise in admissions.',
          'source': 'Source A',
          'url': 'https://example.com/a',
          'category': 'latest',
          'tags': '',
          'publishedAt': now
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        },
        <String, String>{
          'title': 'Delta outbreak spreads across nearby areas',
          'description': 'Officials call it a trending public health concern.',
          'source': 'Source B',
          'url': 'https://example.com/b',
          'category': 'trending',
          'tags': 'trending,health',
          'publishedAt': now
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
        },
        <String, String>{
          'title': 'Local council approves annual budget',
          'description': 'Infrastructure and schools are top priorities.',
          'source': 'Source C',
          'url': 'https://example.com/c',
          'category': 'national',
          'tags': '',
          'publishedAt': now
              .subtract(const Duration(days: 5))
              .toIso8601String(),
        },
      ]);

      expect(topics, isNotEmpty);
      expect(topics.first.label.toLowerCase(), contains('delta'));
    });

    test(
      'search intelligence suggestions include latest/trending defaults',
      () {
        final state = SearchIntelligenceState(
          suggestedQueries: const <String>[
            'latest',
            'trending',
            'latest news',
            'economy outlook',
          ],
        );

        expect(state.filterSuggestions('', limit: 2), const <String>[
          'latest',
          'trending',
        ]);
        expect(state.filterSuggestions('trend'), const <String>['trending']);
      },
    );
  });
}
