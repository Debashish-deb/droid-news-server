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

  static String articleIdentityKey(String rawUrl) => UrlIdentity.canonicalize(rawUrl);
  static String articleIdFromUrl(String rawUrl) => UrlIdentity.idFromUrl(rawUrl);

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
    final normalizedTags = matchedTags.map((tag) => tag.trim().toLowerCase()).where((tag) => tag.isNotEmpty).toSet();

    final hasSportsTag = normalizedTags.any((tag) => tag.startsWith('sports:'));
    final hasEntertainmentTag = normalizedTags.any((tag) => tag.startsWith('entertainment:'));
    final hasBangladeshTag = normalizedTags.any((tag) =>
      tag == 'country:bangladesh' ||
      tag.startsWith('division:') ||
      tag.startsWith('district:') ||
      tag.startsWith('organization:'));

    final hasSportsSignal = hasSportsTag || CategorizationHelper.hasStrongSportsEvidence(title: article.title, description: article.description, content: article.fullContent);
    final hasEntertainmentSignal = hasEntertainmentTag || CategorizationHelper.hasEntertainmentKeywords(title: article.title, description: article.description, content: article.fullContent);

    final hasBangladeshSignal = hasBangladeshTag ||
      CategorizationHelper.isBangladeshCentric(title: article.title, description: article.description, content: article.fullContent) ||
      CategorizationHelper.hasNationalSoftKeywords(title: article.title, description: article.description, content: article.fullContent);
    
    final hasInternationalSignal = normalizedTags.any((tag) => tag.startsWith('international:')) ||
      CategorizationHelper.hasInternationalKeywords(title: article.title, description: article.description, content: article.fullContent) ||
      CategorizationHelper.hasInternationalSoftKeywords(title: article.title, description: article.description, content: article.fullContent);

    if (hasSportsTag && !hasEntertainmentTag && !hasInternationalSignal && !hasBangladeshSignal) return 'sports';
    if (hasEntertainmentTag && !hasSportsTag) return 'entertainment';

    if (hasSportsSignal && normalizedCategory == 'sports' && !hasInternationalSignal) return 'sports';
    if (hasEntertainmentSignal && normalizedCategory == 'entertainment') return 'entertainment';
    if (hasBangladeshSignal && (normalizedCategory == 'national' || normalizedCategory == 'international')) {
      return normalizedCategory == 'international' ? 'international' : 'national';
    }

    if (hasSportsSignal && !hasEntertainmentSignal && !hasBangladeshSignal && !hasInternationalSignal) return 'sports';
    if (hasEntertainmentSignal && !hasSportsSignal && !hasBangladeshSignal) return 'entertainment';
    if (hasBangladeshSignal) return 'national';

    if (normalizedSourceCategory == 'national') return 'national';
    if (normalizedSourceCategory == 'international') return 'international';
    if (normalizedSourceCategory == 'sports') return 'sports';
    if (normalizedSourceCategory == 'entertainment') return 'entertainment';

    if (normalizedCategory != 'latest' && normalizedCategory.isNotEmpty) {
      return CategorizationHelper.validateAndFixCategory(detectedCategory: normalizedCategory, title: article.title, description: article.description);
    }

    if (article.language == 'bn') return 'national';
    return 'international';
  }

  static List<String> resolveCanonicalTags({
    required NewsArticle article,
    required List<String> matchedTags,
    required String sourceCategory,
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

    return tags.toList();
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
      return CategorizationHelper.hasEntertainmentKeywords(
            title: article.title,
            description: article.description,
            content: article.fullContent,
          ) ||
          (article.tags?.any((t) => t.startsWith('entertainment:')) ?? false);
    }

    return true;
  }
}
