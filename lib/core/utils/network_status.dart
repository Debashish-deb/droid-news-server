import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Network status checker
class NetworkStatus {
  static final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connection
  static Future<bool> isConnected() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }

      try {
        final result = await InternetAddress.lookup(
          'google.com',
        ).timeout(const Duration(seconds: 3));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } on SocketException catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  /// Stream of connectivity changes
  static Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  /// Get connectivity type
  static Future<List<ConnectivityResult>> getConnectivityType() async {
    return await _connectivity.checkConnectivity();
  }
}
