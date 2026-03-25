import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

/// Metadata for a category (previously in MLCategorizer)
class CategoryMeta {

  const CategoryMeta({
    required this.id,
    required this.labelEn,
    required this.labelBn,
    required this.icon,
  });
  final String id;
  final String labelEn;
  final String labelBn;
  final String icon;
}

class EnhancedAICategorizer {

  EnhancedAICategorizer._internal();
  static final EnhancedAICategorizer _instance =
      EnhancedAICategorizer._internal();
  static EnhancedAICategorizer get instance => _instance;

  final http.Client _client = http.Client();
  final Map<String, String> _memCache = {};

  // Semaphore for limiting concurrent API calls
  // Simple implementation using a counter
  int _activeRequests = 0;
  final int _maxConcurrent = 5;

  // -----------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------
  static const String categoryNational = 'national';
  static const String categoryInternational = 'international';
  static const String categorySports = 'sports';
  static const String categoryEntertainment = 'entertainment';
  static const String categoryGeneral = 'general';
  static const String categoryUnsafe = 'unsafe';

  // ── Category Metadata Map ──────────────
  static const _bdCategoryMap = <String, CategoryMeta>{
    categoryNational: CategoryMeta(
      id: categoryNational,
      labelEn: 'National',
      labelBn: 'জাতীয়',
      icon: '🏛️',
    ),
    categoryInternational: CategoryMeta(
      id: categoryInternational,
      labelEn: 'International',
      labelBn: 'আন্তর্জাতিক',
      icon: '🌏',
    ),
    categorySports: CategoryMeta(
      id: categorySports,
      labelEn: 'Sports',
      labelBn: 'খেলা',
      icon: '⚽',
    ),
    categoryEntertainment: CategoryMeta(
      id: categoryEntertainment,
      labelEn: 'Entertainment',
      labelBn: 'বিনোদন',
      icon: '🎬',
    ),
    categoryGeneral: CategoryMeta(
      id: categoryGeneral,
      labelEn: 'General',
      labelBn: 'সাধারণ',
      icon: '📰',
    ),
  };

  CategoryMeta? getCategoryMeta(String categoryId) {
    if (categoryId == 'politics' ||
        categoryId == 'education' ||
        categoryId == 'bangladesh') {
      return _bdCategoryMap[categoryNational];
    }
    return _bdCategoryMap[categoryId] ?? _bdCategoryMap[categoryNational];
  }

  Future<String> categorizeArticle({
    required String title,
    required String description,
    String content = '',
    String? url,
    String language = 'bn',
  }) async {
    final text = '$title $description $content'.toLowerCase();

    // 1. Memory Cache
    final cacheKey = url ?? title.hashCode.toString();
    if (_memCache.containsKey(cacheKey)) {
      return _memCache[cacheKey]!;
    }

    // 2. High-Confidence Keyword Matching (Regex)
    final keywordCategory = _matchKeywords(text);
    if (keywordCategory != null) {
      _memCache[cacheKey] = keywordCategory;
      return keywordCategory;
    }

    // 3. Content Safety Check (NSFW/Offensive)
    if (_isUnsafe(text)) {
      _memCache[cacheKey] = categoryUnsafe;
      return categoryUnsafe;
    }

    // 4. AI Categorization (only if content is sufficient)
    // If text is too short, default to national
    if (text.length < 50) return categoryNational;

    try {
      final aiCategory = await _callGeminiAPI(text);
      if (aiCategory != null) {
        final normalized = _normalizeCategory(aiCategory);
        _memCache[cacheKey] = normalized;
        return normalized;
      }
    } catch (e) {
      debugPrint('⚠️ AI Categorization failed: $e');
    }

    // Default Fallback
    return categoryNational;
  }

  String? _matchKeywords(String text) {
    // 1. International Disambiguation (West Bengal always international)
    if (RegExp(
      r'\b(west bengal|পশ্চিমবঙ্গ|kolkata|কলকাতা|mamata|মমতা|trinamool|তৃণমূল|bjp|বিজেপি)\b',
    ).hasMatch(text)) {
      return categoryInternational;
    }

    // 2. Sports Disambiguation (High Priority)
    // Players and match reporting
    if (RegExp(
          r'\b(shakib|তামিম|tamim|mushfiq|মুশফিক|messi|ronaldo|neymar|kohli|bpl|ipl|world cup)\b',
        ).hasMatch(text) &&
        RegExp(
          r'\b(cricket|ক্রিকেট|football|ফুটবল|match|ম্যাচ|goal|গোল|wicket|উইকেট|runs|রান|stadium)\b',
        ).hasMatch(text)) {
      return categorySports;
    }

    // Explicit match/tournament reporting
    if (RegExp(
      r'\b(match highlights|final score|won the match|defeated|innings|test match|championship|test cricket)\b',
    ).hasMatch(text)) {
      return categorySports;
    }

    // 3. Entertainment Disambiguation
    // Actors and movies
    if (RegExp(
      r'\b(shakib khan|শাকিব খান|apu biswas|অপু বিশ্বাস|bubly|বুবলি|actor|অভিনেতা|actress|অভিনেত্রী|movie|সিনেমা|film|ছবি|hero|নায়ক|dhallywood|ঢালিউড|bollywood|বলিউড|hollywood)\b',
    ).hasMatch(text)) {
      return categoryEntertainment;
    }

    // 4. Broad keyword lists (Low priority fallback within matcher)
    if (RegExp(
      r'\b(cricket|football|tennis|bpl|ipl|world cup|olympics)\b',
    ).hasMatch(text)) {
      return categorySports;
    }
    if (RegExp(
      r'\b(netflix|concert|কনসার্ট|oscars|grammys|music|গান|theater|নাটক)\b',
    ).hasMatch(text)) {
      return categoryEntertainment;
    }
    if (RegExp(
      r'\b(usa|uk|america|india|ভারত|pakistan|পাকিস্তান|china|চীন|russia|রাশিয়া|ukraine|ইউক্রেন|israel|ইসরায়েল|gaza|গাজা|united nations|জাতিসংঘ|nato)\b',
    ).hasMatch(text)) {
      return categoryInternational;
    }

    return null;
  }

  bool _isUnsafe(String text) {
    // Basic NSFW/Safety filter for technical readiness
    final unsafePatterns = RegExp(
      r'\b(porn|adult|sex|hate speech|violence|gore|offensive-word-placeholder)\b',
      caseSensitive: false,
    );
    return unsafePatterns.hasMatch(text);
  }

  Future<String?> _callGeminiAPI(String text) async {
    final apiKey = Config.skOrV1Key;
    if (apiKey.isEmpty) return null;

    if (_activeRequests >= _maxConcurrent) {
      // Too many requests, fallback to keyword
      return null;
    }

    _activeRequests++;

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey',
      );

      final prompt = _buildPrompt(text);

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {'temperature': 0.0, 'maxOutputTokens': 10},
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final answer = data['candidates']?[0]?['content']?['parts']?[0]?['text']
            ?.toString()
            .trim()
            .toLowerCase();
        return answer;
      }
    } catch (e) {
      debugPrint('Gemini API Error: $e');
    } finally {
      _activeRequests--;
    }
    return null;
  }

  String _buildPrompt(String text) {
    return '''
You are a news classifier for Bangladesh. 
Categories: national, international, sports, entertainment.

Strict Rules:
1. Sports: Purely about matches, athletes, scores, tournaments, and sports administration (e.g., Cricket Board).
2. Entertainment: Movies, celebrity gossip, music, arts, and theater. 
   - Note: A report about an actor getting into a political debate is NATIONAL.
   - Note: A report about a sports celebrity getting married is ENTERTAINMENT.
3. International: News strictly from outside Bangladesh (India, USA, UK, etc.).
   - CRITICAL: West Bengal, Kolkata, and Mamata Banerjee news is INTERNATIONAL (Indian state).
4. National: Default for Bangladesh politics, economy, disaster news, and general local interest across all districts (Dhaka, Chittagong, Sylhet, etc.).

Disambiguation:
- Shakib Al Hasan (cricketer) + match -> sports
- Shakib Al Hasan (cricketer) + politics -> national
- Shakib Khan (actor) -> entertainment

Article: "$text"

Respond with ONLY ONE word: the category name.
''';
  }

  String _normalizeCategory(String raw) {
    if (raw.contains('sport')) return categorySports;
    if (raw.contains('entertain')) return categoryEntertainment;
    if (raw.contains('nation') && !raw.contains('inter')) {
      return categoryNational;
    }
    if (raw.contains('inter')) return categoryInternational;
    return categoryNational;
  }

  void dispose() {
    _client.close();
  }
}
