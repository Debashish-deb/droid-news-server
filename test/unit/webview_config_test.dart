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
      expect(
        regex.hasMatch('https://cdn.bilsyndication.com/w/slot.js'),
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

    test('Publisher ad blocking can be disabled explicitly', () {
      final blockers = buildWebViewContentBlockers(enableAdBlocking: false);
      expect(blockers, isEmpty);
    });

    test('Publisher ad blocking applies layered content blockers', () {
      final blockers = buildWebViewContentBlockers(enableAdBlocking: true);

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

    test('Data saver keeps inline article images visible', () {
      final blockers = buildWebViewContentBlockers(
        enableAdBlocking: true,
        dataSaver: true,
      );

      expect(
        blockers.any(
          (b) =>
              b.action.type == ContentBlockerActionType.CSS_DISPLAY_NONE &&
              (b.action.selector ?? '').contains('picture'),
        ),
        isFalse,
      );
      expect(
        blockers.any(
          (b) =>
              b.action.type == ContentBlockerActionType.BLOCK &&
              b.trigger.urlFilter.contains('jpe?g'),
        ),
        isFalse,
      );
    });

    test('Lightweight mode adds third-party cleanup blockers', () {
      final blockers = buildWebViewContentBlockers(
        enableAdBlocking: false,
        lightweightMode: true,
      );

      expect(
        blockers.any(
          (b) =>
              b.action.type == ContentBlockerActionType.BLOCK &&
              b.trigger.urlFilter.contains('fonts\\.gstatic'),
        ),
        isTrue,
      );
      expect(
        blockers.any(
          (b) =>
              b.action.type == ContentBlockerActionType.CSS_DISPLAY_NONE &&
              (b.action.selector ?? '').contains('social-embed'),
        ),
        isTrue,
      );
    });
  });
}
