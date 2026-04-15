import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:bdnewsreader/core/utils/webview_policy.dart';

void main() {
  group('WebView Publisher Support Tests', () {
    final highPriorityHosts = [
      'prothomalo.com',
      'thedailystar.net',
      'bdnews24.com',
      'dhakatribune.com',
      'banglatribune.com',
      'jugantor.com',
      'manabzamin.com',
      'tbsnews.net',
    ];

    test('Conservative policy host matching logic', () {
      final yahooHosts = ['engadget.com', 'techcrunch.com', 'yahoo.com'];
      for (var host in yahooHosts) {
        expect(
          isConservativeWebViewHost(Uri.parse('https://$host')),
          isTrue,
          reason: 'Failed for Yahoo-group $host',
        );
      }

      for (var host in highPriorityHosts) {
        expect(
          isConservativeWebViewHost(Uri.parse('https://$host')),
          isTrue,
          reason: 'Failed for $host',
        );
        expect(
          isConservativeWebViewHost(Uri.parse('https://www.$host')),
          isTrue,
          reason: 'Failed for www.$host',
        );
      }

      expect(
        isConservativeWebViewHost(Uri.parse('https://google.com')),
        isFalse,
      );
      expect(isConservativeWebViewHost(Uri.parse('https://bbc.com')), isFalse);
    });

    test(
      'Conservative hosts do not force hybrid composition by themselves',
      () {
        expect(
          shouldUseHybridCompositionForWebView(
            isEmulator: false,
            isLowEndDevice: false,
            lowPowerMode: false,
          ),
          isFalse,
        );
      },
    );

    test('Transient publisher errors are retryable only on main frame', () {
      final transientError = WebResourceError(
        type: WebResourceErrorType.RESET,
        description: 'net_error -101',
      );

      expect(
        shouldRetryTransientPublisherLoad(
          isPublisherMode: true,
          isMainFrame: true,
          hasRetryBudget: true,
          error: transientError,
        ),
        isTrue,
      );

      expect(
        shouldRetryTransientPublisherLoad(
          isPublisherMode: true,
          isMainFrame: false,
          hasRetryBudget: true,
          error: transientError,
        ),
        isFalse,
      );

      expect(
        shouldRetryTransientPublisherLoad(
          isPublisherMode: false,
          isMainFrame: true,
          hasRetryBudget: true,
          error: transientError,
        ),
        isFalse,
      );
    });

    test('Site-specific script distribution logic', () {
      String getScriptForHost(String host) {
        host = host.toLowerCase();
        if (host.contains('prothomalo.com') ||
            host.contains('thedailystar.net')) {
          return 'bangla-specific';
        }
        if (host.contains('theguardian.com') ||
            host.contains('bbc.com') ||
            host.contains('nytimes.com')) {
          return 'international-specific';
        }
        if (host.contains('theverge.com') ||
            host.contains('wired.com') ||
            host.contains('techcrunch.com')) {
          return 'tech-specific';
        }
        return 'default';
      }

      expect(getScriptForHost('prothomalo.com'), equals('bangla-specific'));
      expect(
        getScriptForHost('www.thedailystar.net'),
        equals('bangla-specific'),
      );
      expect(
        getScriptForHost('theguardian.com'),
        equals('international-specific'),
      );
      expect(getScriptForHost('theverge.com'), equals('tech-specific'));
      expect(getScriptForHost('google.com'), equals('default'));
    });
  });
}
