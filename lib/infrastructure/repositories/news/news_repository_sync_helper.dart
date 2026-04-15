// ignore_for_file: avoid_classes_with_only_static_members

import '../../../domain/entities/news_article.dart';
import '../../../core/utils/url_identity.dart';
import '../../services/ml/categorization_helper.dart';

class NewsRepositorySyncHelper {
  static const Set<String> homeFeedCategories = {
    'home',
    'latest',
    'general',
    'all',
    'mixed',
  };

  static const List<String> allIngestCategories = <String>[
    'latest',
    'national',
    'international',
    'magazine',
    'sports',
    'entertainment',
    'technology',
    'economy',
    'trending',
  ];

  static const Set<String> apiIngestCategories = <String>{
    'latest',
    'national',
    'international',
    'sports',
    'entertainment',
    'technology',
    'economy',
    'trending',
  };

  static const Set<String> strictHomeCategories = <String>{
    'national',
    'international',
    'sports',
    'entertainment',
  };

  static const int maxAllCategorySyncArticles = 260;
  static const int maxScopedSyncArticles = 140;

  static const Map<String, int> feedCategoryPriority = <String, int>{
    'sports': 4,
    'entertainment': 4,
    'national': 4,
    'international': 4,
    'technology': 3,
    'economy': 3,
    'latest': 2,
    'magazine': 2,
    'home': 1,
    'general': 1,
    'all': 1,
    'mixed': 1,
  };

  static const Set<String> _hiddenTagPrefixes = <String>{'format'};

  static const Set<String> _hiddenSemanticTags = <String>{'tax'};

  static const Map<String, String> _semanticAliases = <String, String>{
    'bangla': 'bangladesh',
    'bd': 'bangladesh',
    'world': 'international',
    'global': 'international',
    'world affairs': 'international',
    'sport': 'sports',
    'showbiz': 'entertainment',
    'taxes': 'tax',
    'income tax': 'tax',
    'vat': 'tax',
  };

  static String articleIdentityKey(String rawUrl) =>
      UrlIdentity.canonicalize(rawUrl);
  static String articleIdFromUrl(String rawUrl) =>
      UrlIdentity.idFromUrl(rawUrl);

  static String resolveSyncCategory(String? category) {
    if (category == null || category == 'all') return 'latest';
    if (category == 'home' || category == 'general' || category == 'mixed') {
      return 'latest';
    }
    return category;
  }

  static String preferSourceCategory(String? current, String incoming) {
    if (current == null || current.isEmpty) return incoming;
    final currentScore = feedCategoryPriority[current] ?? 0;
    final incomingScore = feedCategoryPriority[incoming] ?? 0;
    return incomingScore > currentScore ? incoming : current;
  }

  static String resolveCanonicalCategory({
    required NewsArticle article,
    required String classifiedCategory,
    required List<String> matchedTags,
    required String sourceCategory,
  }) {
    final normalizedCategory = classifiedCategory.trim().toLowerCase();
    final normalizedSourceCategory = sourceCategory.trim().toLowerCase();
    final normalizedTags = matchedTags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet();

    final hasSportsTag = normalizedTags.any((tag) => tag.startsWith('sports:'));
    final hasEntertainmentTag = normalizedTags.any(
      (tag) => tag.startsWith('entertainment:'),
    );
    final hasBangladeshTag = normalizedTags.any(
      (tag) =>
          tag == 'country:bangladesh' ||
          tag.startsWith('division:') ||
          tag.startsWith('district:') ||
          tag.startsWith('organization:'),
    );

    final hasSportsSignal =
        hasSportsTag ||
        CategorizationHelper.hasStrongSportsEvidence(
          title: article.title,
          description: article.description,
          content: article.fullContent,
        );
    final hasEntertainmentSignal =
        hasEntertainmentTag ||
        CategorizationHelper.hasHardEntertainmentEvidence(
          title: article.title,
          description: article.description,
          content: article.fullContent,
        );

    final hasBangladeshSignal =
        hasBangladeshTag ||
        CategorizationHelper.isBangladeshCentric(
          title: article.title,
          description: article.description,
          content: article.fullContent,
        ) ||
        CategorizationHelper.hasNationalSoftKeywords(
          title: article.title,
          description: article.description,
          content: article.fullContent,
        );

    final hasInternationalSignal =
        normalizedTags.any((tag) => tag.startsWith('international:')) ||
        CategorizationHelper.hasInternationalKeywords(
          title: article.title,
          description: article.description,
          content: article.fullContent,
        ) ||
        CategorizationHelper.hasInternationalSoftKeywords(
          title: article.title,
          description: article.description,
          content: article.fullContent,
        );
    final hasInternationalDominance =
        CategorizationHelper.hasInternationalDominance(
          title: article.title,
          description: article.description,
          content: article.fullContent,
        );

    if (hasSportsSignal &&
        !hasEntertainmentSignal &&
        !hasInternationalSignal &&
        !hasBangladeshSignal) {
      return 'sports';
    }
    if (hasEntertainmentSignal &&
        !hasSportsSignal &&
        (!hasBangladeshSignal ||
            normalizedCategory == 'entertainment' ||
            normalizedSourceCategory == 'entertainment')) {
      return 'entertainment';
    }

    if (hasBangladeshSignal) {
      if (hasInternationalSignal && hasInternationalDominance) {
        return 'international';
      }
      return 'national';
    }
    if (hasInternationalSignal) return 'international';

    if (normalizedSourceCategory == 'national') return 'national';
    if (normalizedSourceCategory == 'international') {
      return hasBangladeshSignal && !hasInternationalDominance
          ? 'national'
          : 'international';
    }
    if (normalizedSourceCategory == 'sports') return 'sports';
    if (normalizedSourceCategory == 'entertainment' && hasEntertainmentSignal) {
      return 'entertainment';
    }

    if (normalizedCategory != 'latest' && normalizedCategory.isNotEmpty) {
      if (normalizedCategory == 'entertainment' && !hasEntertainmentSignal) {
        return 'national';
      }
      return CategorizationHelper.validateAndFixCategory(
        detectedCategory: normalizedCategory,
        title: article.title,
        description: article.description,
      );
    }

    if (article.language == 'bn') return 'national';
    return 'international';
  }

  static List<String> resolveCanonicalTags({
    required NewsArticle article,
    required List<String> matchedTags,
    required String sourceCategory,
    required String primaryCategory,
  }) {
    final tags = matchedTags.toSet();
    final text = '${article.title} ${article.description}'.toLowerCase();

    // Trending keywords (Bengali)
    if (text.contains('ভাইরাল') ||
        text.contains('জনপ্রিয়') ||
        text.contains('ট্রেন্ডিং') ||
        text.contains('আলোচিত') ||
        text.contains('ভাইরাল ভিডিও') ||
        sourceCategory == 'trending') {
      tags.add('trending');
    }

    // Trending keywords (English)
    if (text.contains('trending') ||
        text.contains('viral') ||
        text.contains('popular') ||
        text.contains('breaking') ||
        text.contains('trending now')) {
      tags.add('trending');
    }

    return _sanitizeCanonicalTags(
      tags.toList(),
      primaryCategory: primaryCategory,
    );
  }

  static List<String> _sanitizeCanonicalTags(
    List<String> rawTags, {
    required String primaryCategory,
  }) {
    final output = <String>[];
    final seenSemantic = <String>{};
    final normalizedPrimary = primaryCategory.trim().toLowerCase();

    for (final raw in rawTags) {
      final normalized = raw.trim().toLowerCase();
      if (normalized.isEmpty || normalized == 'premium') continue;

      final (prefix, value) = _splitTag(normalized);
      if (_hiddenTagPrefixes.contains(prefix)) continue;
      if (value.isEmpty) continue;

      final semantic = _canonicalSemantic(value);
      if (semantic.isEmpty) continue;
      if (_hiddenSemanticTags.contains(semantic) && prefix != 'topic') continue;
      if (_isCategoryEquivalentSemantic(semantic, normalizedPrimary)) continue;
      if (!seenSemantic.add(semantic)) continue;

      if (prefix.isEmpty) {
        output.add(semantic);
      } else {
        output.add('$prefix:$semantic');
      }
      if (output.length >= 10) break;
    }

    return output;
  }

  static (String prefix, String value) _splitTag(String normalizedTag) {
    if (!normalizedTag.contains(':')) return ('', normalizedTag);
    final parts = normalizedTag.split(':');
    final prefix = parts.first.trim();
    final value = parts.sublist(1).join(':').trim();
    return (prefix, value);
  }

  static String _canonicalSemantic(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return '';
    return _semanticAliases[normalized] ?? normalized;
  }

  static bool _isCategoryEquivalentSemantic(
    String semantic,
    String primaryCategory,
  ) {
    switch (primaryCategory) {
      case 'national':
        return semantic == 'national' ||
            semantic == 'bangladesh' ||
            semantic == 'country bangladesh';
      case 'international':
        return semantic == 'international' ||
            semantic == 'world' ||
            semantic == 'world affairs' ||
            semantic == 'global';
      case 'sports':
        return semantic == 'sports' || semantic == 'sport';
      case 'entertainment':
        return semantic == 'entertainment' || semantic == 'showbiz';
      default:
        return false;
    }
  }

  static bool matchesStrictCategory(NewsArticle article, String category) {
    final normalizedCategory = category.toLowerCase();

    if (normalizedCategory == 'latest') {
      return true;
    } else if (normalizedCategory == 'trending') {
      // Trending is differentiated at the DB query level (limit 30)
      return true;
    }

    if (article.category.trim().toLowerCase() != normalizedCategory) {
      return false;
    }

    // Additional strict validation for noisy categories
    if (normalizedCategory == 'sports') {
      return CategorizationHelper.hasStrongSportsEvidence(
            title: article.title,
            description: article.description,
            content: article.fullContent,
          ) ||
          (article.tags?.any((t) => t.startsWith('sports:')) ?? false);
    }

    if (normalizedCategory == 'entertainment') {
      return CategorizationHelper.hasHardEntertainmentEvidence(
            title: article.title,
            description: article.description,
            content: article.fullContent,
          ) ||
          (article.tags?.any((t) => t.startsWith('entertainment:')) ?? false);
    }

    return true;
  }
}
