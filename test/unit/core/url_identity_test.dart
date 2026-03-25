import 'package:bdnewsreader/core/utils/url_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UrlIdentity', () {
    test('canonicalize normalizes host, query order, and tracking params', () {
      final canonical = UrlIdentity.canonicalize(
        'HTTPS://Example.com/path/?utm_source=app&b=2&a=1&ref=home',
      );

      expect(canonical, 'https://example.com/path?a=1&b=2');
    });

    test('idFromUrl stays stable across equivalent URLs', () {
      final first = UrlIdentity.idFromUrl(
        'https://example.com/news/story?utm_source=a&x=1',
      );
      final second = UrlIdentity.idFromUrl(
        'https://example.com/news/story?x=1',
      );

      expect(first, second);
    });

    test('canonicalize falls back safely for malformed URLs', () {
      final canonical = UrlIdentity.canonicalize(' Not A Valid URL ');
      expect(canonical, 'not a valid url');
    });
  });
}
