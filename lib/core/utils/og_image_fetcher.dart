import 'package:html/dom.dart';
import 'package:http/http.dart' as https;
import 'package:html/parser.dart' as html_parser;
import 'package:logger/logger.dart';

final Logger logger = Logger();

/// Fetches the best available image from a webpage (og:image or twitter:image).
Future<String?> fetchBestImageFromUrl(String url) async {
  try {
    final https.Response response = await https.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final Document document = html_parser.parse(response.body);

      // Try Open Graph image first
      final Element? ogImageMeta = document.querySelector('meta[property="og:image"]');
      if (ogImageMeta != null && ogImageMeta.attributes['content'] != null) {
        return ogImageMeta.attributes['content'];
      }

      // Fallback: Try Twitter Card image
      final Element? twitterImageMeta = document.querySelector('meta[name="twitter:image"]');
      if (twitterImageMeta != null && twitterImageMeta.attributes['content'] != null) {
        return twitterImageMeta.attributes['content'];
      }
    }

    return null; // No image found
  } catch (e, stackTrace) {
    logger.e('Error fetching image from URL: $url', error: e, stackTrace: stackTrace);
    return null;
  }
}
