import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:bdnewsreader/core/utils/webview_blocking.dart';

void main() {
  group('WebView Content Blocking Config', () {
    test('Ad URL regex matches common ad domains', () {
      final RegExp regex = RegExp(kAdUrlFilterPattern);

      expect(
        regex.hasMatch('https://googleads.g.doubleclick.net/pagead/ads'),
        isTrue,
      );
      expect(
        regex.hasMatch('https://www.googlesyndication.com/safeframe'),
        isTrue,
      );
      expect(regex.hasMatch('https://cdn.taboola.com/libtrc/impl.js'), isTrue);
      expect(regex.hasMatch('https://googleadservices.com/test'), isTrue);
    });

    test('Ad URL regex does not match legitimate content', () {
      final RegExp regex = RegExp(kAdUrlFilterPattern);

      expect(regex.hasMatch('https://www.bbc.com/news'), isFalse);
      expect(regex.hasMatch('https://www.prothomalo.com/bangladesh'), isFalse);
      expect(regex.hasMatch('https://my-admin-dashboard.com'), isFalse);
    });

    test('Free tier does not apply aggressive content blockers', () {
      final blockers = buildWebViewContentBlockers(isPremium: false);
      expect(blockers, isEmpty);
    });

    test('Premium tier applies layered content blockers', () {
      final blockers = buildWebViewContentBlockers(isPremium: true);

      expect(blockers, isNotEmpty);
      expect(
        blockers.any((b) => b.action.type == ContentBlockerActionType.BLOCK),
        isTrue,
      );
      expect(
        blockers.any(
          (b) => b.action.type == ContentBlockerActionType.CSS_DISPLAY_NONE,
        ),
        isTrue,
      );
    });
  });
}
