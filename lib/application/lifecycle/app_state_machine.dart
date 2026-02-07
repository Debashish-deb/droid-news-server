import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/offline_handler.dart';

/// Explicit Application Lifecycle States
enum AppState {
  /// App just launched, initializing core services
  coldStart,

  /// Recovering session, checking cache validity
  restoringSession,

  /// Device is offline, app operating in degraded/cached mode
  offline,

  /// Device is online, actively syncing with backend/RSS
  syncing,

  /// App is idle, content is up-to-date, ready for user interaction
  ready,

  /// App is running but in a degraded state (errors, partial data)
  degraded,

  /// App is in background (paused)
  background,
}

/// Managing Application Lifecycle State
class AppLifecycleNotifier extends StateNotifier<AppState> with WidgetsBindingObserver {
  AppLifecycleNotifier() : super(AppState.coldStart) {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Initialize app state
  Future<void> _init() async {
    state = AppState.coldStart;

    // Defer connectivity check to allow consumers to observe coldStart first.
    Future.microtask(_checkConnectivity);
  }

  Future<void> _checkConnectivity() async {
    state = AppState.restoringSession;
    
    final isOffline = await OfflineHandler.isOffline();
    if (isOffline) {
      state = AppState.offline;
    } else {
      state = AppState.ready;
    }
  }

  /// Hook for Sync Engine to signal start of sync
  void startSync() {
    if (state != AppState.background) {
      state = AppState.syncing;
    }
  }

  /// Hook for Sync Engine to signal end of sync
  void endSync({bool success = true}) {
    if (state == AppState.background) return;

    if (success) {
      state = AppState.ready;
    } else {
      state = AppState.degraded;
    }
  }

  /// Manually force offline state
  void setOffline() {
    state = AppState.offline;
  }

  /// Manually force ready state
  void setReady() {
    state = AppState.ready;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    super.didChangeAppLifecycleState(lifecycleState);
    
    switch (lifecycleState) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        state = AppState.background;
        break;
      case AppLifecycleState.resumed:
        _checkConnectivity(); 
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }
}

/// Global provider for App Lifecycle State
final appLifecycleProvider = StateNotifierProvider<AppLifecycleNotifier, AppState>((ref) {
  return AppLifecycleNotifier();
});
