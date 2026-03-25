import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WebViewTextExtractor {
  WebViewTextExtractor({String? readabilityScriptOverride})
    : _readabilityScriptOverride = readabilityScriptOverride;

  final String? _readabilityScriptOverride;
  static String? _cachedReadabilityScript;

  static const List<String> _noiseMarkers = <String>[
    'read more',
    'also read',
    'related',
    'recommended',
    'trending',
    'most read',
    'most popular',
    'you may like',
    'newsletter',
    'subscribe',
    'sign up',
    'follow us',
    'share this',
    'comments',
    'advertisement',
    'sponsored',
    'cookie',
    'privacy policy',
    'terms of use',
    'breaking:',
    'আরও পড়ুন',
    'আরও পড়ুন',
    'সম্পর্কিত',
    'সংশ্লিষ্ট',
    'জনপ্রিয়',
    'জনপ্রিয়',
    'ট্রেন্ডিং',
  ];

  static final RegExp _metadataLinePattern = RegExp(
    r'^(by|source|published|updated|last updated|posted|author|category|tags?)\b',
    caseSensitive: false,
  );
  static final RegExp _urlPattern = RegExp(
    r'https?://\S+|www\.\S+',
    caseSensitive: false,
  );

  Future<String> extract(dynamic webViewController) async {
    try {
      final readabilityScript = await _loadReadabilityScript();
      final source = _buildExtractorScript(readabilityScript);
      final result = await webViewController.evaluateJavascript(source: source);
      if (result == null) return '';

      // Keep heavy cleanup off the UI isolate for large articles.
      return compute(_sanitizeContent, result.toString());
    } catch (_) {
      return '';
    }
  }

  Future<String> _loadReadabilityScript() async {
    if (_readabilityScriptOverride != null) {
      return _readabilityScriptOverride;
    }
    if (_cachedReadabilityScript != null) {
      return _cachedReadabilityScript!;
    }
    try {
      _cachedReadabilityScript = await rootBundle.loadString(
        'assets/js/readability.js',
      );
      return _cachedReadabilityScript!;
    } catch (_) {
      _cachedReadabilityScript = '';
      return '';
    }
  }

  static String _buildExtractorScript(String readabilityScript) =>
      '''
(function() {
  const normalizeSpace = (value) => String(value || '')
    .replace(/\\u00a0/g, ' ')
    .replace(/[ \\t]+/g, ' ')
    .replace(/\\n{3,}/g, '\\n\\n')
    .trim();

  const selectorsToRemove = [
    'script', 'style', 'nav', 'footer', 'aside', 'noscript', 'header',
    'form', 'button', 'svg', 'canvas',
    '.ads', '.ad', '.advertisement', '.advert', '.sponsored', '.promo',
    '.social-share', '.share-tools', '.newsletter', '.comments', '.comment',
    '.related', '.related-posts', '.recommended', '.trending', '.most-popular',
    '.cookie-banner', '.consent', '.popup', '.overlay', '.paywall',
    '[role="navigation"]', '[role="complementary"]', '[aria-label*="share"]',
    '[data-testid*="ad"]', '[id*="taboola"]', '[id*="outbrain"]'
  ];

  const cleanupNode = (node) => {
    if (!node || !node.querySelectorAll) return;
    selectorsToRemove.forEach((selector) => {
      node.querySelectorAll(selector).forEach((el) => el.remove());
    });
    node.querySelectorAll('[class*="ad-"], [id*="ad-"], [class*="sponsor"], [id*="sponsor"]')
      .forEach((el) => el.remove());
  };

  const scoreNode = (node) => {
    if (!node) return -1;
    const text = normalizeSpace(node.innerText || node.textContent || '');
    if (text.length < 220) return -1;

    const pCount = node.querySelectorAll ? node.querySelectorAll('p').length : 0;
    const headings = node.querySelectorAll ? node.querySelectorAll('h1,h2,h3,h4').length : 0;
    const links = node.querySelectorAll ? Array.from(node.querySelectorAll('a')) : [];
    const linkText = links.reduce((sum, a) => sum + normalizeSpace(a.innerText).length, 0);
    const linkDensity = linkText / Math.max(text.length, 1);

    const marker = String((node.className || '') + ' ' + (node.id || '')).toLowerCase();
    const noisePenalty = /(related|recommend|trending|popular|comment|footer|sidebar|share|menu|nav|header)/.test(marker)
      ? 400
      : 0;

    return text.length + (pCount * 120) - Math.round(linkDensity * 900) - (headings * 40) - noisePenalty;
  };

  const parseWithReadability = () => {
    try {
      if (typeof Readability === 'undefined') {
        $readabilityScript
      }
      if (typeof Readability === 'undefined') return '';
      const parsed = new Readability(document.cloneNode(true)).parse();
      if (parsed && parsed.textContent && parsed.textContent.length > 220) {
        return parsed.textContent;
      }
    } catch (_) {}
    return '';
  };

  const parseFromLdJson = () => {
    try {
      const scripts = Array.from(document.querySelectorAll('script[type="application/ld+json"]'));
      for (const script of scripts) {
        const raw = script.textContent || '';
        if (!raw.trim()) continue;
        let data;
        try {
          data = JSON.parse(raw);
        } catch (_) {
          continue;
        }

        const nodes = Array.isArray(data) ? data : [data];
        for (const node of nodes) {
          const articleBody = node && typeof node === 'object' ? node.articleBody : null;
          if (typeof articleBody === 'string' && articleBody.trim().length > 220) {
            return articleBody;
          }
        }
      }
    } catch (_) {}
    return '';
  };

  const parseByScoring = () => {
    const candidates = Array.from(document.querySelectorAll(
      'article,main,[role="main"],[itemprop*="articleBody"],[class*="article"],[class*="story"],[class*="content"],section,div'
    ));
    let bestText = '';
    let bestScore = -1;

    for (const candidate of candidates) {
      const clone = candidate.cloneNode(true);
      cleanupNode(clone);
      const score = scoreNode(clone);
      if (score > bestScore) {
        bestScore = score;
        bestText = normalizeSpace(clone.innerText || clone.textContent || '');
      }
    }
    return bestText;
  };

  let extracted = parseWithReadability();
  if (!extracted) extracted = parseFromLdJson();
  if (!extracted) extracted = parseByScoring();
  if (!extracted) {
    const body = document.body ? document.body.cloneNode(true) : null;
    cleanupNode(body);
    extracted = normalizeSpace(body ? (body.innerText || body.textContent || '') : '');
  }

  return normalizeSpace(extracted);
})();
''';

  static String _sanitizeContent(String raw) {
    final decoded = _decodeJsResult(raw);
    if (decoded.isEmpty) return '';

    final lines = decoded
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final seenLineKeys = <String, int>{};
    final keptLines = <String>[];

    for (final line in lines) {
      if (_shouldDropLine(line)) continue;

      final key = _normalizeComparable(line);
      if (key.length < 8) continue;

      final count = (seenLineKeys[key] ?? 0) + 1;
      seenLineKeys[key] = count;

      // Keep one long duplicate if it is likely body content, drop repeats.
      if (count > 1 && line.length < 180) continue;
      keptLines.add(line);
    }

    final joined = keptLines.join('\n');
    final dedupedSentences = _dedupeSentences(joined);

    return dedupedSentences
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
      if (decoded is String) {
        text = decoded;
      } else if (decoded is Map && decoded['text'] is String) {
        text = decoded['text'] as String;
      }
    } catch (_) {
      // Keep raw value if it is not JSON-encoded.
    }

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

    final hasNoiseMarker = _noiseMarkers.any(lower.contains);
    if (hasNoiseMarker && line.length < 220) return true;

    // Menu-like fragments or tiny labels are usually not article text.
    if (words <= 3 && line.length < 25) return true;
    if (RegExp(r'^[A-Z0-9\s|:/_-]{2,}$').hasMatch(line) && line.length < 80) {
      return true;
    }

    return false;
  }

  static String _normalizeComparable(String line) {
    return line.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9\u0980-\u09ff]+'),
      '',
    );
  }

  static String _dedupeSentences(String text) {
    final matches = RegExp(r'[^.!?।]+[.!?।]?').allMatches(text);
    if (matches.isEmpty) return text;

    final seen = <String, int>{};
    final buffer = StringBuffer();

    for (final match in matches) {
      final sentence = match.group(0)?.trim() ?? '';
      if (sentence.isEmpty) continue;

      final key = _normalizeComparable(sentence);
      if (key.length < 8) continue;

      final count = (seen[key] ?? 0) + 1;
      seen[key] = count;

      // Repeated short snippets are usually nav/recommendation residue.
      if (count > 1 && sentence.length < 200) continue;
      buffer.write('$sentence ');
    }

    return buffer.toString().trim();
  }
}
