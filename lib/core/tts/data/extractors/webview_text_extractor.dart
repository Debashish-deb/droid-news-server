import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ─── Result / exception types ─────────────────────────────────────────────────

/// Structured output returned by [WebViewTextExtractor.extractFull].
class ExtractionResult {
  const ExtractionResult({
    required this.body,
    this.title,
    this.author,
    this.publishedAt,
    this.siteName,
    this.description,
    this.detectedLanguage = 'en',
    this.wordCount = 0,
  });

  /// Empty sentinel — returned on failure or when the page has no readable content.
  static const empty = ExtractionResult(body: '');

  /// The main article body text, cleaned and normalised.
  final String body;

  /// Article title extracted from LD+JSON, OpenGraph, or `<title>`.
  final String? title;

  /// Byline / author name.
  final String? author;

  /// ISO-8601 publish date string (if found in metadata).
  final String? publishedAt;

  /// Site / publication name from OpenGraph `og:site_name`.
  final String? siteName;

  /// Short article description or excerpt.
  final String? description;

  /// BCP-47 language code inferred from body text (`"en"` or `"bn"`).
  final String detectedLanguage;

  /// Approximate word count of [body].
  final int wordCount;

  /// `true` when [body] is empty.
  bool get isEmpty => body.isEmpty;

  /// `true` when [body] is non-empty.
  bool get isNotEmpty => body.isNotEmpty;

  /// Estimated reading time in minutes (based on 200 wpm average).
  int get estimatedReadingMinutes => (wordCount / 200).ceil().clamp(1, 120);

  @override
  String toString() =>
      'ExtractionResult('
      'lang: $detectedLanguage, '
      'words: $wordCount, '
      'title: ${title ?? "none"})';
}

/// Failure categories for [ExtractionException].
enum ExtractionFailureReason {
  /// JavaScript evaluation timed out.
  timeout,

  /// The JS engine threw an exception.
  javaScriptError,

  /// Evaluation returned null / empty before sanitisation.
  emptyResult,

  /// Post-processing failed to parse the JS return value.
  parseError,

  /// The Readability asset could not be loaded from the bundle.
  assetLoadFailure,
}

/// Thrown by [WebViewTextExtractor.extractFull] on failure.
class ExtractionException implements Exception {
  const ExtractionException(this.reason, this.message, {this.cause});

  final ExtractionFailureReason reason;
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'ExtractionException(${reason.name}): $message'
      '${cause != null ? ' caused by: $cause' : ''}';
}

// ─── Extractor ────────────────────────────────────────────────────────────────

class WebViewTextExtractor {
  WebViewTextExtractor({
    String? readabilityScriptOverride,
    this.timeout = const Duration(seconds: 12),
  }) : _readabilityScriptOverride = readabilityScriptOverride;

  final String? _readabilityScriptOverride;

  /// Maximum time allowed for JavaScript evaluation. Defaults to 12 s.
  final Duration timeout;

  static String? _cachedReadabilityScript;

  // ─── Noise / filter constants ───────────────────────────────────────────────

  static const List<String> _noiseMarkers = <String>[
    'read more', 'also read', 'related', 'recommended', 'trending',
    'most read', 'most popular', 'you may like', 'newsletter',
    'subscribe', 'sign up', 'follow us', 'share this', 'comments',
    'advertisement', 'sponsored', 'cookie', 'privacy policy',
    'terms of use', 'breaking:',
    // Bengali equivalents
    'আরও পড়ুন', 'সম্পর্কিত', 'সংশ্লিষ্ট', 'জনপ্রিয়', 'ট্রেন্ডিং',
  ];

  static final RegExp _metadataLinePattern = RegExp(
    r'^(by|source|published|updated|last updated|posted|author|category|tags?)\b',
    caseSensitive: false,
  );
  static final RegExp _urlPattern = RegExp(
    r'https?://\S+|www\.\S+',
    caseSensitive: false,
  );
  static final RegExp _bengaliGlyphPattern = RegExp(r'[\u0980-\u09FF]');
  static final RegExp _latinGlyphPattern = RegExp(r'[a-zA-Z]');

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Extracts the readable body text from [webViewController].
  ///
  /// Backward-compatible: returns the plain body string only.
  /// For metadata use [extractFull].
  Future<String> extract(dynamic webViewController) async {
    try {
      final result = await extractFull(webViewController);
      return result.body;
    } catch (_) {
      return '';
    }
  }

  /// Extracts body text **and** metadata from [webViewController].
  ///
  /// Throws [ExtractionException] on failure.
  Future<ExtractionResult> extractFull(dynamic webViewController) async {
    final String readabilityScript;
    try {
      readabilityScript = await _loadReadabilityScript();
    } catch (e) {
      throw ExtractionException(
        ExtractionFailureReason.assetLoadFailure,
        'Could not load Readability asset.',
        cause: e,
      );
    }

    final String rawResult;
    try {
      rawResult = await webViewController
          .evaluateJavascript(source: _buildExtractorScript(readabilityScript))
          .timeout(
            timeout,
            onTimeout: () {
              throw ExtractionException(
                ExtractionFailureReason.timeout,
                'JavaScript evaluation exceeded ${timeout.inSeconds}s.',
              );
            },
          );
    } on ExtractionException {
      rethrow;
    } catch (e) {
      throw ExtractionException(
        ExtractionFailureReason.javaScriptError,
        'JavaScript evaluation threw an exception.',
        cause: e,
      );
    }

    if (rawResult.isEmpty || rawResult == 'null' || rawResult == 'undefined') {
      throw const ExtractionException(
        ExtractionFailureReason.emptyResult,
        'JavaScript returned an empty result.',
      );
    }

    // Heavy processing off the UI thread.
    try {
      return await compute(_parseExtractionPayload, rawResult);
    } catch (e) {
      throw ExtractionException(
        ExtractionFailureReason.parseError,
        'Failed to parse extraction payload.',
        cause: e,
      );
    }
  }

  // ─── Asset loading ──────────────────────────────────────────────────────────

  Future<String> _loadReadabilityScript() async {
    if (_readabilityScriptOverride != null) return _readabilityScriptOverride;
    if (_cachedReadabilityScript != null) return _cachedReadabilityScript!;
    try {
      _cachedReadabilityScript = await rootBundle.loadString(
        'assets/js/readability.js',
      );
      return _cachedReadabilityScript!;
    } catch (e) {
      // Continue without Readability; scorer fallback will be used.
      _cachedReadabilityScript = '';
      return '';
    }
  }

  // ─── JS script ────────────────────────────────────────────────────────────

  static String _buildExtractorScript(String readabilityScript) =>
      '''
(function() {
  const ns = (v) => String(v || '')
    .replace(/\\u00a0/g, ' ')
    .replace(/[ \\t]+/g, ' ')
    .replace(/\\n{3,}/g, '\\n\\n')
    .trim();

  // ── Elements to strip before scoring ──────────────────────────────────────
  const REMOVE = [
    'script','style','nav','footer','aside','noscript','header',
    'form','button','svg','canvas',
    '.ads','.ad','.advertisement','.advert','.sponsored','.promo',
    '.social-share','.share-tools','.newsletter','.comments','.comment',
    '.related','.related-posts','.recommended','.trending','.most-popular',
    '.cookie-banner','.consent','.popup','.overlay','.paywall',
    '[role="navigation"]','[role="complementary"]','[aria-label*="share"]',
    '[data-testid*="ad"]','[id*="taboola"]','[id*="outbrain"]'
  ];

  const strip = (node) => {
    if (!node || !node.querySelectorAll) return;
    REMOVE.forEach((s) => node.querySelectorAll(s).forEach((el) => el.remove()));
    node.querySelectorAll('[class*="ad-"],[id*="ad-"],[class*="sponsor"],[id*="sponsor"]')
      .forEach((el) => el.remove());
  };

  const score = (node) => {
    if (!node) return -1;
    const t = ns(node.innerText || node.textContent || '');
    if (t.length < 220) return -1;
    const p = node.querySelectorAll ? node.querySelectorAll('p').length : 0;
    const h = node.querySelectorAll ? node.querySelectorAll('h1,h2,h3,h4').length : 0;
    const links = node.querySelectorAll ? Array.from(node.querySelectorAll('a')) : [];
    const ld = links.reduce((s,a) => s + ns(a.innerText).length, 0) / Math.max(t.length, 1);
    const m = String((node.className||'') + ' ' + (node.id||'')).toLowerCase();
    const pen = /(related|recommend|trending|popular|comment|footer|sidebar|share|menu|nav|header)/.test(m) ? 400 : 0;
    return t.length + (p * 120) - Math.round(ld * 900) - (h * 40) - pen;
  };

  // ── Metadata extraction ───────────────────────────────────────────────────
  const getMeta = (prop) => {
    const el = document.querySelector(
      'meta[property="'+prop+'"],meta[name="'+prop+'"]'
    );
    return el ? ns(el.getAttribute('content')) : '';
  };

  const getLdJson = () => {
    try {
      const scripts = Array.from(document.querySelectorAll('script[type="application/ld+json"]'));
      for (const s of scripts) {
        let d;
        try { d = JSON.parse(s.textContent || ''); } catch(_) { continue; }
        const nodes = Array.isArray(d) ? d : [d];
        for (const n of nodes) {
          if (n && typeof n === 'object') return n;
        }
      }
    } catch(_) {}
    return null;
  };

  const ld = getLdJson();
  const metaTitle = getMeta('og:title') || getMeta('twitter:title')
    || (document.title ? ns(document.title) : '');
  const metaAuthor = getMeta('author') || getMeta('article:author')
    || (ld && typeof ld.author === 'string' ? ld.author : '')
    || (ld && ld.author && ld.author.name ? ld.author.name : '');
  const metaPublished = getMeta('article:published_time')
    || getMeta('datePublished')
    || (ld ? ld.datePublished || '' : '');
  const metaSite = getMeta('og:site_name')
    || (ld ? ld.publisher && ld.publisher.name ? ld.publisher.name : '' : '');
  const metaDesc = getMeta('og:description') || getMeta('description');

  // ── Body extraction ───────────────────────────────────────────────────────
  const withReadability = () => {
    try {
      if (typeof Readability === 'undefined') { $readabilityScript }
      if (typeof Readability === 'undefined') return '';
      const parsed = new Readability(document.cloneNode(true)).parse();
      return parsed && parsed.textContent && parsed.textContent.length > 220
        ? parsed.textContent : '';
    } catch(_) { return ''; }
  };

  const withLdBody = () => {
    if (!ld) return '';
    const body = ld.articleBody;
    return typeof body === 'string' && body.trim().length > 220 ? body : '';
  };

  const withScoring = () => {
    const candidates = Array.from(document.querySelectorAll(
      'article,main,[role="main"],[itemprop*="articleBody"],' +
      '[class*="article"],[class*="story"],[class*="content"],section,div'
    ));
    let best = '', bestScore = -1;
    for (const c of candidates) {
      const clone = c.cloneNode(true);
      strip(clone);
      const s = score(clone);
      if (s > bestScore) { bestScore = s; best = ns(clone.innerText || clone.textContent || ''); }
    }
    return best;
  };

  let body = withReadability();
  if (!body) body = withLdBody();
  if (!body) body = withScoring();
  if (!body) {
    const clone = document.body ? document.body.cloneNode(true) : null;
    strip(clone);
    body = ns(clone ? (clone.innerText || clone.textContent || '') : '');
  }

  return JSON.stringify({
    body: ns(body),
    title: metaTitle,
    author: metaAuthor,
    publishedAt: metaPublished,
    siteName: metaSite,
    description: metaDesc
  });
})();
''';

  // ─── Isolate-safe parsing ────────────────────────────────────────────────

  static ExtractionResult _parseExtractionPayload(String raw) {
    // Decode the outer JS string quoting.
    final decoded = _decodeJsResult(raw);
    if (decoded.isEmpty) return ExtractionResult.empty;

    // The extractor now always returns JSON.
    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(decoded) as Map<String, dynamic>?;
    } catch (_) {
      // Fallback: treat the whole string as body text (old script format).
      final body = _sanitizeBody(decoded);
      return body.isEmpty
          ? ExtractionResult.empty
          : ExtractionResult(
              body: body,
              wordCount: _countWords(body),
              detectedLanguage: _detectLanguage(body),
            );
    }

    if (payload == null) return ExtractionResult.empty;

    final body = _sanitizeBody(payload['body'] as String? ?? '');
    if (body.isEmpty) return ExtractionResult.empty;

    return ExtractionResult(
      body: body,
      title: _nvl(payload['title'] as String?),
      author: _nvl(payload['author'] as String?),
      publishedAt: _nvl(payload['publishedAt'] as String?),
      siteName: _nvl(payload['siteName'] as String?),
      description: _nvl(payload['description'] as String?),
      wordCount: _countWords(body),
      detectedLanguage: _detectLanguage(body),
    );
  }

  // ─── Text sanitisation ────────────────────────────────────────────────────

  static String _sanitizeBody(String raw) {
    if (raw.isEmpty) return '';
    final lines = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final seenKeys = <String, int>{};
    final kept = <String>[];

    for (final line in lines) {
      if (_shouldDropLine(line)) continue;
      final key = _normalizeKey(line);
      if (key.length < 8) continue;
      final count = (seenKeys[key] ?? 0) + 1;
      seenKeys[key] = count;
      if (count > 1 && line.length < 180) continue;
      kept.add(line);
    }

    return _dedupeSentences(kept.join('\n'))
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _decodeJsResult(String raw) {
    var text = raw.trim();
    if (text.isEmpty || text == 'null' || text == 'undefined') return '';
    try {
      final decoded = jsonDecode(text);
      if (decoded is String) text = decoded;
    } catch (_) {}
    return text
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'")
        .trim();
  }

  static bool _shouldDropLine(String line) {
    final lower = line.toLowerCase();
    final words = line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    if (_urlPattern.hasMatch(line)) return true;
    if (_metadataLinePattern.hasMatch(lower) && line.length < 180) return true;
    if (_noiseMarkers.any(lower.contains) && line.length < 220) return true;
    if (words <= 3 && line.length < 25) return true;
    if (RegExp(r'^[A-Z0-9\s|:/_-]{2,}$').hasMatch(line) && line.length < 80) {
      return true;
    }
    return false;
  }

  static String _normalizeKey(String line) =>
      line.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0980-\u09ff]+'), '');

  static String _dedupeSentences(String text) {
    final matches = RegExp(r'[^.!?।]+[.!?।]?').allMatches(text);
    if (matches.isEmpty) return text;
    final seen = <String, int>{};
    final buf = StringBuffer();
    for (final m in matches) {
      final s = m.group(0)?.trim() ?? '';
      if (s.isEmpty) continue;
      final key = _normalizeKey(s);
      if (key.length < 8) continue;
      final count = (seen[key] ?? 0) + 1;
      seen[key] = count;
      if (count > 1 && s.length < 200) continue;
      buf.write('$s ');
    }
    return buf.toString().trim();
  }

  // ─── Language & word count utilities ─────────────────────────────────────

  /// Detects `"bn"` (Bengali) or `"en"` (English) from character ratio.
  static String _detectLanguage(String text) {
    final bengali = _bengaliGlyphPattern.allMatches(text).length;
    final latin = _latinGlyphPattern.allMatches(text).length;
    final total = bengali + latin;
    if (total == 0) return 'en';
    return (bengali / total) > 0.25 ? 'bn' : 'en';
  }

  static int _countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  /// Returns [s] trimmed, or `null` if empty after trimming.
  static String? _nvl(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}
