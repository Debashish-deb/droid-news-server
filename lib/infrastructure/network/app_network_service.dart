// lib/infrastructure/network/app_network_service.dart
// ==========================================
// UNIFIED NETWORK SERVICE
// Combines NetworkManager + NetworkQualityManager
// Provides connectivity monitoring and quality assessment
// ==========================================

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../../bootstrap/di/injection_container.dart' show sl;
import 'package:injectable/injectable.dart';

// Network connection quality levels
enum NetworkQuality {
  excellent,
  good, // 4G/LTE
  fair, // 3G
  poor, // 2G/EDGE
  offline,
}

// Unified network service for connectivity and quality monitoring
///
// This service consolidates NetworkManager and NetworkQualityManager
// into a single, coherent service for network state management.
@lazySingleton
class AppNetworkService {
  AppNetworkService();



  bool _isConnected = true;
  NetworkQuality _currentQuality = NetworkQuality.good;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final List<VoidCallback> _listeners = [];


  bool get isConnected {
    return _isConnected;
  }

  NetworkQuality get currentQuality {
    return _currentQuality;
  }

  String get qualityDescription {
    switch (_currentQuality) {
      case NetworkQuality.excellent:
        return 'Excellent (WiFi)';
      case NetworkQuality.good:
        return 'Good (4G)';
      case NetworkQuality.fair:
        return 'Fair (3G)';
      case NetworkQuality.poor:
        return 'Poor (2G)';
      case NetworkQuality.offline:
        return 'Offline';
    }
  }


  Future<void> initialize() async {
    await _checkConnectivity();

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      _updateFromResults(results);
    });

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

  void _updateFromResults(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;
    final previousQuality = _currentQuality;

    _isConnected = !results.contains(ConnectivityResult.none);

    if (results.contains(ConnectivityResult.none)) {
      _currentQuality = NetworkQuality.offline;
    } else if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      _currentQuality = NetworkQuality.excellent;
    } else if (results.contains(ConnectivityResult.mobile)) {
      // Mobile networks can be unstable; default to fair to be conservative.
      _currentQuality = NetworkQuality.fair;
    } else {
      _currentQuality = NetworkQuality.fair;
    }

    if (wasConnected != _isConnected || previousQuality != _currentQuality) {
      _notifyListeners();

      if (kDebugMode) {
        debugPrint('📶 Network changed:');
        debugPrint('   Connected: $_isConnected');
        debugPrint('   Quality: $qualityDescription');
      }
    }
  }


  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }


  Duration getAdaptiveTimeout() {
    switch (_currentQuality) {
      case NetworkQuality.excellent:
        return const Duration(seconds: 5);
      case NetworkQuality.good:
        return const Duration(seconds: 6);
      case NetworkQuality.fair:
        return const Duration(seconds: 7);
      case NetworkQuality.poor:
        return const Duration(seconds: 8);
      case NetworkQuality.offline:
        return const Duration(seconds: 5); // Fail fast when offline
    }
  }

  int getImageCacheWidth({required bool dataSaver}) {
    if (dataSaver) {
      return 300; // Low quality in data saver mode
    }

    switch (_currentQuality) {
      case NetworkQuality.excellent:
        return 800; // High quality on WiFi
      case NetworkQuality.good:
        return 600; // Medium-high on 4G
      case NetworkQuality.fair:
        return 400; // Medium on 3G
      case NetworkQuality.poor:
      case NetworkQuality.offline:
        return 300; // Low quality on 2G or offline (cached)
    }
  }

  int getArticleLimit() {
    switch (_currentQuality) {
      case NetworkQuality.excellent:
        return 50; // Full load on WiFi
      case NetworkQuality.good:
        return 30; // Limited load on 4G
      case NetworkQuality.fair:
        return 20; // Lighter load on 3G
      case NetworkQuality.poor:
      case NetworkQuality.offline:
        return 15; // Minimal load on 2G/offline
    }
  }

  bool shouldLoadImages({required bool dataSaver}) {
    if (dataSaver) return false; // No images in data saver
    if (_currentQuality == NetworkQuality.offline) return false;
    return true; // Load images on all other connections
  }

  Duration getCacheDuration() {
    switch (_currentQuality) {
      case NetworkQuality.excellent:
      case NetworkQuality.good:
        return const Duration(minutes: 20); // Standard cache
      case NetworkQuality.fair:
        return const Duration(hours: 1); // Longer cache for 3G
      case NetworkQuality.poor:
      case NetworkQuality.offline:
        return const Duration(hours: 3); // Very long cache for poor connections
    }
  }

  bool shouldPrefetch() {
    return _currentQuality == NetworkQuality.excellent;
  }


  void dispose() {
    _subscription?.cancel();
    _listeners.clear();

    if (kDebugMode) {
      debugPrint('📡 AppNetworkService disposed');
    }
  }
}
