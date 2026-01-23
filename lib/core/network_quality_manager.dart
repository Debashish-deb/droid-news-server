/// Network quality levels
enum NetworkQuality { excellent, good, fair, poor, offline }

/// Manages network quality monitoring and adaptive behavior
class NetworkQualityManager {
  factory NetworkQualityManager() {
    return _instance;
  }

  NetworkQualityManager._internal();
  NetworkQuality _currentQuality = NetworkQuality.good;

  /// Singleton instance
  static final NetworkQualityManager _instance =
      NetworkQualityManager._internal();

  /// Get current network quality
  NetworkQuality get currentQuality => _currentQuality;

  /// Update network quality based on measurements
  void updateQuality(NetworkQuality quality) {
    _currentQuality = quality;
  }

  /// Check if quality is good enough for operation
  bool isGoodEnough({NetworkQuality minimumRequired = NetworkQuality.fair}) {
    return _currentQuality.index <= minimumRequired.index;
  }

  /// Get cache duration based on network quality
  Duration getCacheDuration() {
    switch (_currentQuality) {
      case NetworkQuality.excellent:
        return const Duration(minutes: 15);
      case NetworkQuality.good:
        return const Duration(minutes: 30);
      case NetworkQuality.fair:
        return const Duration(hours: 1);
      case NetworkQuality.poor:
        return const Duration(hours: 2);
      case NetworkQuality.offline:
        return const Duration(hours: 24);
    }
  }

  /// Get adaptive timeout based on network quality
  Duration getAdaptiveTimeout() {
    switch (_currentQuality) {
      case NetworkQuality.excellent:
        return const Duration(seconds: 5);
      case NetworkQuality.good:
        return const Duration(seconds: 10);
      case NetworkQuality.fair:
        return const Duration(seconds: 15);
      case NetworkQuality.poor:
        return const Duration(seconds: 30);
      case NetworkQuality.offline:
        return const Duration(seconds: 60);
    }
  }

  /// Get image cache width based on data saver mode
  int getImageCacheWidth({required bool dataSaver}) {
    if (dataSaver) {
      return 400; // Reduced size for data saver
    }

    switch (_currentQuality) {
      case NetworkQuality.excellent:
        return 1024; // Reduced from 1200
      case NetworkQuality.good:
        return 800; // Reduced from 1000
      case NetworkQuality.fair:
        return 600; // Reduced from 800
      case NetworkQuality.poor:
        return 400; // Reduced from 600
      case NetworkQuality.offline:
        return 200; // Reduced from 400
    }
  }

  /// Should load images based on data saver mode
  bool shouldLoadImages({required bool dataSaver}) {
    if (dataSaver) {
      return false; // Don't load images in data saver mode
    }
    return _currentQuality != NetworkQuality.offline;
  }

  /// Get article limit based on network quality
  int getArticleLimit() {
    switch (_currentQuality) {
      case NetworkQuality.excellent:
        return 100;
      case NetworkQuality.good:
        return 75;
      case NetworkQuality.fair:
        return 50;
      case NetworkQuality.poor:
        return 25;
      case NetworkQuality.offline:
        return 10;
    }
  }

  /// Get quality description
  String getQualityDescription() {
    switch (_currentQuality) {
      case NetworkQuality.excellent:
        return 'Excellent';
      case NetworkQuality.good:
        return 'Good';
      case NetworkQuality.fair:
        return 'Fair';
      case NetworkQuality.poor:
        return 'Poor';
      case NetworkQuality.offline:
        return 'Offline';
    }
  }

  /// Should prefetch content
  bool shouldPrefetch() {
    return _currentQuality == NetworkQuality.excellent ||
        _currentQuality == NetworkQuality.good;
  }

  /// Reset to default quality
  void reset() {
    _currentQuality = NetworkQuality.good;
  }
}
