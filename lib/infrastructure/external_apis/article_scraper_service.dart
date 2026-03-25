import '../../core/telemetry/structured_logger.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:flutter/foundation.dart';

/// Service to extract full article content from web pages for offline reading

class ArticleScraperService {

  ArticleScraperService(this._client, this._logger);
  final http.Client _client;
  final StructuredLogger _logger;

  /// Extract full article content from a URL
  /// Returns cleaned HTML content or null if extraction fails
  Future<String?> extractArticleContent(String url) async {
    try {
      _logger.info('🌐 Fetching article: $url');

      final response = await _client
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'Mozilla/5.0 (compatible; BDNewsReader/1.0)',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('⚠️ Failed to fetch article: ${response.statusCode}');
        return null;
      }

      final Document document = html_parser.parse(response.body);

      final String? content = _extractMainContent(document);

      if (content == null || content.isEmpty) {
        debugPrint('⚠️ No content extracted from $url');
        return null;
      }

      final cleanedContent = _cleanHtml(content);
      debugPrint('✅ Extracted ${cleanedContent.length} chars');
      return cleanedContent;
    } catch (e) {
      debugPrint('❌ Error scraping article: $e');
      return null;
    }
  }

  /// Extract main article content using multiple strategies
  String? _extractMainContent(Document doc) {
    final article = doc.querySelector('article');
    if (article != null) {
      debugPrint('   📄 Found <article> tag');
      return article.outerHtml;
    }

    final commonClasses = [
      '.article-body',
      '.article-content',
      '.post-content',
      '.entry-content',
      '.content-body',
      '.story-body',
      '.article__body',
      '.post__content',
      '.news-content',
    ];

    for (final className in commonClasses) {
      final element = doc.querySelector(className);
      if (element != null && element.text.length > 200) {
        debugPrint('   📄 Found content via class: $className');
        return element.outerHtml;
      }
    }

    final divs = doc.querySelectorAll('div');
    Element? bestDiv;
    int maxParagraphs = 0;

    for (final div in divs) {
      final paragraphs = div.querySelectorAll('p');
      if (paragraphs.length > maxParagraphs) {
        maxParagraphs = paragraphs.length;
        bestDiv = div;
      }
    }

    if (bestDiv != null && maxParagraphs >= 3) {
      debugPrint('   📄 Found content via largest div (${maxParagraphs}p)');
      return bestDiv.outerHtml;
    }

    debugPrint('   ❌ No suitable content found');
    return null;
  }

  /// Clean HTML by removing unwanted elements and attributes
  String _cleanHtml(String htmlContent) {
    final doc = html_parser.parseFragment(htmlContent);

    final unwantedSelectors = [
      'script', 'style', 'noscript',
      'iframe', 'embed', 'object',
      'nav', 'header', 'footer',
      'aside', '.sidebar',
      '.advertisement', '.ad',
      '.social-share', '.related',
      '.comments', '.comment-section',
    ];

    for (final selector in unwantedSelectors) {
      doc.querySelectorAll(selector).forEach((el) => el.remove());
    }

    for (final element in doc.querySelectorAll('*')) {
      final allowedAttrs = ['src', 'href', 'alt', 'title'];
      final attrsToRemove = <String>[];

      element.attributes.forEach((key, value) {
        final String attrKey = key.toString();
        if (!allowedAttrs.contains(attrKey)) {
          attrsToRemove.add(attrKey);
        }
      });

      for (final attr in attrsToRemove) {
        element.attributes.remove(attr);
      }
    }

    return doc.outerHtml;
  }

  /// Test if a URL is likely to work with scraping
  bool canScrapeUrl(String url) {
    final problematic = ['facebook.com', 'twitter.com', 'instagram.com'];
    return !problematic.any((domain) => url.contains(domain));
  }
}
