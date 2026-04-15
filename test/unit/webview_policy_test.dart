import 'package:bdnewsreader/core/utils/webview_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebView policy helpers', () {
    test('compares common publisher subdomains as the same site', () {
      final articleUri = Uri.parse(
        'https://edition.cnn.com/2026/03/30/world/live-news/example-story',
      );
      final detourUri = Uri.parse('https://www.cnn.com/your-privacy-choices');

      expect(isLikelySamePublisherHost(articleUri, detourUri), isTrue);
    });

    test('detects cookie or privacy detours on the same publisher', () {
      final articleUri = Uri.parse(
        'https://edition.cnn.com/2026/03/30/world/live-news/example-story',
      );

      expect(
        isConsentManagementDetour(
          targetUri: Uri.parse('https://www.cnn.com/your-privacy-choices'),
          articleUri: articleUri,
        ),
        isTrue,
      );
      expect(
        isConsentManagementDetour(
          targetUri: Uri.parse(
            'https://edition.cnn.com/privacy-center/manage-cookies',
          ),
          articleUri: articleUri,
        ),
        isTrue,
      );
    });

    test('does not flag normal article navigation as a consent detour', () {
      final articleUri = Uri.parse(
        'https://edition.cnn.com/2026/03/30/world/live-news/example-story',
      );

      expect(
        isConsentManagementDetour(
          targetUri: Uri.parse(
            'https://edition.cnn.com/2026/03/30/tech/privacy-scandal-explainer',
          ),
          articleUri: articleUri,
        ),
        isFalse,
      );
      expect(
        isConsentManagementDetour(
          targetUri: Uri.parse(
            'https://edition.cnn.com/2026/03/30/world/live-news/example-story#live-updates',
          ),
          articleUri: articleUri,
        ),
        isFalse,
      );
    });

    test('does not treat subscription pages as consent detours', () {
      final articleUri = Uri.parse(
        'https://edition.cnn.com/2026/03/30/world/live-news/example-story',
      );

      expect(
        isConsentManagementDetour(
          targetUri: Uri.parse('https://www.cnn.com/account/subscribe'),
          articleUri: articleUri,
        ),
        isFalse,
      );
    });

    test('blocks heavy third-party subresources in lightweight mode', () {
      final pageUri = Uri.parse(
        'https://www.prothomalo.com/world/asia/example-story',
      );

      expect(
        shouldBlockHeavyThirdPartySubresource(
          pageUri: pageUri,
          requestUri: Uri.parse('https://fonts.gstatic.com/s/inter.woff2'),
          adBlockingEnabled: false,
          dataSaver: false,
          lightweightMode: true,
        ),
        isTrue,
      );

      expect(
        shouldBlockHeavyThirdPartySubresource(
          pageUri: pageUri,
          requestUri: Uri.parse('https://www.prothomalo.com/assets/app.css'),
          adBlockingEnabled: false,
          dataSaver: false,
          lightweightMode: true,
        ),
        isFalse,
      );

      expect(
        shouldBlockHeavyThirdPartySubresource(
          pageUri: pageUri,
          requestUri: Uri.parse('https://cdn.example.com/hero.jpg'),
          adBlockingEnabled: false,
          dataSaver: true,
          lightweightMode: false,
        ),
        isTrue,
      );
    });
  });
}
