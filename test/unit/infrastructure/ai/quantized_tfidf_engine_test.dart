import 'package:bdnewsreader/domain/entities/news_article.dart';
import 'package:bdnewsreader/infrastructure/ai/engine/quantized_tfidf_engine.dart';
import 'package:flutter_test/flutter_test.dart';

NewsArticle _article(String id, String title, String description) {
  return NewsArticle(
    title: title,
    description: description,
    url: 'https://example.com/$id',
    source: 'Example',
    publishedAt: DateTime.parse('2026-03-31T00:00:00Z'),
  );
}

void main() {
  test('returns the cached vector for repeated requests', () {
    final engine = QuantizedTfIdfEngine(maxVectorCacheEntries: 2);
    final article = _article('one', 'Economy outlook', 'Markets rally today');
    final vocabulary = engine.extractVocabulary([article]);

    final first = engine.generateVector(article, vocabulary);
    final second = engine.generateVector(article, vocabulary);

    expect(identical(first, second), isTrue);
  });

  test('evicts the least recently used vector when the cache is full', () {
    final engine = QuantizedTfIdfEngine(maxVectorCacheEntries: 1);
    final articleA = _article('a', 'Politics update', 'Election reform debate');
    final articleB = _article('b', 'Sports bulletin', 'Cricket team wins');
    final vocabulary = engine.extractVocabulary([articleA, articleB]);

    final firstA = engine.generateVector(articleA, vocabulary);
    engine.generateVector(articleB, vocabulary);
    final secondA = engine.generateVector(articleA, vocabulary);

    expect(identical(firstA, secondA), isFalse);
  });

  test('clears cached vectors when IDF state changes', () {
    final engine = QuantizedTfIdfEngine(maxVectorCacheEntries: 2);
    final articleA = _article(
      'a',
      'Energy prices rise',
      'Power market volatility',
    );
    final articleB = _article('b', 'Flood response', 'Emergency aid deployed');
    final vocabulary = engine.extractVocabulary([articleA, articleB]);

    final beforeUpdate = engine.generateVector(articleA, vocabulary);
    engine.updateIdfCache([articleA, articleB]);
    final afterUpdate = engine.generateVector(articleA, vocabulary);

    expect(identical(beforeUpdate, afterUpdate), isFalse);
  });
}
