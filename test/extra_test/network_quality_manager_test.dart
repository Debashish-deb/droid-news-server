import 'package:flutter_test/flutter_test.dart';
import 'package:bdnewsreader/core/network/network_quality_manager.dart';

void main() {
  group('Network Quality Adaptive Loading', () {
    late NetworkQualityManager manager;

    setUp(() {
      manager = NetworkQualityManager();
      manager.reset();
    });

    test('should use aggressive caching on poor network', () {
      manager.updateQuality(NetworkQuality.poor);

      expect(manager.getArticleLimit(), equals(25)); // Reduced limit
      expect(manager.shouldPrefetch(), isFalse);
      expect(manager.getAdaptiveTimeout(), equals(const Duration(seconds: 30)));
    });

    test('should prefetch on excellent network', () {
      manager.updateQuality(NetworkQuality.excellent);

      expect(manager.shouldPrefetch(), isTrue);
      expect(manager.getArticleLimit(), equals(100));
    });

    test('should handle rapid quality changes without crash', () {
      // Rapid fluctuations
      for (var quality in [
        NetworkQuality.excellent,
        NetworkQuality.offline,
        NetworkQuality.poor,
        NetworkQuality.excellent,
      ]) {
        manager.updateQuality(quality);
        // Should not throw
        manager.getCacheDuration();
        manager.getAdaptiveTimeout();
      }
    });
  });
}
