import 'package:flutter_test/flutter_test.dart';
// Note: We are testing the logic inside WebViewScreen indirectly if possible, 
// but since WebViewScreen is a Widget with private methods, 
// for unit testing we might need to expose them or test via widget tests.
// However, I can create a mock/utility test for the host matching logic.

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
      bool shouldBeConservative(String host) {
        host = host.toLowerCase();
        return host == 'kalerkantho.com' || host.endsWith('.kalerkantho.com') ||
               host == 'prothomalo.com' || host.endsWith('.prothomalo.com') ||
               host == 'thedailystar.net' || host.endsWith('.thedailystar.net') ||
               host == 'bdnews24.com' || host.endsWith('.bdnews24.com') ||
               host == 'dhakatribune.com' || host.endsWith('.dhakatribune.com') ||
               host == 'banglatribune.com' || host.endsWith('.banglatribune.com') ||
               host == 'jugantor.com' || host.endsWith('.jugantor.com') ||
               host == 'manabzamin.com' || host.endsWith('.manabzamin.com') ||
                host == 'tbsnews.net' || host.endsWith('.tbsnews.net') ||
                host == 'engadget.com' || host.endsWith('.engadget.com') ||
                host == 'techcrunch.com' || host.endsWith('.techcrunch.com') ||
                host == 'yahoo.com' || host.endsWith('.yahoo.com');
      }

      final yahooHosts = ['engadget.com', 'techcrunch.com', 'yahoo.com'];
      for (var host in yahooHosts) {
        expect(shouldBeConservative(host), isTrue, reason: 'Failed for Yahoo-group $host');
      }

      for (var host in highPriorityHosts) {
        expect(shouldBeConservative(host), isTrue, reason: 'Failed for $host');
        expect(shouldBeConservative('www.$host'), isTrue, reason: 'Failed for www.$host');
      }

      expect(shouldBeConservative('google.com'), isFalse);
      expect(shouldBeConservative('bbc.com'), isFalse);
    });

    test('Site-specific script distribution logic', () {
      String getScriptForHost(String host) {
        host = host.toLowerCase();
        if (host.contains('prothomalo.com') || host.contains('thedailystar.net')) {
          return 'bangla-specific';
        }
        if (host.contains('theguardian.com') || host.contains('bbc.com') || host.contains('nytimes.com')) {
          return 'international-specific';
        }
        if (host.contains('theverge.com') || host.contains('wired.com') || host.contains('techcrunch.com')) {
          return 'tech-specific';
        }
        return 'default';
      }

      expect(getScriptForHost('prothomalo.com'), equals('bangla-specific'));
      expect(getScriptForHost('www.thedailystar.net'), equals('bangla-specific'));
      expect(getScriptForHost('theguardian.com'), equals('international-specific'));
      expect(getScriptForHost('theverge.com'), equals('tech-specific'));
      expect(getScriptForHost('google.com'), equals('default'));
    });
  });
}
