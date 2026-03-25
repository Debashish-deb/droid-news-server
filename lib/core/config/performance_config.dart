// ============================================================================
// OPTIMIZED PERFORMANCE CONFIG FOR ANDROID
// ============================================================================
// This version includes:
// - Native Android integration via MethodChannel
// - Memory optimization and caching
// - Android-specific device detection
// - Better equality checking
// - Reduced widget rebuilds
// - Async initialization
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Native communication channel for Android performance APIs
const _performanceChannel = MethodChannel('com.newsapp.performance/android');

/// Cached device capabilities to avoid repeated Android API calls
class _DeviceCapabilitiesCache {
  factory _DeviceCapabilitiesCache() => _instance;

  _DeviceCapabilitiesCache._internal();
  static final _instance = _DeviceCapabilitiesCache._internal();

  /// Cached values - null means not yet fetched
  bool? _isLowRam;
  bool? _isBatterySaverEnabled;
  int? _deviceRam;
  String? _deviceBrand;
  int? _androidSdkVersion;
  bool? _isEmulator;

  /// Cache timestamp to refresh periodically
  DateTime? _cacheTime;

  bool get _isCacheValid {
    if (_cacheTime == null) return false;
    return DateTime.now().difference(_cacheTime!).inMinutes < 5;
  }

  /// Fetch from cache or query Android APIs
  Future<bool> getIsLowRam() async {
    if (_isCacheValid && _isLowRam != null) return _isLowRam!;
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android)) {
      return false;
    }
    try {
      _isLowRam =
          await _performanceChannel.invokeMethod<bool>('isLowRamDevice') ??
          false;
      _cacheTime = DateTime.now();
      return _isLowRam!;
    } catch (e) {
      debugPrint('Error fetching isLowRam: $e');
      return false;
    }
  }

  Future<bool> getIsBatterySaverEnabled() async {
    if (_isCacheValid && _isBatterySaverEnabled != null) {
      return _isBatterySaverEnabled!;
    }
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android)) {
      return false;
    }
    try {
      _isBatterySaverEnabled =
          await _performanceChannel.invokeMethod<bool>(
            'isBatterySaverEnabled',
          ) ??
          false;
      _cacheTime = DateTime.now();
      return _isBatterySaverEnabled!;
    } catch (e) {
      debugPrint('Error fetching isBatterySaverEnabled: $e');
      return false;
    }
  }

  Future<int> getTotalRam() async {
    if (_isCacheValid && _deviceRam != null) return _deviceRam!;
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android)) {
      return 4096; // Default to 4GB
    }
    try {
      _deviceRam =
          await _performanceChannel.invokeMethod<int>('getTotalRam') ?? 0;
      _cacheTime = DateTime.now();
      return _deviceRam!;
    } catch (e) {
      debugPrint('Error fetching totalRam: $e');
      return 0;
    }
  }

  Future<String> getDeviceBrand() async {
    if (_isCacheValid && _deviceBrand != null) return _deviceBrand!;
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android)) {
      return 'Generic';
    }
    try {
      _deviceBrand =
          await _performanceChannel.invokeMethod<String>('getDeviceBrand') ??
          'Unknown';
      _cacheTime = DateTime.now();
      return _deviceBrand!;
    } catch (e) {
      debugPrint('Error fetching deviceBrand: $e');
      return 'Unknown';
    }
  }

  Future<int> getAndroidSdkVersion() async {
    if (_isCacheValid && _androidSdkVersion != null) return _androidSdkVersion!;
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android)) return 0;
    try {
      _androidSdkVersion =
          await _performanceChannel.invokeMethod<int>('getAndroidSdkVersion') ??
          0;
      _cacheTime = DateTime.now();
      return _androidSdkVersion!;
    } catch (e) {
      debugPrint('Error fetching androidSdkVersion: $e');
      return 0;
    }
  }

  Future<bool> getIsEmulator() async {
    if (_isCacheValid && _isEmulator != null) return _isEmulator!;
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android)) {
      return false;
    }
    try {
      _isEmulator =
          await _performanceChannel.invokeMethod<bool>('isEmulator') ?? false;
      _cacheTime = DateTime.now();
      return _isEmulator!;
    } catch (e) {
      debugPrint('Error fetching isEmulator: $e');
      return false;
    }
  }
}

/// Represents device performance profile
enum DevicePerformanceTier {
  flagship, // High-end device (>8GB RAM, latest SDK)
  midRange, // Mid-range device (4-8GB RAM)
  budget, // Budget device (<4GB RAM)
  lowEnd, // Very low-end device (<2GB RAM or battery saver enabled)
}

/// Optimized Inherited configuration for Android performance settings
class PerformanceConfig extends InheritedWidget {
  /// Create from defaults (synchronous)
  factory PerformanceConfig.defaults({required Widget child}) {
    return PerformanceConfig._(
      reduceMotion: false,
      reduceEffects: false,
      dataSaver: false,
      lowPowerMode: false,
      performanceTier: DevicePerformanceTier.midRange,
      isLowRamDevice: false,
      isBatterySaverEnabled: false,
      totalRam: 4096,
      androidSdkVersion: 30,
      isEmulator: false,
      child: child,
    );
  }

  /// Create from provided metrics (synchronous - used in build methods)
  factory PerformanceConfig.autoDetectSync({
    required Widget child,
    required bool reduceMotion,
    required bool reduceEffects,
    required bool dataSaver,
    required bool isLowRamDevice,
    required bool isBatterySaverEnabled,
    required int totalRam,
    required int androidSdkVersion,
    required bool isEmulator,
    required DevicePerformanceTier performanceTier,
  }) {
    return PerformanceConfig._(
      reduceMotion: reduceMotion,
      reduceEffects: reduceEffects,
      dataSaver: dataSaver,
      lowPowerMode: isBatterySaverEnabled || dataSaver,
      performanceTier: performanceTier,
      isLowRamDevice: isLowRamDevice,
      isBatterySaverEnabled: isBatterySaverEnabled,
      totalRam: totalRam,
      androidSdkVersion: androidSdkVersion,
      isEmulator: isEmulator,
      child: child,
    );
  }

  /// Private constructor for factory methods
  PerformanceConfig._({
    required this.reduceMotion,
    required this.reduceEffects,
    required this.dataSaver,
    required this.lowPowerMode,
    required this.performanceTier,
    required this.isLowRamDevice,
    required this.isBatterySaverEnabled,
    required this.totalRam,
    required this.androidSdkVersion,
    required this.isEmulator,
    required super.child,
    super.key,
  });

  final bool reduceMotion;
  final bool reduceEffects;
  final bool dataSaver;
  final bool lowPowerMode;
  final DevicePerformanceTier performanceTier;
  final bool isLowRamDevice;
  final bool isBatterySaverEnabled;
  final int totalRam; // in MB
  final int androidSdkVersion;
  final bool isEmulator;

  /// Cached computed value to avoid recalculation
  late final bool _isLowEndDevice =
      lowPowerMode ||
      reduceEffects ||
      reduceMotion ||
      isLowRamDevice ||
      performanceTier == DevicePerformanceTier.lowEnd;

  /// Whether the device is considered low-end or performance-constrained
  bool get isLowEndDevice => _isLowEndDevice;

  /// Whether to disable heavy animations and effects
  bool get shouldDisableAnimations =>
      isLowEndDevice || performanceTier == DevicePerformanceTier.budget;

  /// Whether to use lower image quality
  bool get shouldUseLowerImageQuality =>
      dataSaver ||
      performanceTier == DevicePerformanceTier.budget ||
      performanceTier == DevicePerformanceTier.lowEnd;

  /// Whether to limit concurrent network requests
  bool get shouldLimitConcurrentRequests =>
      dataSaver || isBatterySaverEnabled || isLowRamDevice;

  /// Maximum concurrent network connections based on device
  int get maxConcurrentNetworkRequests {
    if (performanceTier == DevicePerformanceTier.lowEnd) return 1;
    if (performanceTier == DevicePerformanceTier.budget) return 2;
    if (performanceTier == DevicePerformanceTier.midRange) return 4;
    return 8;
  }

  /// Cache size in MB based on device capabilities
  int get imageCacheSizeMb {
    if (performanceTier == DevicePerformanceTier.lowEnd) return 25;
    if (performanceTier == DevicePerformanceTier.budget) return 50;
    if (performanceTier == DevicePerformanceTier.midRange) return 100;
    return 200;
  }

  /// Frame rate cap for animations based on device
  int get maxFrameRate {
    if (performanceTier == DevicePerformanceTier.lowEnd) return 30;
    if (performanceTier == DevicePerformanceTier.budget) return 30;
    return 60;
  }

  /// Create with auto-detection from Android (async)
  static Future<PerformanceConfig> autoDetect({
    required Widget child,
    bool reduceMotion = false,
    bool reduceEffects = false,
    bool dataSaver = false,
  }) async {
    final cache = _DeviceCapabilitiesCache();

    try {
      final isLowRam = await cache.getIsLowRam();
      final isBatterySaver = await cache.getIsBatterySaverEnabled();
      final totalRam = await cache.getTotalRam();
      final sdkVersion = await cache.getAndroidSdkVersion();
      final isEmulator = await cache.getIsEmulator();

      // Determine performance tier
      final tier = _determinePerformanceTier(
        totalRam: totalRam,
        sdkVersion: sdkVersion,
        isBatterySaver: isBatterySaver,
        isLowRam: isLowRam,
      );

      return PerformanceConfig._(
        reduceMotion: reduceMotion,
        reduceEffects: reduceEffects,
        dataSaver: dataSaver,
        lowPowerMode: isBatterySaver || dataSaver,
        performanceTier: tier,
        isLowRamDevice: isLowRam,
        isBatterySaverEnabled: isBatterySaver,
        totalRam: totalRam,
        androidSdkVersion: sdkVersion,
        isEmulator: isEmulator,
        child: child,
      );
    } catch (e) {
      debugPrint('Error in autoDetect: $e, using defaults');
      return PerformanceConfig.defaults(child: child);
    }
  }

  /// Returns a new [PerformanceConfig] with selected fields replaced.
  ///
  /// This is used by app-level builders to reuse the current config values
  /// while swapping only the subtree [child].
  PerformanceConfig copyWith({
    bool? reduceMotion,
    bool? reduceEffects,
    bool? dataSaver,
    bool? lowPowerMode,
    DevicePerformanceTier? performanceTier,
    bool? isLowRamDevice,
    bool? isBatterySaverEnabled,
    int? totalRam,
    int? androidSdkVersion,
    bool? isEmulator,
    Widget? child,
    Key? key,
  }) {
    final nextDataSaver = dataSaver ?? this.dataSaver;
    final nextBatterySaver =
        isBatterySaverEnabled ?? this.isBatterySaverEnabled;

    return PerformanceConfig._(
      reduceMotion: reduceMotion ?? this.reduceMotion,
      reduceEffects: reduceEffects ?? this.reduceEffects,
      dataSaver: nextDataSaver,
      lowPowerMode: lowPowerMode ?? (nextBatterySaver || nextDataSaver),
      performanceTier: performanceTier ?? this.performanceTier,
      isLowRamDevice: isLowRamDevice ?? this.isLowRamDevice,
      isBatterySaverEnabled: nextBatterySaver,
      totalRam: totalRam ?? this.totalRam,
      androidSdkVersion: androidSdkVersion ?? this.androidSdkVersion,
      isEmulator: isEmulator ?? this.isEmulator,
      key: key ?? this.key,
      child: child ?? this.child,
    );
  }

  /// Determine performance tier based on device specs
  static DevicePerformanceTier _determinePerformanceTier({
    required int totalRam,
    required int sdkVersion,
    required bool isBatterySaver,
    required bool isLowRam,
  }) {
    if (isBatterySaver || isLowRam) {
      return DevicePerformanceTier.lowEnd;
    }

    if (totalRam >= 8000) {
      return DevicePerformanceTier.flagship;
    } else if (totalRam >= 4000) {
      return DevicePerformanceTier.midRange;
    } else if (totalRam >= 2000) {
      return DevicePerformanceTier.budget;
    } else {
      return DevicePerformanceTier.lowEnd;
    }
  }

  static PerformanceConfig? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PerformanceConfig>();
  }

  static PerformanceConfig of(BuildContext context) {
    return maybeOf(context) ??
        PerformanceConfig.defaults(child: const SizedBox.shrink());
  }

  @override
  bool updateShouldNotify(PerformanceConfig oldWidget) {
    if (identical(this, oldWidget)) return false;

    return reduceMotion != oldWidget.reduceMotion ||
        reduceEffects != oldWidget.reduceEffects ||
        dataSaver != oldWidget.dataSaver ||
        lowPowerMode != oldWidget.lowPowerMode ||
        performanceTier != oldWidget.performanceTier ||
        isLowRamDevice != oldWidget.isLowRamDevice ||
        isEmulator != oldWidget.isEmulator;
  }
}
