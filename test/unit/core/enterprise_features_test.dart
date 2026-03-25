import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:bdnewsreader/bootstrap/config/feature_flags/feature_flag_service.dart';
import 'package:bdnewsreader/bootstrap/config/feature_flags/app_features.dart';
import 'package:bdnewsreader/core/telemetry/performance_monitor.dart';

@GenerateMocks([FirebaseRemoteConfig])
import 'enterprise_features_test.mocks.dart';

void main() {
  group('Enterprise Feature Verification', () {
    late MockFirebaseRemoteConfig mockRemoteConfig;
    late FeatureFlagService featureFlagService;

    setUp(() {
      mockRemoteConfig = MockFirebaseRemoteConfig();
      featureFlagService = FeatureFlagService(remoteConfig: mockRemoteConfig);
      when(mockRemoteConfig.getBool(any)).thenReturn(false);
      when(mockRemoteConfig.fetchAndActivate()).thenAnswer((_) async => true);
      when(mockRemoteConfig.setDefaults(any)).thenAnswer((_) async {});
      when(mockRemoteConfig.setConfigSettings(any)).thenAnswer((_) async {});
    });

    test('FeatureFlagService returns correct boolean value', () {
      // Arrange
      when(mockRemoteConfig.getBool('enable_ads')).thenReturn(false);

      // Act
      final isEnabled = featureFlagService.isEnabled(AppFeatures.enable_ads);

      // Assert
      expect(isEnabled, false);
      verify(mockRemoteConfig.getBool('enable_ads')).called(1);
    });

    test('FeatureFlagService falls back to safe defaults on initialization failure', () async {
      // Arrange
      when(mockRemoteConfig.fetchAndActivate()).thenThrow(Exception('Network Error'));

      // Act
      await featureFlagService.initialize();

      // Assert
      // Should not throw, allowing app to proceed with defaults
      verify(mockRemoteConfig.setDefaults({
        AppFeatures.enable_news_threading.key: false,
        AppFeatures.enable_smart_ranking.key: false,
        AppFeatures.enable_perf_monitoring.key: false,
        AppFeatures.enable_ads.key: true,
        AppFeatures.enable_new_magazine_ui.key: true,
      })).called(1);
    });

    test('PerformanceMonitor works correctly', () async {
      // This is a behavioral test to ensure no exceptions occur
      final monitor = PerformanceMonitor.start('test_metric');
      await Future.delayed(const Duration(milliseconds: 10));
      monitor.stop();
      // If no exception, passed.
    });
   
    test('AppFeatures Enum mapping is correct', () {
      expect(AppFeatures.enable_news_threading.key, 'enable_news_threading');
    });
  });
}
