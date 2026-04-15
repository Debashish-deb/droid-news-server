import 'package:bdnewsreader/presentation/features/common/webview_screen.dart';
import 'package:bdnewsreader/infrastructure/network/app_network_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebView reader readiness', () {
    test(
      'blocks reader entry until controller exists and load has settled',
      () {
        final now = DateTime(2026, 4, 1, 12);

        expect(
          isReaderSourceReadyForToggle(
            hasController: false,
            mainFrameLoading: false,
            lastLoadStopAt: now.subtract(const Duration(seconds: 2)),
            settleDelay: const Duration(milliseconds: 650),
            now: now,
          ),
          isFalse,
        );

        expect(
          isReaderSourceReadyForToggle(
            hasController: true,
            mainFrameLoading: true,
            lastLoadStopAt: now.subtract(const Duration(seconds: 2)),
            settleDelay: const Duration(milliseconds: 650),
            now: now,
          ),
          isFalse,
        );

        expect(
          isReaderSourceReadyForToggle(
            hasController: true,
            mainFrameLoading: false,
            lastLoadStopAt: now.subtract(const Duration(milliseconds: 250)),
            settleDelay: const Duration(milliseconds: 650),
            now: now,
          ),
          isFalse,
        );

        expect(
          isReaderSourceReadyForToggle(
            hasController: true,
            mainFrameLoading: false,
            lastLoadStopAt: now.subtract(const Duration(seconds: 1)),
            settleDelay: const Duration(milliseconds: 650),
            now: now,
          ),
          isTrue,
        );
      },
    );

    test('global loading overlay only shows while reader mode is active', () {
      expect(
        shouldShowReaderLoadingOverlay(isReader: true, isLoading: true),
        isTrue,
      );
      expect(
        shouldShowReaderLoadingOverlay(isReader: false, isLoading: true),
        isFalse,
      );
      expect(
        shouldShowReaderLoadingOverlay(isReader: true, isLoading: false),
        isFalse,
      );
    });

    test('promotes WebView to visually ready after high-progress plateau', () {
      final now = DateTime(2026, 4, 1, 12);

      expect(
        shouldPromoteWebViewToVisuallyReady(
          mainFrameLoading: true,
          progress: 0.98,
          loadStartedAt: now.subtract(const Duration(seconds: 6)),
          lastProgressChangedAt: now.subtract(const Duration(seconds: 3)),
          plateauDelay: const Duration(seconds: 2),
          minLoadTime: const Duration(seconds: 4),
          now: now,
        ),
        isTrue,
      );

      expect(
        shouldPromoteWebViewToVisuallyReady(
          mainFrameLoading: true,
          progress: 0.94,
          loadStartedAt: now.subtract(const Duration(seconds: 6)),
          lastProgressChangedAt: now.subtract(const Duration(seconds: 3)),
          plateauDelay: const Duration(seconds: 2),
          minLoadTime: const Duration(seconds: 4),
          now: now,
        ),
        isFalse,
      );

      expect(
        shouldPromoteWebViewToVisuallyReady(
          mainFrameLoading: true,
          progress: 0.98,
          loadStartedAt: now.subtract(const Duration(seconds: 3)),
          lastProgressChangedAt: now.subtract(const Duration(seconds: 3)),
          plateauDelay: const Duration(seconds: 2),
          minLoadTime: const Duration(seconds: 4),
          now: now,
        ),
        isFalse,
      );

      expect(
        shouldPromoteWebViewToVisuallyReady(
          mainFrameLoading: false,
          progress: 0.98,
          loadStartedAt: now.subtract(const Duration(seconds: 6)),
          lastProgressChangedAt: now.subtract(const Duration(seconds: 3)),
          plateauDelay: const Duration(seconds: 2),
          minLoadTime: const Duration(seconds: 4),
          now: now,
        ),
        isFalse,
      );
    });

    test('lightweight WebView mode turns on for constrained conditions', () {
      expect(
        shouldUseLightweightWebViewMode(
          isPublisherMode: false,
          dataSaver: true,
          lowPowerMode: false,
          isLowEndDevice: false,
          networkQuality: NetworkQuality.good,
        ),
        isTrue,
      );

      expect(
        shouldUseLightweightWebViewMode(
          isPublisherMode: true,
          dataSaver: false,
          lowPowerMode: false,
          isLowEndDevice: false,
          networkQuality: NetworkQuality.fair,
        ),
        isTrue,
      );

      expect(
        shouldUseLightweightWebViewMode(
          isPublisherMode: false,
          dataSaver: false,
          lowPowerMode: false,
          isLowEndDevice: false,
          networkQuality: NetworkQuality.good,
        ),
        isFalse,
      );
    });

    test('blocks http subresources on https pages', () {
      expect(
        shouldBlockCleartextSubresource(
          pageUri: Uri.parse('https://www.abnews24bd.com/story'),
          requestUri: Uri.parse('http://www.abnews24bd.com/assets/main.js'),
        ),
        isTrue,
      );

      expect(
        shouldBlockCleartextSubresource(
          pageUri: Uri.parse('https://www.abnews24bd.com/story'),
          requestUri: Uri.parse('https://www.abnews24bd.com/assets/main.js'),
        ),
        isFalse,
      );

      expect(
        shouldBlockCleartextSubresource(
          pageUri: Uri.parse('http://www.abnews24bd.com/story'),
          requestUri: Uri.parse('http://www.abnews24bd.com/assets/main.js'),
        ),
        isFalse,
      );
    });

    test('auto TTS advance stays reader-feed only', () {
      expect(
        shouldAutoAdvanceReaderTts(
          autoPlayEnabled: true,
          isPublisherOrigin: false,
          isReaderMode: true,
          hasNextArticle: true,
          navigationInFlight: false,
          unlockPromptInFlight: false,
        ),
        isTrue,
      );

      expect(
        shouldAutoAdvanceReaderTts(
          autoPlayEnabled: true,
          isPublisherOrigin: true,
          isReaderMode: true,
          hasNextArticle: true,
          navigationInFlight: false,
          unlockPromptInFlight: false,
        ),
        isFalse,
      );

      expect(
        shouldAutoAdvanceReaderTts(
          autoPlayEnabled: false,
          isPublisherOrigin: false,
          isReaderMode: true,
          hasNextArticle: true,
          navigationInFlight: false,
          unlockPromptInFlight: false,
        ),
        isFalse,
      );

      expect(
        shouldAutoAdvanceReaderTts(
          autoPlayEnabled: true,
          isPublisherOrigin: false,
          isReaderMode: true,
          hasNextArticle: false,
          navigationInFlight: false,
          unlockPromptInFlight: false,
        ),
        isFalse,
      );

      expect(
        shouldAutoAdvanceReaderTts(
          autoPlayEnabled: true,
          isPublisherOrigin: false,
          isReaderMode: false,
          hasNextArticle: true,
          navigationInFlight: false,
          unlockPromptInFlight: false,
        ),
        isFalse,
      );

      expect(
        shouldAutoAdvanceReaderTts(
          autoPlayEnabled: true,
          isPublisherOrigin: false,
          isReaderMode: true,
          hasNextArticle: true,
          navigationInFlight: true,
          unlockPromptInFlight: false,
        ),
        isFalse,
      );

      expect(
        shouldAutoAdvanceReaderTts(
          autoPlayEnabled: true,
          isPublisherOrigin: false,
          isReaderMode: true,
          hasNextArticle: true,
          navigationInFlight: false,
          unlockPromptInFlight: true,
        ),
        isFalse,
      );
    });
  });
}
