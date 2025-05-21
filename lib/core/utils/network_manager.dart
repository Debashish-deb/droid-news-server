// path: lib/core/utils/network_manager.dart

import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkSpeed { fast, slow, unknown }

class NetworkManager {
  static Future<NetworkSpeed> getConnectionSpeed() async {
    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) return NetworkSpeed.unknown;

    // Simple, non-blocking heuristic: consider non-WiFi as "slow"
    if (result == ConnectivityResult.mobile) return NetworkSpeed.slow;
    if (result == ConnectivityResult.wifi) return NetworkSpeed.fast;

    return NetworkSpeed.unknown;
  }
}
