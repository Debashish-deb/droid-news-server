import 'dart:io';
import 'dart:convert';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:logger/logger.dart';
import '../security/ssl_pinning.dart';

final Logger logger = Logger();

/// Fetches the best available image from a webpage (og:image or twitter:image).
Future<String?> fetchBestImageFromUrl(String url) async {
  try {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return null;
    }

    final HttpClient client = SSLPinning.getHttpClientFor(uri);
    final HttpClientRequest request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 10));

    final HttpClientResponse response = await request.close().timeout(
      const Duration(seconds: 10),
    );

    if (response.statusCode == 200) {
      final String body = await response.transform(utf8.decoder).join();
      final Document document = html_parser.parse(body);

      final Element? ogImageMeta = document.querySelector(
        'meta[property="og:image"]',
      );
      if (ogImageMeta != null && ogImageMeta.attributes['content'] != null) {
        return ogImageMeta.attributes['content'];
      }

      final Element? twitterImageMeta = document.querySelector(
        'meta[name="twitter:image"]',
      );
      if (twitterImageMeta != null &&
          twitterImageMeta.attributes['content'] != null) {
        return twitterImageMeta.attributes['content'];
      }
    }

    return null;
  } catch (e, stackTrace) {
    logger.e(
      'Error fetching image from URL: $url',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}
