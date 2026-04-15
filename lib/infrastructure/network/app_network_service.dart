// lib/infrastructure/network/app_network_service.dart
// ==========================================
// UNIFIED NETWORK SERVICE
// ==========================================

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/performance_config.dart' show DevicePerformanceTier;

enum NetworkQuality { excellent, good, fair, poor, offline }

class AppNetworkService extends ChangeNotifier {
  AppNetworkService();

  bool _isConnected = true;
  NetworkQuality _currentQuality = NetworkQuality.good;
  DevicePerformanceTier _performanceTier = DevicePerformanceTier.midRange;
  NetworkQuality? _debugOverrideQuality;
  bool? _debugOverrideConnectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityResult _lastTransport = ConnectivityResult.other;
  final List<int> _latencySamplesMs = <int>[];

  bool get isConnected => _debugOverrideConnectivity ?? _isConnected;
  NetworkQuality get currentQuality => _debugOverrideQuality ?? _currentQuality;
  DevicePerformanceTier get performanceTier => _performanceTier;

  bool get isDebugOverrideActive =>
      _debugOverrideQuality != null || _debugOverrideConnectivity != null;

  bool get isDebugSlowNetwork =>
      _debugOverrideQuality == NetworkQuality.poor &&
      (_debugOverrideConnectivity ?? true);

  bool get isDebugOffline => (_debugOverrideConnectivity ?? true) == false;

  String get qualityDescription {
    switch (currentQuality) {
      case NetworkQuality.excellent:
        return 'Excellent (WiFi)';
      case NetworkQuality.good:
        return 'Good (4G/5G)';
      case NetworkQuality.fair:
        return 'Fair (3G/unstable mobile)';
      case NetworkQuality.poor:
        return 'Poor (high latency)';
      case NetworkQuality.offline:
        return 'Offline';
    }
  }

  Future<void> initialize() async {
    await _checkConnectivity();
    _subscription ??= Connectivity().onConnectivityChanged.listen(
      _updateFromResults,
    );

    if (kDebugMode) {
      debugPrint('📡 AppNetworkService initialized');
      debugPrint('   Connected: $_isConnected');
      debugPrint('   Quality: $qualityDescription');
    }
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateFromResults(results);
  }

  ConnectivityResult _pickPrimaryTransport(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none)) {
      return ConnectivityResult.none;
    }
    if (results.contains(ConnectivityResult.wifi)) {
      return ConnectivityResult.wifi;
    }
    if (results.contains(ConnectivityResult.ethernet)) {
      return ConnectivityResult.ethernet;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return ConnectivityResult.mobile;
    }
    if (results.contains(ConnectivityResult.vpn)) return ConnectivityResult.vpn;
    if (results.contains(ConnectivityResult.bluetooth)) {
      return ConnectivityResult.bluetooth;
    }
    return ConnectivityResult.other;
  }

  NetworkQuality _deriveMobileQualityFromLatency() {
    if (_latencySamplesMs.isEmpty) {
      return _performanceTier == DevicePerformanceTier.lowEnd
          ? NetworkQuality.fair
          : NetworkQuality.good;
    }

    final sorted = List<int>.from(_latencySamplesMs)..sort();
    final median = sorted[sorted.length ~/ 2];

    // Bangladesh-friendly thresholds (mobile RTT is often higher).
    if (median <= 500) return NetworkQuality.good;
    if (median <= 1400) return NetworkQuality.fair;
    return NetworkQuality.poor;
  }

  void _updateFromResults(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;
    final previousQuality = _currentQuality;

    _isConnected = !results.contains(ConnectivityResult.none);
    final transport = _pickPrimaryTransport(results);

    if (transport != _lastTransport) {
      _lastTransport = transport;
      _latencySamplesMs.clear();
    }

    switch (transport) {
      case ConnectivityResult.none:
        _currentQuality = NetworkQuality.offline;
        break;
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
        // Start conservatively at 'good' — congested WiFi in Bangladesh
        // can still have high RTT. Promote to 'excellent' only after
        // collecting 2+ RTT samples that confirm fast response.
        if (_latencySamplesMs.length >= 2) {
          final sorted = List<int>.from(_latencySamplesMs)..sort();
          final median = sorted[sorted.length ~/ 2];
          _currentQuality = median <= 200
              ? NetworkQuality.excellent
              : median <= 600
              ? NetworkQuality.good
              : NetworkQuality.fair;
        } else {
          // Not enough samples yet — assume good until proven otherwise.
          _currentQuality = NetworkQuality.good;
        }
        break;
      case ConnectivityResult.mobile:
        _currentQuality = _deriveMobileQualityFromLatency();
        break;
      case ConnectivityResult.vpn:
      case ConnectivityResult.bluetooth:
      case ConnectivityResult.other:
        _currentQuality = NetworkQuality.fair;
        break;
      case ConnectivityResult.satellite:
        // TODO: Handle this case.
        throw UnimplementedError();
    }

    final changed =
        wasConnected != _isConnected || previousQuality != _currentQuality;
    if (changed) {
      notifyListeners();
      if (kDebugMode) {
        debugPrint('📶 Network changed:');
        debugPrint('   Connected: $_isConnected');
        debugPrint('   Quality: $qualityDescription');
      }
    }
  }

  /// Feed measured request RTT so the service can adapt mobile quality.
  void registerRequestLatency(Duration duration) {
    final ms = duration.inMilliseconds;
    if (ms <= 0 || !_isConnected) return;

    _latencySamplesMs.add(ms.clamp(1, 120000));
    if (_latencySamplesMs.length > 16) {
      _latencySamplesMs.removeAt(0);
    }

    if (_lastTransport == ConnectivityResult.mobile) {
      final next = _deriveMobileQualityFromLatency();
      if (next != _currentQuality) {
        _currentQuality = next;
        notifyListeners();
      }
    } else if (_lastTransport == ConnectivityResult.wifi ||
        _lastTransport == ConnectivityResult.ethernet) {
      // Re-evaluate WiFi quality now that we have more RTT data.
      if (_latencySamplesMs.length >= 2) {
        final sorted = List<int>.from(_latencySamplesMs)..sort();
        final median = sorted[sorted.length ~/ 2];
        final next = median <= 200
            ? NetworkQuality.excellent
            : median <= 600
            ? NetworkQuality.good
            : NetworkQuality.fair;
        if (next != _currentQuality) {
          _currentQuality = next;
          notifyListeners();
        }
      }
    }
  }

  Duration getAdaptiveTimeout() {
    switch (currentQuality) {
      case NetworkQuality.excellent:
        return const Duration(seconds: 8);
      case NetworkQuality.good:
        return const Duration(seconds: 10);
      case NetworkQuality.fair:
        return const Duration(seconds: 14);
      case NetworkQuality.poor:
        return const Duration(seconds: 22);
      case NetworkQuality.offline:
        return const Duration(seconds: 5);
    }
  }

  int getFeedConcurrency() {
    switch (currentQuality) {
      case NetworkQuality.excellent:
        return 6;
      case NetworkQuality.good:
        return 4;
      case NetworkQuality.fair:
        return 2;
      case NetworkQuality.poor:
      case NetworkQuality.offline:
        return 1;
    }
  }

  int getImageCacheWidth({required bool dataSaver}) {
    if (dataSaver) return 280;

    switch (currentQuality) {
      case NetworkQuality.excellent:
        return 900;
      case NetworkQuality.good:
        return 700;
      case NetworkQuality.fair:
        return 500;
      case NetworkQuality.poor:
      case NetworkQuality.offline:
        return 320;
    }
  }

  int getArticleLimit() {
    switch (currentQuality) {
      case NetworkQuality.excellent:
        return 60;
      case NetworkQuality.good:
        return 36;
      case NetworkQuality.fair:
        return 24;
      case NetworkQuality.poor:
      case NetworkQuality.offline:
        return 12;
    }
  }

  bool shouldLoadImages({required bool dataSaver}) {
    if (dataSaver) return false;
    return currentQuality != NetworkQuality.offline;
  }

  Duration getCacheDuration() {
    switch (currentQuality) {
      case NetworkQuality.excellent:
      case NetworkQuality.good:
        return const Duration(minutes: 30);
      case NetworkQuality.fair:
        return const Duration(hours: 1);
      case NetworkQuality.poor:
      case NetworkQuality.offline:
        return const Duration(hours: 4);
    }
  }

  bool shouldPrefetch() {
    if (_performanceTier == DevicePerformanceTier.budget ||
        _performanceTier == DevicePerformanceTier.lowEnd) {
      return false;
    }
    return currentQuality == NetworkQuality.excellent ||
        currentQuality == NetworkQuality.good;
  }

  void updatePerformanceTier(DevicePerformanceTier tier) {
    if (_performanceTier == tier) return;
    _performanceTier = tier;
    if (kDebugMode) {
      debugPrint('📡 AppNetworkService: Tier updated to $tier');
    }
  }

  void enableDebugSlowNetwork() {
    _debugOverrideQuality = NetworkQuality.poor;
    _debugOverrideConnectivity = true;
    _emitDebugOverrideLog('Enabled slow-network stress');
  }

  void enableDebugOfflineMode() {
    _debugOverrideQuality = NetworkQuality.offline;
    _debugOverrideConnectivity = false;
    _emitDebugOverrideLog('Enabled offline stress');
  }

  void clearDebugOverride() {
    _debugOverrideQuality = null;
    _debugOverrideConnectivity = null;
    _emitDebugOverrideLog('Cleared network stress overrides');
  }

  void _emitDebugOverrideLog(String msg) {
    if (kDebugMode) {
      debugPrint(
        '🧪 NetworkStress: $msg (quality=$currentQuality, connected=$isConnected)',
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    if (kDebugMode) {
      debugPrint('📡 AppNetworkService disposed');
    }
    super.dispose();
  }
}
