import 'dart:convert';
import '../../../domain/entities/news_article.dart';
import '../../../platform/persistence/app_database.dart';

extension ArticleMapper on Article {
  NewsArticle toDomainEntity() {
    return NewsArticle(
      title: title,
      description: description,
      url: url,
      source: source,
      imageUrl: imageUrl,
      language: language,
      fullContent: content ?? '',
      publishedAt: publishedAt,
      category: category ?? 'general',
      tags: _decodeTags(tags),
      fromCache: true,
    );
  }

  static List<String>? _decodeTags(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded.whereType<String>().toList(growable: false);
    } catch (_) {
      return null;
    }
  }
}

extension NewsArticleMapper on NewsArticle {
  String? encodeTags(List<String> combinedTags) {
    if (combinedTags.isEmpty) return null;
    return jsonEncode(combinedTags);
  }

  List<String> mergeTags(List<String> matchedTags) {
    final merged = <String>{...matchedTags, ...?tags, 'latest'};
    if (url.hashCode % 5 == 0 || title.length > 80) {
      merged.add('trending');
    }
    final sorted = merged.toList()..sort();
    return sorted;
  }
}
