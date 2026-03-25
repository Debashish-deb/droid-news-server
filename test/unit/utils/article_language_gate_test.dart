import 'package:bdnewsreader/core/utils/article_language_gate.dart';
import 'package:bdnewsreader/domain/entities/news_article.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArticleLanguageGate', () {
    test('rejects English content for Bangla requests', () {
      final article = NewsArticle(
        title: 'Global markets rally after policy shift',
        description: 'Analysts expect further upside this quarter.',
        url: 'https://example.com/en-1',
        source: 'Example',
        publishedAt: DateTime(2026, 3, 6),
      );

      final result = ArticleLanguageGate.evaluate(
        article: article,
        requestedLanguage: 'bn',
      );

      expect(result.accepted, isFalse);
      expect(result.reasonCode, ArticleLanguageGate.reasonNonBanglaContent);
    });

    test('accepts Bangla content for Bangla requests', () {
      final article = NewsArticle(
        title: 'বাংলাদেশে নতুন নীতিমালা ঘোষণা',
        description: 'ঢাকায় সংবাদ সম্মেলনে এই সিদ্ধান্ত জানানো হয়।',
        url: 'https://example.com/bn-1',
        source: 'Example',
        publishedAt: DateTime(2026, 3, 6),
        language: 'bn',
      );

      final result = ArticleLanguageGate.evaluate(
        article: article,
        requestedLanguage: 'bn',
      );

      expect(result.accepted, isTrue);
      expect(result.detectedLanguage, 'bn');
      expect(result.reasonCode, ArticleLanguageGate.reasonAccepted);
    });

    test('keeps English requests permissive', () {
      final article = NewsArticle(
        title: 'International summit opens in Brussels',
        description: 'Leaders gather to discuss regional security.',
        url: 'https://example.com/en-2',
        source: 'Example',
        publishedAt: DateTime(2026, 3, 6),
      );

      final result = ArticleLanguageGate.evaluate(
        article: article,
        requestedLanguage: 'en',
      );

      expect(result.accepted, isTrue);
      expect(result.reasonCode, ArticleLanguageGate.reasonAccepted);
    });
  });
}
