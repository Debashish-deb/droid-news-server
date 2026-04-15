import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AdPlacement { banner, interstitial, rewarded }

// ignore: avoid_classes_with_only_static_members
abstract final class AdUnitConfig {
  static String? _configuredId(String envKey) {
    final value = dotenv.env[envKey]?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static bool get hasAnyConfiguredUnitIds {
    return const <String>[
      'BANNER_AD_UNIT_ID_TEST',
      'INTERSTITIAL_AD_UNIT_ID_TEST',
      'REWARDED_AD_UNIT_ID_TEST',
      'BANNER_AD_UNIT_ID',
      'INTERSTITIAL_AD_UNIT_ID',
      'REWARDED_AD_UNIT_ID',
    ].any((key) => _configuredId(key) != null);
  }

  static String? resolve({
    required AdPlacement placement,
    required String productionEnvKey,
    required String testEnvKey,
  }) {
    final productionId = _configuredId(productionEnvKey);
    final testId = _configuredId(testEnvKey);

    if (!kReleaseMode) {
      return testId ?? productionId;
    }

    if (productionId != null) {
      return productionId;
    }

    debugPrint(
      '[Ads] Release ad unit missing for $placement. '
      'Expected env var $productionEnvKey.',
    );
    return null;
  }
}
