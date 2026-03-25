import 'package:bdnewsreader/core/navigation/url_safety_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid https URLs open in-app', () {
    final decision = UrlSafetyPolicy.evaluate('https://example.com/news');

    expect(decision.disposition, UrlSafetyDisposition.allowInApp);
    expect(decision.uri, isNotNull);
  });

  test('unsafe schemes are rejected', () {
    const urls = <String>[
      'javascript:alert(1)',
      'data:text/plain;base64,SGVsbG8=',
      'file:///etc/passwd',
      'content://local/file',
      'intent://scan/#Intent;scheme=zxing;package=com.example;end',
      'not a valid url',
    ];

    for (final url in urls) {
      expect(
        UrlSafetyPolicy.evaluate(url).disposition,
        UrlSafetyDisposition.reject,
      );
    }
  });

  test('external action schemes are routed externally', () {
    expect(
      UrlSafetyPolicy.evaluate('mailto:hello@example.com').disposition,
      UrlSafetyDisposition.openExternal,
    );
    expect(
      UrlSafetyPolicy.evaluate('tel:+123456789').disposition,
      UrlSafetyDisposition.openExternal,
    );
  });
}
