import 'package:bdnewsreader/presentation/features/reader/controllers/reader_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reader fallback policy', () {
    test('detects common article URLs and rejects publisher landing pages', () {
      expect(
        looksLikeReaderArticleUrl(
          'https://www.prothomalo.com/world/asia/abc123/example-story-slug',
        ),
        isTrue,
      );
      expect(
        looksLikeReaderArticleUrl(
          'https://www.thedailystar.net/opinion/views/news/example-long-headline-slug-123456',
        ),
        isTrue,
      );
      expect(looksLikeReaderArticleUrl('https://www.prothomalo.com/'), isFalse);
      expect(
        looksLikeReaderArticleUrl('https://www.prothomalo.com/bangladesh'),
        isFalse,
      );
    });

    test(
      'unsupported extraction attempts are allowed only for article-like publisher URLs',
      () {
        expect(
          shouldAttemptUnsupportedReaderExtraction(
            allowPublisherFallback: true,
            likelyArticleUrl: true,
          ),
          isTrue,
        );
        expect(
          shouldAttemptUnsupportedReaderExtraction(
            allowPublisherFallback: true,
            likelyArticleUrl: false,
          ),
          isFalse,
        );
        expect(
          shouldAttemptUnsupportedReaderExtraction(
            allowPublisherFallback: false,
            likelyArticleUrl: true,
          ),
          isFalse,
        );
        expect(
          shouldAttemptUnsupportedReaderExtraction(
            allowPublisherFallback: true,
            likelyArticleUrl: true,
            classifiedPageType: ReaderPageType.liveFeed,
          ),
          isFalse,
        );
      },
    );

    test('unsupported recovery fails closed for publisher landing pages', () {
      expect(
        shouldAllowUnsupportedReaderRecovery(
          allowPublisherFallback: true,
          likelyArticleUrl: false,
          trustedArticleHost: true,
        ),
        isFalse,
      );
    });

    test(
      'unsupported recovery still allows trusted feed articles and article-like URLs',
      () {
        expect(
          shouldAllowUnsupportedReaderRecovery(
            allowPublisherFallback: false,
            likelyArticleUrl: false,
            trustedArticleHost: true,
          ),
          isTrue,
        );
        expect(
          shouldAllowUnsupportedReaderRecovery(
            allowPublisherFallback: true,
            likelyArticleUrl: true,
            trustedArticleHost: false,
          ),
          isTrue,
        );
        expect(
          shouldAllowUnsupportedReaderRecovery(
            allowPublisherFallback: true,
            likelyArticleUrl: true,
            trustedArticleHost: true,
            classifiedPageType: ReaderPageType.liveFeed,
          ),
          isFalse,
        );
      },
    );
  });
}
