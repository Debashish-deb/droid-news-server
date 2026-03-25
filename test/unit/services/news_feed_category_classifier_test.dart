import 'package:bdnewsreader/infrastructure/services/ml/categorization_helper.dart';
import 'package:bdnewsreader/infrastructure/services/ml/news_feed_category_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final taxonomy = FeedCategoryTaxonomy.fromMap(<String, dynamic>{
    'divisions': <Map<String, String>>[
      <String, String>{
        'id': 'dhaka-division',
        'en': 'Dhaka Division',
        'bn': 'ঢাকা বিভাগ',
      },
    ],
    'districts': <Map<String, String>>[
      <String, String>{'id': 'dhaka', 'en': 'Dhaka', 'bn': 'ঢাকা'},
      <String, String>{'id': 'barishal', 'en': 'Barishal', 'bn': 'বরিশাল'},
    ],
    'organizations': <Map<String, String>>[
      <String, String>{
        'id': 'bangladesh-bank',
        'en': 'Bangladesh Bank',
        'bn': 'বাংলাদেশ ব্যাংক',
      },
    ],
    'international_entities': <Map<String, String>>[
      <String, String>{
        'id': 'united-nations',
        'en': 'United Nations',
        'bn': 'জাতিসংঘ',
      },
      <String, String>{
        'id': 'security-council',
        'en': 'UN Security Council',
        'bn': 'নিরাপত্তা পরিষদ',
      },
    ],
    'international_locations': <Map<String, String>>[
      <String, String>{'id': 'new-york', 'en': 'New York', 'bn': 'নিউ ইয়র্ক'},
      <String, String>{'id': 'london', 'en': 'London', 'bn': 'লন্ডন'},
    ],
    'sports': <Map<String, String>>[
      <String, String>{'id': 'cricket', 'en': 'Cricket', 'bn': 'ক্রিকেট'},
      <String, String>{'id': 'world-cup', 'en': 'World Cup', 'bn': 'বিশ্বকাপ'},
    ],
    'entertainment': <Map<String, String>>[
      <String, String>{'id': 'film', 'en': 'Film', 'bn': 'চলচ্চিত্র'},
      <String, String>{'id': 'celebrity', 'en': 'Celebrity', 'bn': 'তারকা'},
    ],
    'topics': <Map<String, String>>[
      <String, String>{'id': 'politics', 'en': 'Politics', 'bn': 'রাজনীতি'},
    ],
    'formats': <Map<String, String>>[
      <String, String>{
        'id': 'breaking',
        'en': 'Breaking News',
        'bn': 'ব্রেকিং নিউজ',
      },
    ],
  });

  TagDrivenCategorizationResult classify({
    required String title,
    required String description,
    String? content,
    String? feedCategory,
  }) {
    return NewsFeedCategoryClassifier.classifyWithTaxonomy(
      taxonomy: taxonomy,
      title: title,
      description: description,
      content: content,
      feedCategory: feedCategory,
      fallback: CategorizationHelper.categorizeByKeywords(
        title: title,
        description: description,
        content: content,
      ),
    );
  }

  group('NewsFeedCategoryClassifier', () {
    test('routes Bangladesh policy stories to national', () {
      final result = classify(
        title: 'Bangladesh Bank announces new policy in Dhaka',
        description: 'Politics and economy remain central to the decision.',
      );

      expect(result.category, 'national');
      expect(result.matchedTags, contains('organization:bangladesh-bank'));
      expect(result.matchedTags, contains('district:dhaka'));
    });

    test('routes Bangladesh sports stories to sports', () {
      final result = classify(
        title: 'Bangladesh win World Cup cricket thriller in Dhaka',
        description: 'The cricket final went down to the last over.',
      );

      expect(result.category, 'sports');
      expect(result.matchedTags, contains('sports:world-cup'));
    });

    test('routes entertainment stories to entertainment', () {
      final result = classify(
        title: 'Celebrity joins new film premiere in Dhaka',
        description: 'The star dominated entertainment headlines.',
      );

      expect(result.category, 'entertainment');
      expect(result.matchedTags, contains('entertainment:celebrity'));
    });

    test('treats non-Bangladesh general stories as international', () {
      final result = classify(
        title: 'European leaders meet over energy prices',
        description: 'A diplomacy-heavy summit continued in Brussels.',
      );

      expect(result.category, 'international');
    });

    test('uses international taxonomy entities as strong signal', () {
      final result = classify(
        title: 'UN Security Council meets in New York on ceasefire plan',
        description: 'United Nations officials are expected to vote tonight.',
      );

      expect(result.category, 'international');
      expect(result.matchedTags, contains('international:security-council'));
    });

    test('uses feed hint for low-signal stories', () {
      final result = classify(
        title: 'Live updates and latest developments',
        description: 'Follow the rolling coverage as events unfold.',
        feedCategory: 'sports',
      );

      expect(result.category, 'sports');
      expect(result.source, 'feed_hint');
    });

    test('keeps Bangladesh-linked diplomacy in national bucket', () {
      final result = classify(
        title: 'Bangladesh and India hold bilateral talks in Dhaka',
        description: 'Officials said Bangladesh priorities led the meeting.',
      );

      expect(result.category, 'national');
    });
  });
}
