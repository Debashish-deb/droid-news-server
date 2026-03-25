import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show ServicesBinding;
import 'package:rxdart/rxdart.dart';

class OfflineHandler {
  factory OfflineHandler() => _instance;
  OfflineHandler._internal();
  static final OfflineHandler _instance = OfflineHandler._internal();

  bool _isOffline = false;
  bool get isDeviceOffline => _isOffline;

  StreamController<bool>? _controller;
  Stream<bool> get onConnectivityChanged {
    _ensureInitialized();
    _controller ??= StreamController<bool>.broadcast();
    return _controller!.stream;
  }

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isListenerInitialized = false;

  void _ensureInitialized() {
    if (_isListenerInitialized) return;
    _initListener();
  }

  void _initListener() {
    _isListenerInitialized = true;
    _subscription?.cancel();
    try {
      ServicesBinding.instance;
    } catch (_) {
      return;
    }
    try {
      _subscription = Connectivity().onConnectivityChanged
          .debounceTime(const Duration(milliseconds: 300))
          .listen((List<ConnectivityResult> results) {
            final bool offline = results.contains(ConnectivityResult.none);

            if (_isOffline != offline) {
              _isOffline = offline;
              if (_controller != null && !_controller!.isClosed) {
                _controller!.add(offline);
              }
            }
          });

      Connectivity()
          .checkConnectivity()
          .then((List<ConnectivityResult> results) {
            _isOffline = results.contains(ConnectivityResult.none);
          })
          .catchError((_) {
            // Platform channels may be unavailable in some tests.
          });
    } catch (_) {
      // Platform channels may be unavailable in some tests.
    }
  }

  /// Static Accessor for manual checks
  static Future<bool> isOffline() async {
    _instance._ensureInitialized();
    try {
      final List<ConnectivityResult> results = await Connectivity()
          .checkConnectivity();
      _instance._isOffline = results.contains(ConnectivityResult.none);
    } catch (_) {
      // Fallback to cached value when connectivity plugin is unavailable.
    }
    return _instance._isOffline;
  }

  /// Force refresh status (debug only manual override)
  static Future<void> checkNow() async {
    if (!kDebugMode) return;

    final List<ConnectivityResult> results = await Connectivity()
        .checkConnectivity();
    _instance._isOffline = results.contains(ConnectivityResult.none);
  }

  /// Manually set offline status for testing
  @visibleForTesting
  static void setOfflineForTesting(bool offline) {
    if (kDebugMode) {
      _instance._isOffline = offline;
      if (_instance._controller != null && !_instance._controller!.isClosed) {
        _instance._controller!.add(offline);
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _isListenerInitialized = false;
    // We don't close the controller here to protect the heart of the singleton,
    // or we close it and set to null so it can be re-created.
    _controller?.close();
    _controller = null;
  }

  /// Re-initialize if disposed
  void reInitialize() {
    if (_subscription != null) return;
    _isListenerInitialized = false;
    _ensureInitialized();
  }
}
