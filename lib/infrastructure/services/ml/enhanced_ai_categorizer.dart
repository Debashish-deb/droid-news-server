// lib/infrastructure/services/ml/enhanced_ai_categorizer.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

/// Simple semaphore for concurrent‑limit handling
class Semaphore {
  int _permits;
  final List<Completer<void>> _queue = [];

  Semaphore(this._permits);
  Future<void> acquire() async {
    if (_permits > 0) {
      _permits--;
      return;
    }
    final completer = Completer<void>();
    _queue.add(completer);
    await completer.future;
  }

  void release() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0).complete();
    } else {
      _permits++;
    }
  }
}

/// Simple language detection helper
class LanguageDetectionResult {
  final String languageCode;
  final double confidence;
  LanguageDetectionResult(this.languageCode, this.confidence);
}

class LanguageDetector {
  static LanguageDetectionResult detect(String text) {
    // Check for Bangla characters (range \u0980-\u09FF)
    final banglaRegex = RegExp(r'[\u0980-\u09FF]');
    if (banglaRegex.hasMatch(text)) {
      return LanguageDetectionResult('bn', 0.9);
    }
    return LanguageDetectionResult('en', 1.0);
  }
}

/// Persistent disk cache
class DiskCache {
  final Directory _dir = Directory('${Directory.systemTemp.path}/news_cache');
  DiskCache() {
    if (!_dir.existsSync()) {
      _dir.createSync(recursive: true);
    }
  }

  String _fileForKey(String key) => '${_dir.path}/$key.json';

  Future<void> write(String key, String value) async {
    try {
      final file = File(_fileForKey(key));
      await file.writeAsString(jsonEncode({
        'category': value,
        'ts': DateTime.now().toUtc().millisecondsSinceEpoch,
      }));
    } catch (e) {
      debugPrint('⚠️ DiskCache write failed: $e');
    }
  }

  Future<String?> read(String key) async {
    try {
      final file = File(_fileForKey(key));
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString());
      // invalidate after 6 h
      if (DateTime.now().toUtc().millisecondsSinceEpoch -
              (data['ts'] as int) >
          6 * 3600 * 1000) {
        return null;
      }
      return data['category'] as String?;
    } catch (e) {
      return null;
    }
  }
}

/// Main categorizer (AI + fallback)
class EnhancedAICategorizer {
  static final EnhancedAICategorizer instance = EnhancedAICategorizer._();

  EnhancedAICategorizer._() {
    _initTries();
  }

  // -----------------------------------------------------------------
  // Configuration
  // -----------------------------------------------------------------
  static const String _model = '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';
  static const String _apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';
  static final String _geminiApiKey = Config.skOrV1Key;

  final http.Client _client = http.Client();
  final Map<String, String> _memCache = {};
  final DiskCache _diskCache = DiskCache();
  final Semaphore _semaphore = Semaphore(10); // max parallel LLM calls

  // -----------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------
  static const String categoryNational = 'national';
  static const String categoryInternational = 'international';
  static const String categorySports = 'sports';
  static const String categoryEntertainment = 'entertainment';
  static const String categoryGeneral = 'general';

  /// Main entry point – detects language automatically.
  Future<String> categorizeArticle({
    required String title,
    required String description,
    String? content,
    String? language, // optional override
    String? url,      // optional – used for caching key
  }) async {
    final cacheKey = _hash(url ?? '$title${description.hashCode}');
    // 1️⃣  Memory cache
    if (_memCache.containsKey(cacheKey)) return _memCache[cacheKey]!;

    // 2️⃣  Disk cache
    final persisted = await _diskCache.read(cacheKey);
    if (persisted != null) {
      _memCache[cacheKey] = persisted;
      return persisted;
    }

    // 3️⃣  Language detection (fallback to English)
    final lang = language ?? _detectLanguage('$title $description ${content ?? ''}');

    // 4️⃣  Try AI first, guarded by semaphore
    String category;
    try {
      category = await _runLimited(() => _categorizeWithAI(
            title: title,
            description: description,
            content: content,
            language: lang,
          ));
    } catch (e) {
      if (kDebugMode) debugPrint('⚡ AI failed: $e');
      // 5️⃣  Keyword fallback
      category = _keywordBasedCategorization(title, description, content ?? '');
    }

    // 6️⃣  Cache results
    _memCache[cacheKey] = category;
    await _diskCache.write(cacheKey, category);
    return category;
  }

  /// Batch version – returns a map of URL (or index) → category.
  Future<Map<String, String>> batchCategorize({
    required List<Map<String, String>> articles,
    String? language,
  }) async {
    final results = <String, String>{};
    final futures = <Future<void>>[];

    for (var i = 0; i < articles.length; i++) {
      final article = articles[i];
      final url = article['url'] ?? i.toString();
      futures.add(
        categorizeArticle(
          title: article['title'] ?? '',
          description: article['description'] ?? '',
          content: article['content'],
          language: language,
          url: url,
        ).then((cat) => results[url] = cat),
      );

      // Respect concurrency limit
      if (futures.length >= 5 || i == articles.length - 1) {
        await Future.wait(futures);
        futures.clear();
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }
    return results;
  }

  // -----------------------------------------------------------------
  // Private helpers
  // -----------------------------------------------------------------
  Future<T> _runLimited<T>(Future<T> Function() fn) async {
    await _semaphore.acquire();
    try {
      return await fn();
    } finally {
      _semaphore.release();
    }
  }

  String _detectLanguage(String text) {
    final result = LanguageDetector.detect(text);
    return (result.confidence > 0.7) ? result.languageCode : 'en';
  }

  String _hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // -------------------------------------------------------------
  // 1️⃣ AI Path
  // -------------------------------------------------------------
  Future<String> _categorizeWithAI({
    required String title,
    required String description,
    String? content,
    required String language,
  }) async {
    final fullText = '$title. $description. ${content ?? ''}';
    final prompt = _buildPrompt(fullText, language);

    final response = await _client
        .post(
          Uri.parse('$_apiUrl?key=$_geminiApiKey'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.0,
              'topP': 0.1,
              'maxOutputTokens': 10,
            },
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final raw = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
    return _parseCategory(raw.trim().toLowerCase());
  }

  String _buildPrompt(String text, String language) {
    const categories = 'national, international, sports, entertainment';
    const rulesBn = '''
১. খেলাধুলা বা বিনোদন‑সংক্রান্ত সংবাদ হলে অবশ্যই sports বা entertainment দিন।
২. যদি বাংলাদেশ‑সংক্রান্ত (জেলা, রাজনীতি, সরকার) কোনো শব্দ থাকে এবং তা খেলাধুলা বা বিনোদন না হয় → national
৩. অন্য দেশের রাজনীতি/অর্থনীতি/সামাজিক সংবাদ → international''';
    const rulesEn = '''
1. If it is Sports or Entertainment, ALWAYS use sports or entertainment.
2. If NOT sports/entertainment AND mentions Bangladesh (districts, politics, government) → national
3. All other foreign political/economic/social news → international''';

    final rules = language == 'bn' ? rulesBn : rulesEn;

    return '''
You are a Bangladeshi news‑categorisation AI.

Categories: $categories

Rules:
$rules

Article:
"$text"

Respond with ONLY ONE word from the category list (lower‑case, no punctuation).''';
  }

  String _parseCategory(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^a-z]'), '');
    if (clean.contains('sports') || clean.contains('sport')) return categorySports;
    if (clean.contains('entertainment') || clean.contains('entertain')) return categoryEntertainment;
    if (clean.contains('national')) return categoryNational;
    if (clean.contains('international')) return categoryInternational;
    return categoryGeneral;
  }

  // -------------------------------------------------------------
  // 2️⃣ Keyword‑fallback (enhanced)
  // -------------------------------------------------------------
  final _nationalKeywords = [
    // Districts (English)
    'dhaka', 'faridpur', 'gazipur', 'gopalganj', 'kishoreganj', 'madaripur', 'manikganj', 'munshiganj', 'narayanganj', 'narsingdi', 'rajbari', 'shariatpur', 'tangail',
    'bagerhat', 'chuadanga', 'jessore', 'jhenaidah', 'khulna', 'kushtia', 'magura', 'meherpur', 'narail', 'satkhira',
    'bogra', 'joypurhat', 'naogaon', 'natore', 'chapai nawabganj', 'pabna', 'rajshahi', 'sirajganj',
    'dinajpur', 'gaibandha', 'kurigram', 'lalmonirhat', 'nilphamari', 'panchagarh', 'rangpur', 'thakurgaon',
    'habiganj', 'maulvibazar', 'sunamganj', 'sylhet',
    'barguna', 'barisal', 'bhola', 'jhalokati', 'patuakhali', 'pirojpur',
    'bandarban', 'brahmanbaria', 'chandpur', 'chittagong', 'comilla', 'cox\'s bazar', 'feni', 'khagrachari', 'lakshmipur', 'noakhali', 'rangamati',
    'jamalpur', 'mymensingh', 'netrokona', 'sherpur',
    // Districts (Bangla)
    'ঢাকা', 'ফরিদপুর', 'গাজীপুর', 'গোপালগঞ্জ', 'কিশোরগঞ্জ', 'মাদারীপুর', 'মানিকগঞ্জ', 'মুন্সীগঞ্জ', 'নারায়ণগঞ্জ', 'নরসিংদী', 'রাজবাড়ী', 'শরীয়তপুর', 'টাঙ্গাইল',
    'বাগেরহাট', 'চুয়াডাঙ্গা', 'যশোর', 'ঝিনাইদহ', 'খুলনা', 'কুষ্টিয়া', 'মাগুরা', 'মেহেরপুর', 'নড়াইল', 'সাতক্ষীরা',
    'বগুড়া', 'জয়পুরহাট', 'নওগাঁ', 'নাটোর', 'নবাবগঞ্জ', 'পাবনা', 'রাজশাহী', 'সিরাজগঞ্জ',
    'দিনাজপুর', 'গাইবান্ধা', 'কুড়িগ্রাম', 'লালমনিরহাট', 'নীলফামারী', 'পঞ্চগড়', 'রংপুর', 'ঠাকুরগাঁও',
    'হবিগঞ্জ', 'মৌলভীবাজার', 'সুনামগঞ্জ', 'সিলেট',
    'বরগুনা', 'বরিশাল', 'ভোলা', 'ঝালকাঠি', 'পটুয়াখালী', 'পিরোজপুর',
    'বান্দরবান', 'ব্রাহ্মণবাড়িয়া', 'চাঁদপুর', 'চট্টগ্রাম', 'কুমিল্লা', 'কক্সবাজার', 'ফেনী', 'খাগড়াছড়ি', 'লক্ষ্মীপুর', 'নোয়াখালী', 'রাঙ্গামাটি',
    'জামালপুর', 'ময়মনসিংহ', 'নেত্রকোণা', 'শেরপুর',
    // Political & Govt
    'bangladesh', 'বাংলাদেশ', 'minister', 'সরকার', 'prime minister', 'শেখ হাসিনা', 'parliament', 'সংসদ', 'আওয়ামী লীগ', 'বিএনপি', 'awami league', 'bnp', 'khaleda zia', 'খালেদা জিয়া', 'rab', 'র‍্যাব', 'বিজিবি', 'bgb', 'পুলিশ', 'police', 'হাইকোর্ট', 'high court', 'সুপ্রিম কোর্ট', 'নির্বাচন', 'election', 'ভোট', 'উপদেষ্টা', 'তারেক রহমান',
  ];
  final _sportsKeywords = [
    'cricket', 'ক্রিকেট', 'football', 'ফুটবল', 'match', 'ম্যাচ', 'tournament', 'টুর্নামেন্ট', 'world cup', 'বিশ্বকাপ', 'olympics', 'অলিম্পিক', 'ipl', 'fifa', 'premier league', 'shakib', 'শাকিব', 'mushfiq', 'মুশফিক', 'তামিম', 'tamim', 'বিপিএল', 'bpl', 'সাকিব',
  ];
  final _entertainKeywords = [
    'movie', 'সিনেমা', 'film', 'ছবি', 'actor', 'অভিনেতা', 'music', 'গান', 'concert', 'কনসার্ট', 'bollywood', 'বলিউড', 'hollywood', 'হলিউড', 'dhallywood', 'ঢালিউড', 'netflix', 'নেটফ্লিক্স', 'award', 'পুরস্কার', 'শাকিব খান', 'shakib khan', 'নাটক', 'drama',
  ];
  final _internationalKeywords = [
    'usa', 'america', 'uk', 'britain', 'india', 'ভারত', 'pakistan', 'চীন', 'china', 'russia', 'রাশিয়া', 'europe', 'middle east', 'মধ্যপ্রাচ্য', 'africa', 'আফ্রিকা', 'japan', 'জাপান', 'australia', 'অস্ট্রেলিয়া', 'canada', 'কানাডা', 'france', 'ফ্রান্স', 'germany', 'জার্মানি', 'united nations', 'জাতিসংঘ', 'biden', 'বাইডেন', 'পুতিন', 'putin', 'ট্রাম্প', 'trump', 'ইসরায়েল', 'গাজা', 'israel', 'gaza',
  ];

  void _initTries() {
    // Current simple implementation doesn't use trie for speed but could be added back
  }

  String _keywordBasedCategorization(String title, String description, String content) {
    final text = '$title $description $content'.toLowerCase();

    // Priority order: sports → entertainment → national → international
    for (final kw in _sportsKeywords) {
      if (text.contains(kw)) return categorySports;
    }
    for (final kw in _entertainKeywords) {
      if (text.contains(kw)) return categoryEntertainment;
    }
    for (final kw in _nationalKeywords) {
      if (text.contains(kw)) return categoryNational;
    }
    for (final kw in _internationalKeywords) {
      if (text.contains(kw)) return categoryInternational;
    }

    return categoryNational;
  }

  // -----------------------------------------------------------------
  // Clean‑up
  // -----------------------------------------------------------------
  void dispose() {
    _client.close();
    _memCache.clear();
  }
}