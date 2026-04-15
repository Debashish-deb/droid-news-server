import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../../core/telemetry/structured_logger.dart';

/// Service to extract full article content from a URL for reader/offline flows.
class ArticleScraperService {
  ArticleScraperService(this._client, this._logger);

  final http.Client _client;
  final StructuredLogger _logger;

  static const String _kMobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36 '
      'BDNewsReader/1.0';

  Future<String?> extractArticleContent(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    try {
      _logger.info('🌐 Fetching article: $url');

      final response = await _client
          .get(
            uri,
            headers: const <String, String>{
              'User-Agent': _kMobileUserAgent,
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'bn-BD,bn;q=0.95,en-US;q=0.85,en;q=0.75',
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200 || response.body.isEmpty) {
        debugPrint('⚠️ Failed to fetch article: ${response.statusCode}');
        return null;
      }

      final document = html_parser.parse(response.body);
      final content = _extractMainContent(document, uri);

      if (content == null || content.trim().isEmpty) {
        debugPrint('⚠️ No content extracted from $url');
        return null;
      }

      final cleanedContent = _cleanHtml(content);
      if (cleanedContent.length < 300) {
        debugPrint('⚠️ Extracted content too small for $url');
        return null;
      }

      debugPrint('✅ Extracted ${cleanedContent.length} chars');
      return cleanedContent;
    } catch (e, s) {
      _logger.warning('Article scrape failed', e, s);
      debugPrint('❌ Error scraping article: $e');
      return null;
    }
  }

  String? _extractMainContent(Document doc, Uri uri) {
    final selectors = <String>[
      ..._hostSelectors(uri.host.toLowerCase()),
      'article',
      'main article',
      '[itemprop*="articleBody"]',
      '[role="main"] article',
      '.article-body',
      '.article-content',
      '.post-content',
      '.entry-content',
      '.content-body',
      '.story-body',
      '.story-content',
      '.news-content',
      '.article__body',
      '.post__content',
      '.details',
      '.section-content',
      '.article-details',
      'main',
      '[role="main"]',
      'body',
    ];

    Element? bestRoot;
    var bestScore = -1 << 30;
    final seen = <Element>{};

    for (final selector in selectors) {
      for (final element in doc.querySelectorAll(selector)) {
        if (!seen.add(element)) continue;
        final candidate = _prepareCandidate(element);
        if (candidate == null) continue;
        final score = _scoreCandidate(candidate);
        if (score > bestScore) {
          bestScore = score;
          bestRoot = candidate;
        }
      }
    }

    if (bestRoot == null) {
      debugPrint('   ❌ No suitable content found');
      return null;
    }

    final textLength = _normalizedText(bestRoot.text).length;
    final paragraphCount = bestRoot.querySelectorAll('p').length;
    if (textLength < 320 || paragraphCount < 2) {
      debugPrint('   ❌ Best candidate too small');
      return null;
    }

    return bestRoot.outerHtml;
  }

  List<String> _hostSelectors(String host) {
    if (host.contains('prothomalo.com')) {
      return const <String>[
        'article',
        'div[itemprop="articleBody"]',
        '.story-content',
        '.story-body',
        '.story-element.story-element-text',
      ];
    }
    if (host.contains('bd-pratidin.com')) {
      return const <String>[
        'article',
        '.details',
        '.news-content',
        '[itemprop="articleBody"]',
      ];
    }
    if (host.contains('thedailystar.net')) {
      return const <String>['article', '.article-body', '.section-content'];
    }
    if (host.contains('dhakatribune.com')) {
      return const <String>['article', '.section-content', '.article-content'];
    }
    if (host.contains('bbc.com') || host.contains('bbc.co.uk')) {
      return const <String>[
        'article',
        '[data-component="text-block"]',
        '.story-body__inner',
      ];
    }
    if (host.contains('banglanews24.com')) {
      return const <String>[
        'article',
        '.news-article-content',
        '.article-details',
      ];
    }
    return const <String>[];
  }

  Element? _prepareCandidate(Element element) {
    final candidate = element.clone(true);
    _removeNoise(candidate);

    final text = _normalizedText(candidate.text);
    if (text.length < 180) return null;

    final paragraphs = candidate.querySelectorAll('p').length;
    final anchors = candidate.querySelectorAll('a');
    final anchorTextLength = anchors.fold<int>(
      0,
      (sum, anchor) => sum + _normalizedText(anchor.text).length,
    );
    final linkDensity = anchorTextLength / text.length.clamp(1, 1 << 20);

    if (paragraphs == 0 && text.length < 300) return null;
    if (linkDensity > 0.55) return null;
    return candidate;
  }

  int _scoreCandidate(Element element) {
    final text = _normalizedText(element.text);
    final paragraphs = element.querySelectorAll('p').length;
    final anchors = element.querySelectorAll('a');
    final shortAnchors = anchors
        .where(
          (anchor) => _normalizedText(anchor.text)
              .split(RegExp(r'\s+'))
              .where((word) => word.isNotEmpty)
              .length <=
              8,
        )
        .length;
    final anchorTextLength = anchors.fold<int>(
      0,
      (sum, anchor) => sum + _normalizedText(anchor.text).length,
    );
    final linkDensity = anchorTextLength / text.length.clamp(1, 1 << 20);
    final listItems = element.querySelectorAll('li').length;

    return text.length +
        (paragraphs * 145) -
        (linkDensity * 1200).round() -
        (shortAnchors * 36) -
        (listItems * 16);
  }

  void _removeNoise(Element root) {
    const selectors = <String>[
      'script',
      'style',
      'noscript',
      'iframe',
      'embed',
      'object',
      'nav',
      'header',
      'footer',
      'aside',
      'form',
      'button',
      'svg',
      'canvas',
      '.sidebar',
      '.advertisement',
      '.ad',
      '.ads',
      '.promo',
      '.sponsored',
      '.social-share',
      '.share-tools',
      '.related',
      '.related-news',
      '.recommended',
      '.trending',
      '.comments',
      '.comment-section',
      '.newsletter',
      '.subscribe',
      '.cookie',
      '.cookie-banner',
      '.consent',
      '.popup',
      '.overlay',
      '[role="navigation"]',
      '[role="complementary"]',
      '[class*="sponsor"]',
      '[id*="sponsor"]',
      '[class*="advert"]',
      '[id*="advert"]',
      '[class*="cookie"]',
      '[id*="cookie"]',
      '[class*="consent"]',
      '[id*="consent"]',
      '[class*="popup"]',
      '[id*="popup"]',
      '[class*="overlay"]',
      '[id*="overlay"]',
    ];

    for (final selector in selectors) {
      root.querySelectorAll(selector).forEach((element) => element.remove());
    }

    final allElements = List<Element>.from(root.querySelectorAll('*'));
    for (final element in allElements) {
      final marker = _normalizedText(
        '${element.className} ${element.id} ${element.attributes['aria-label'] ?? ''}',
      ).toLowerCase();
      final text = _normalizedText(element.text).toLowerCase();
      if (text.isEmpty) continue;

      final anchorCount = element.querySelectorAll('a').length;
      final listItemCount = element.querySelectorAll('li').length;
      final looksLikeNoise = marker.contains('related') ||
          marker.contains('recommend') ||
          marker.contains('trending') ||
          marker.contains('share') ||
          marker.contains('comment') ||
          marker.contains('newsletter') ||
          marker.contains('subscribe');
      final looksLikeHeadlineList = anchorCount >= 4 &&
          listItemCount >= 3 &&
          !RegExp(r'[.!?।]').hasMatch(text);

      if (looksLikeNoise || looksLikeHeadlineList) {
        element.remove();
      }
    }
  }

  String _cleanHtml(String htmlContent) {
    final fragment = html_parser.parseFragment(htmlContent);

    for (final table in fragment.querySelectorAll('table')) {
      _appendInlineStyle(table, 'display:block;overflow-x:auto;width:100%;');
    }
    for (final image in fragment.querySelectorAll('img')) {
      _appendInlineStyle(
        image,
        'max-width:100%;height:auto;display:block;margin:16px auto;',
      );
    }
    for (final paragraph in fragment.querySelectorAll('p,li,blockquote')) {
      _appendInlineStyle(
        paragraph,
        'line-height:1.75;overflow-wrap:anywhere;word-break:break-word;',
      );
    }

    for (final element in fragment.querySelectorAll('*')) {
      final allowedAttrs = <String>{
        'src',
        'srcset',
        'sizes',
        'href',
        'alt',
        'title',
        'style',
        'colspan',
        'rowspan',
      };
      final toRemove = <String>[];
      element.attributes.forEach((key, _) {
        final attrKey = key.toString();
        if (!allowedAttrs.contains(attrKey)) {
          toRemove.add(attrKey);
        }
      });
      for (final attr in toRemove) {
        element.attributes.remove(attr);
      }
    }

    return fragment.outerHtml;
  }

  void _appendInlineStyle(Element element, String style) {
    final current = element.attributes['style']?.trim() ?? '';
    if (current.isEmpty) {
      element.attributes['style'] = style;
      return;
    }
    final separator = current.endsWith(';') ? '' : ';';
    element.attributes['style'] = '$current$separator$style';
  }

  String _normalizedText(String value) {
    return value.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool canScrapeUrl(String url) {
    const problematic = <String>[
      'facebook.com',
      'twitter.com',
      'x.com',
      'instagram.com',
      'youtube.com',
    ];
    return !problematic.any((domain) => url.contains(domain));
  }
}
