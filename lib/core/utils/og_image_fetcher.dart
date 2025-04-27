import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

/// Fetches the best available image from a webpage (og:image or twitter:image).
Future<String?> fetchBestImageFromUrl(String url) async {
  try {
    final http.Response response = await http.get(Uri.parse(url));

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
  } catch (e) {
    print('⚠️ Error fetching image: $e');
    return null;
  }
}
