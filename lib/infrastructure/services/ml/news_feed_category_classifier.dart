import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'categorization_helper.dart';
import 'enhanced_ai_categorizer.dart';

class TagDrivenCategorizationResult {
  const TagDrivenCategorizationResult({
    required this.category,
    required this.confidence,
    required this.source,
    this.matchedTags = const <String>[],
    this.reason = '',
  });

  final String category;
  final double confidence;
  final String source;
  final List<String> matchedTags;
  final String reason;

  bool get isHighConfidence => confidence >= 0.7;
}

class NewsFeedCategoryClassifier {
  NewsFeedCategoryClassifier._();

  static final NewsFeedCategoryClassifier instance =
      NewsFeedCategoryClassifier._();
  static const String _taxonomyAssetPath = 'assets/new-feed-category.json';

  FeedCategoryTaxonomy? _taxonomyOverride;
  Future<FeedCategoryTaxonomy>? _taxonomyFuture;

  static const Set<String> _canonicalCategories = <String>{
    'national',
    'international',
    'sports',
    'entertainment',
  };
  static const double _aiAssistThreshold = 0.82;
  static const double _aiOverrideThreshold = 0.72;

  Future<TagDrivenCategorizationResult> classify({
    required String title,
    required String description,
    String? content,
    String language = 'en',
    String? articleId,
    String? feedCategory,
    bool collectAiSignals = true,
    void Function(Map<String, dynamic> insight)? onAiInsight,
  }) async {
    final fallback = await CategorizationHelper.categorizeSmartly(
      title: title,
      description: description,
      content: content,
      language: language,
      articleId: articleId,
      feedCategory: feedCategory,
      collectAiSignals: collectAiSignals,
      onAiInsight: onAiInsight,
    );

    final taxonomy = await _resolveTaxonomy();
    final refined = classifyWithTaxonomy(
      taxonomy: taxonomy,
      title: title,
      description: description,
      content: content,
      feedCategory: feedCategory,
      fallback: fallback,
    );

    var hybrid = TagDrivenCategorizationResult(
      category: refined.category,
      confidence: refined.confidence,
      source: refined.source,
      matchedTags: refined.matchedTags,
      reason: refined.reason,
    );

    if (_shouldUseAiAssist(hybrid)) {
      final aiCategory = await _classifyWithAi(
        title: title,
        description: description,
        content: content,
        language: language,
      );
      if (aiCategory != null) {
        hybrid = _mergeHybridDecision(
          local: hybrid,
          aiCategory: aiCategory,
          title: title,
          description: description,
          content: content,
        );
      }
    }

    return hybrid;
  }

  bool _shouldUseAiAssist(TagDrivenCategorizationResult result) {
    if (!_canonicalCategories.contains(result.category)) {
      return true;
    }
    if (result.confidence < _aiAssistThreshold) {
      return true;
    }
    return result.source.contains('feed_hint') ||
        result.source.contains('keyword');
  }

  Future<String?> _classifyWithAi({
    required String title,
    required String description,
    required String language,
    String? content,
  }) async {
    try {
      final aiRaw = await EnhancedAICategorizer.instance
          .categorizeArticle(
            title: title,
            description: description,
            content: content ?? '',
            language: language,
          )
          .timeout(const Duration(seconds: 4));
      return _normalizeAiCategory(aiRaw);
    } catch (_) {
      return null;
    }
  }

  String? _normalizeAiCategory(String raw) {
    final normalized = _normalize(raw);
    if (_canonicalCategories.contains(normalized)) {
      return normalized;
    }
    if (normalized.contains('inter')) return 'international';
    if (normalized.contains('sport')) return 'sports';
    if (normalized.contains('entertain')) return 'entertainment';
    if (normalized.contains('nation')) return 'national';
    return null;
  }

  TagDrivenCategorizationResult _mergeHybridDecision({
    required TagDrivenCategorizationResult local,
    required String aiCategory,
    required String title,
    required String description,
    String? content,
  }) {
    if (aiCategory == local.category) {
      return TagDrivenCategorizationResult(
        category: local.category,
        confidence: local.confidence < 0.9 ? 0.9 : local.confidence,
        source: '${local.source}+ai_confirmed',
        matchedTags: local.matchedTags,
        reason: '${local.reason} AI confirmed the same category.',
      );
    }

    final hasBangladesh = CategorizationHelper.isBangladeshCentric(
      title: title,
      description: description,
      content: content,
    );
    final hasInternational =
        CategorizationHelper.hasInternationalKeywords(
          title: title,
          description: description,
          content: content,
        ) ||
        CategorizationHelper.hasInternationalSoftKeywords(
          title: title,
          description: description,
          content: content,
        );
    final hasSports = CategorizationHelper.hasSportsKeywords(
      title: title,
      description: description,
      content: content,
    );
    final hasStrongSports = CategorizationHelper.hasStrongSportsEvidence(
      title: title,
      description: description,
      content: content,
    );
    final hasEntertainment = CategorizationHelper.hasEntertainmentKeywords(
      title: title,
      description: description,
      content: content,
    );

    if (aiCategory == 'international' && hasBangladesh && !hasInternational) {
      return local;
    }
    if (aiCategory == 'national' && hasInternational && !hasBangladesh) {
      return local;
    }
    if (aiCategory == 'sports' &&
        !hasStrongSports &&
        (!hasSports || local.confidence > 0.65)) {
      return local;
    }
    if (aiCategory == 'entertainment' &&
        !hasEntertainment &&
        local.confidence > 0.65) {
      return local;
    }

    if (local.confidence <= _aiOverrideThreshold ||
        local.source.contains('feed_hint')) {
      return TagDrivenCategorizationResult(
        category: aiCategory,
        confidence: 0.84,
        source: '${local.source}+ai_override',
        matchedTags: local.matchedTags,
        reason:
            'Local classification was low-confidence/heuristic; AI override applied.',
      );
    }

    return TagDrivenCategorizationResult(
      category: local.category,
      confidence: local.confidence,
      source: '${local.source}+ai_disagreed',
      matchedTags: local.matchedTags,
      reason:
          '${local.reason} AI disagreed but local signals remained stronger.',
    );
  }

  Future<FeedCategoryTaxonomy> _resolveTaxonomy() {
    final override = _taxonomyOverride;
    if (override != null) {
      return Future<FeedCategoryTaxonomy>.value(override);
    }

    return _taxonomyFuture ??= _loadTaxonomyFromAsset();
  }

  Future<FeedCategoryTaxonomy> _loadTaxonomyFromAsset() async {
    try {
      final raw = await rootBundle.loadString(_taxonomyAssetPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return FeedCategoryTaxonomy.fromMap(decoded);
      }
      if (decoded is Map) {
        return FeedCategoryTaxonomy.fromMap(Map<String, dynamic>.from(decoded));
      }
    } catch (e, stack) {
      debugPrint('Category taxonomy load failed: $e');
      debugPrintStack(stackTrace: stack);
    }

    return FeedCategoryTaxonomy.fromMap(const <String, dynamic>{});
  }

  @visibleForTesting
  static TagDrivenCategorizationResult classifyWithTaxonomy({
    required FeedCategoryTaxonomy taxonomy,
    required String title,
    required String description,
    required CategorizationResult fallback,
    String? content,
    String? feedCategory,
  }) {
    final text = _normalize('$title $description ${content ?? ''}');
    final matchedBangladeshTags = taxonomy.matchBangladeshTags(text);
    final matchedInternationalTags = taxonomy.matchInternationalTags(text);
    final matchedSportsTags = taxonomy.matchSportsTags(text);
    final matchedEntertainmentTags = taxonomy.matchEntertainmentTags(text);
    final matchedTopicTags = taxonomy.matchTopicTags(text);
    final matchedFormatTags = taxonomy.matchFormatTags(text);

    final matchedTags = <String>{
      ...matchedBangladeshTags,
      ...matchedInternationalTags,
      ...matchedSportsTags,
      ...matchedEntertainmentTags,
      ...matchedTopicTags,
      ...matchedFormatTags,
    }.toList()..sort();

    final normalizedFeedCategory = _normalize(feedCategory ?? '');
    final hasSportsKeyword = CategorizationHelper.hasSportsSoftKeywords(
      title: title,
      description: description,
      content: content,
    );
    final hasStrongSportsEvidence =
        CategorizationHelper.hasStrongSportsEvidence(
          title: title,
          description: description,
          content: content,
        );
    final hasEntertainmentKeyword =
        CategorizationHelper.hasEntertainmentSoftKeywords(
          title: title,
          description: description,
          content: content,
        );
    final hasBangladeshKeyword = CategorizationHelper.isBangladeshCentric(
      title: title,
      description: description,
      content: content,
    );
    final hasNationalKeyword = CategorizationHelper.hasNationalSoftKeywords(
      title: title,
      description: description,
      content: content,
    );
    final hasInternationalKeyword =
        CategorizationHelper.hasInternationalKeywords(
          title: title,
          description: description,
          content: content,
        ) ||
        CategorizationHelper.hasInternationalSoftKeywords(
          title: title,
          description: description,
          content: content,
        );

    final sportsSignals =
        matchedSportsTags.length * 2 +
        (hasSportsKeyword ? 1 : 0) +
        (hasStrongSportsEvidence ? 4 : 0);

    final entertainmentSignals =
        matchedEntertainmentTags.length * 3 + (hasEntertainmentKeyword ? 2 : 0);

    final nationalSignals =
        matchedBangladeshTags.length * 3 +
        (hasBangladeshKeyword ? 2 : 0) +
        (hasNationalKeyword ? 1 : 0);
    final internationalSignals =
        matchedInternationalTags.length * 3 +
        (hasInternationalKeyword ? 2 : 0) +
        (fallback.category == 'international' ? 1 : 0);

    final canBeSports =
        hasStrongSportsEvidence || matchedSportsTags.length >= 2;

    if (canBeSports &&
        sportsSignals > entertainmentSignals &&
        sportsSignals > 0) {
      return TagDrivenCategorizationResult(
        category: 'sports',
        confidence: hasStrongSportsEvidence
            ? (matchedSportsTags.isNotEmpty ? 0.94 : 0.82)
            : 0.78,
        source: matchedSportsTags.isNotEmpty ? 'taxonomy' : fallback.source,
        matchedTags: matchedTags,
        reason: 'Sports tags and keywords dominate the article.',
      );
    }

    if (entertainmentSignals > sportsSignals && entertainmentSignals > 0) {
      return TagDrivenCategorizationResult(
        category: 'entertainment',
        confidence: matchedEntertainmentTags.isNotEmpty ? 0.92 : 0.78,
        source: matchedEntertainmentTags.isNotEmpty
            ? 'taxonomy'
            : fallback.source,
        matchedTags: matchedTags,
        reason: 'Entertainment tags and keywords dominate the article.',
      );
    }

    if (sportsSignals > 0 && entertainmentSignals > 0) {
      if (!canBeSports) {
        return TagDrivenCategorizationResult(
          category: 'entertainment',
          confidence: 0.76,
          source: 'taxonomy+guard',
          matchedTags: matchedTags,
          reason:
              'Sports signals were weak/ambiguous; guarded to entertainment.',
        );
      }
      if (normalizedFeedCategory == 'sports') {
        return TagDrivenCategorizationResult(
          category: 'sports',
          confidence: 0.75,
          source: 'taxonomy+feed_hint',
          matchedTags: matchedTags,
          reason:
              'Sports and entertainment overlap; sports feed hint resolved it.',
        );
      }
      if (normalizedFeedCategory == 'entertainment') {
        return TagDrivenCategorizationResult(
          category: 'entertainment',
          confidence: 0.75,
          source: 'taxonomy+feed_hint',
          matchedTags: matchedTags,
          reason:
              'Sports and entertainment overlap; entertainment feed hint resolved it.',
        );
      }
      return TagDrivenCategorizationResult(
        category: fallback.category == 'sports' ? 'sports' : 'entertainment',
        confidence: 0.72,
        source: 'taxonomy+keyword',
        matchedTags: matchedTags,
        reason: 'Sports and entertainment overlap; fallback resolved it.',
      );
    }

    if (nationalSignals > internationalSignals && nationalSignals > 0) {
      return TagDrivenCategorizationResult(
        category: 'national',
        confidence: matchedBangladeshTags.isNotEmpty ? 0.9 : 0.76,
        source: matchedBangladeshTags.isNotEmpty ? 'taxonomy' : fallback.source,
        matchedTags: matchedTags,
        reason:
            'Bangladesh-specific tags or location markers make this national.',
      );
    }

    if (internationalSignals > nationalSignals && internationalSignals > 0) {
      return TagDrivenCategorizationResult(
        category: 'international',
        confidence: matchedInternationalTags.isNotEmpty ? 0.9 : 0.8,
        source: matchedInternationalTags.isNotEmpty
            ? 'taxonomy'
            : fallback.source,
        matchedTags: matchedTags,
        reason:
            'International entities and non-Bangladesh markers dominate the article.',
      );
    }

    if (nationalSignals > 0 && internationalSignals > 0) {
      if (normalizedFeedCategory == 'international' &&
          matchedBangladeshTags.isEmpty &&
          !hasBangladeshKeyword) {
        return TagDrivenCategorizationResult(
          category: 'international',
          confidence: 0.74,
          source: 'taxonomy+feed_hint',
          matchedTags: matchedTags,
          reason:
              'Balanced national/international signals; feed hint resolved to international.',
        );
      }
      return TagDrivenCategorizationResult(
        category: 'national',
        confidence: 0.74,
        source: 'taxonomy+keyword',
        matchedTags: matchedTags,
        reason:
            'Balanced national/international signals with Bangladesh mention; resolved to national.',
      );
    }

    if (_canonicalCategories.contains(normalizedFeedCategory)) {
      return TagDrivenCategorizationResult(
        category: normalizedFeedCategory,
        confidence: 0.66,
        source: 'feed_hint',
        matchedTags: matchedTags,
        reason: 'Low-confidence content matched the source feed category hint.',
      );
    }

    final fallbackCategory = _canonicalCategories.contains(fallback.category)
        ? fallback.category
        : 'national';

    return TagDrivenCategorizationResult(
      category: fallbackCategory,
      confidence: fallback.confidence.clamp(0.6, 0.78).toDouble(),
      source: fallback.source,
      matchedTags: matchedTags,
      reason: fallback.reason,
    );
  }

  @visibleForTesting
  void overrideTaxonomyForTesting(FeedCategoryTaxonomy taxonomy) {
    _taxonomyOverride = taxonomy;
    _taxonomyFuture = null;
  }
}

class FeedCategoryTaxonomy {
  const FeedCategoryTaxonomy({
    required this.bangladeshTerms,
    required this.internationalTerms,
    required this.sportsTerms,
    required this.entertainmentTerms,
    required this.topicTerms,
    required this.formatTerms,
  });

  const FeedCategoryTaxonomy.empty()
    : bangladeshTerms = const <String, String>{},
      internationalTerms = const <String, String>{},
      sportsTerms = const <String, String>{},
      entertainmentTerms = const <String, String>{},
      topicTerms = const <String, String>{},
      formatTerms = const <String, String>{};

  factory FeedCategoryTaxonomy.fromMap(Map<String, dynamic> json) {
    return FeedCategoryTaxonomy(
      bangladeshTerms: <String, String>{
        ..._buildLookup(json['divisions'], prefix: 'division'),
        ..._buildLookup(json['districts'], prefix: 'district'),
        ..._buildLookup(json['organizations'], prefix: 'organization'),
        ..._manualTerms(const <String, String>{
          'bangladesh': 'country:bangladesh',
          'বাংলাদেশ': 'country:bangladesh',
          'bd': 'country:bangladesh',
          'dhaka': 'district:dhaka',
          'ঢাকা': 'district:dhaka',
        }),
      },
      internationalTerms: <String, String>{
        ..._buildLookup(
          json['international_entities'],
          prefix: 'international',
        ),
        ..._buildLookup(
          json['international_locations'],
          prefix: 'international_location',
        ),
        ..._buildLookup(
          json['international_organizations'],
          prefix: 'international_org',
        ),
        ..._manualTerms(const <String, String>{
          'international': 'international:generic',
          'আন্তর্জাতিক': 'international:generic',
          'world': 'international:world',
          'global': 'international:global',
          'বিশ্ব': 'international:world',
          'জাতিসংঘ': 'international:un',
          'united nations': 'international:un',
          'un': 'international:un',
          'security council': 'international:unsc',
          'eu': 'international:eu',
          'european union': 'international:eu',
          'nato': 'international:nato',
          'white house': 'international:white-house',
          'washington': 'international:washington',
          'london': 'international:london',
          'paris': 'international:paris',
          'beijing': 'international:beijing',
          'moscow': 'international:moscow',
          'new york': 'international:new-york',
          'tokyo': 'international:tokyo',
          'delhi': 'international:delhi',
          'india': 'international:india',
          'china': 'international:china',
          'usa': 'international:usa',
          'united states': 'international:usa',
          'uk': 'international:uk',
          'united kingdom': 'international:uk',
          'russia': 'international:russia',
          'europe': 'international:europe',
          'middle east': 'international:middle-east',
        }),
      },
      sportsTerms: <String, String>{
        ..._buildLookup(json['sports'], prefix: 'sports'),
        ..._manualTerms(const <String, String>{
          'sports': 'sports:sports',
          'sport': 'sports:sports',
          'খেলা': 'sports:sports',
          'খেলাধুলা': 'sports:sports',
        }),
      },
      entertainmentTerms: <String, String>{
        ..._buildLookup(json['entertainment'], prefix: 'entertainment'),
        ..._manualTerms(const <String, String>{
          'entertainment': 'entertainment:entertainment',
          'বিনোদন': 'entertainment:entertainment',
          'showbiz': 'entertainment:showbiz',
          'শোবিজ': 'entertainment:showbiz',
        }),
      },
      topicTerms: _buildLookup(json['topics'], prefix: 'topic'),
      formatTerms: _buildLookup(json['formats'], prefix: 'format'),
    );
  }

  final Map<String, String> bangladeshTerms;
  final Map<String, String> internationalTerms;
  final Map<String, String> sportsTerms;
  final Map<String, String> entertainmentTerms;
  final Map<String, String> topicTerms;
  final Map<String, String> formatTerms;

  Set<String> matchBangladeshTags(String text) => _match(text, bangladeshTerms);

  Set<String> matchInternationalTags(String text) =>
      _match(text, internationalTerms);

  Set<String> matchSportsTags(String text) => _match(text, sportsTerms);

  Set<String> matchEntertainmentTags(String text) =>
      _match(text, entertainmentTerms);

  Set<String> matchTopicTags(String text) => _match(text, topicTerms);

  Set<String> matchFormatTags(String text) => _match(text, formatTerms);

  static Map<String, String> _buildLookup(
    dynamic raw, {
    required String prefix,
  }) {
    final lookup = <String, String>{};
    if (raw is! List) return lookup;

    for (final item in raw) {
      if (item is! Map) continue;
      final id = '$prefix:${item['id'] ?? ''}'.trim();
      if (id == prefix || id.endsWith(':')) continue;
      _addTerm(lookup, item['en']?.toString(), id);
      _addTerm(lookup, item['bn']?.toString(), id);
      _addTerm(lookup, item['id']?.toString().replaceAll('-', ' '), id);
    }

    return lookup;
  }

  static Map<String, String> _manualTerms(Map<String, String> input) {
    final output = <String, String>{};
    input.forEach((term, id) {
      _addTerm(output, term, id);
    });
    return output;
  }

  static void _addTerm(Map<String, String> lookup, String? raw, String id) {
    final normalized = _normalize(raw ?? '');
    if (normalized.isEmpty) return;
    lookup[normalized] = id;
  }

  static Set<String> _match(String text, Map<String, String> lookup) {
    final matched = <String>{};
    lookup.forEach((term, tagId) {
      if (_containsTerm(text, term)) {
        matched.add(tagId);
      }
    });
    return matched;
  }
}

String _normalize(String text) {
  return text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _containsTerm(String text, String term) {
  if (term.isEmpty) return false;

  if (RegExp(r'^[a-z0-9 ]+$').hasMatch(term)) {
    final pattern = term
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(RegExp.escape)
        .join(r'\s+');
    return RegExp(r'\b' + pattern + r'\b').hasMatch(text);
  }

  return text.contains(term);
}
