import 'package:bdnewsreader/presentation/features/common/publisher_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolvePublisherUrl', () {
    test('extracts markdown publisher website links', () {
      final url = resolvePublisherUrl({
        'contact': {
          'website': '[Alokito Bangladesh](http://www.alokitobangladesh.com/)',
        },
      });

      expect(url, 'https://www.alokitobangladesh.com/');
    });

    test('normalizes bare www publisher links', () {
      final url = resolvePublisherUrl({
        'contact': {'website': 'www.example.com/news'},
      });

      expect(url, 'https://www.example.com/news');
    });

    test('falls back to url field when website is not usable', () {
      final url = resolvePublisherUrl({
        'contact': {'website': 'N/A'},
        'url': 'https://example.com',
      });

      expect(url, 'https://example.com');
    });

    test('ignores accidental asset paths and falls back to link field', () {
      final url = resolvePublisherUrl({
        'contact': {'website': 'assets/logos/publisher.png'},
        'link': 'https://example.com/publisher',
      });

      expect(url, 'https://example.com/publisher');
    });

    test('drops malformed publisher website values', () {
      final url = resolvePublisherUrl({
        'contact': {'website': 'httpsmissing-scheme.com'},
      });

      expect(url, isEmpty);
    });
  });
}
