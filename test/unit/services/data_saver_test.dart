import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/core/network_quality_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Data Saver & Network Quality', () {
    late NetworkQualityManager networkManager;

    setUp(() {
      networkManager = NetworkQualityManager();
    });

    group('Singleton Pattern', () {
      test('TC-UNIT-070: NetworkQualityManager is a singleton', () {
        final instance1 = NetworkQualityManager();
        final instance2 = NetworkQualityManager();
        
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Cache Duration', () {
      test('TC-UNIT-071: getCacheDuration returns a Duration', () {
        final duration = networkManager.getCacheDuration();
        
        expect(duration, isA<Duration>());
        expect(duration.inMinutes, greaterThan(0));
      });

      test('TC-UNIT-072: Cache duration is reasonable', () {
        final duration = networkManager.getCacheDuration();
        
        expect(duration.inMinutes, inInclusiveRange(10, 300)); // 10min to 5hr
      });
    });

    group('Adaptive Timeout', () {
      test('TC-UNIT-073: getAdaptiveTimeout returns a Duration', () {
        final timeout = networkManager.getAdaptiveTimeout();
        
        expect(timeout, isA<Duration>());
        expect(timeout.inSeconds, greaterThan(0));
      });

      test('TC-UNIT-074: Timeout is within reasonable bounds', () {
        final timeout = networkManager.getAdaptiveTimeout();
        
        expect(timeout.inSeconds, inInclusiveRange(5, 60));
      });
    });

    group('Network Quality State', () {
      test('TC-UNIT-075: currentQuality is accessible', () {
        final quality = networkManager.currentQuality;
        
        expect(quality, isA<NetworkQuality>());
      });

      test('TC-UNIT-076: NetworkQuality enum has expected values', () {
        expect(NetworkQuality.values, contains(NetworkQuality.excellent));
        expect(NetworkQuality.values, contains(NetworkQuality.good));
        expect(NetworkQuality.values, contains(NetworkQuality.fair));
        expect(NetworkQuality.values, contains(NetworkQuality.poor));
        expect(NetworkQuality.values, contains(NetworkQuality.offline));
      });
    });

    group('Image Handling', () {
      test('TC-UNIT-077: getImageCacheWidth returns int', () {
        final width = networkManager.getImageCacheWidth(dataSaver: false);
        
        expect(width, isA<int>());
        expect(width, greaterThan(0));
      });

      test('TC-UNIT-078: Data saver mode reduces image width', () {
        final normalWidth = networkManager.getImageCacheWidth(dataSaver: false);
        final dataSaverWidth = networkManager.getImageCacheWidth(dataSaver: true);
        
        expect(dataSaverWidth, lessThanOrEqualTo(normalWidth));
      });

      test('TC-UNIT-079: shouldLoadImages respects data saver', () {
        expect(networkManager.shouldLoadImages(dataSaver: true), isFalse);
      });
    });

    group('Article Limit', () {
      test('TC-UNIT-080: getArticleLimit returns int', () {
        final limit = networkManager.getArticleLimit();
        
        expect(limit, isA<int>());
        expect(limit, greaterThan(0));
      });
    });

    group('Quality Description', () {
      test('TC-UNIT-081: getQualityDescription returns string', () {
        final description = networkManager.getQualityDescription();
        
        expect(description, isA<String>());
        expect(description, isNotEmpty);
      });
    });

    group('Prefetch Logic', () {
      test('TC-UNIT-082: shouldPrefetch returns boolean', () {
        final shouldPrefetch = networkManager.shouldPrefetch();
        
        expect(shouldPrefetch, isA<bool>());
      });
    });
  });
}
