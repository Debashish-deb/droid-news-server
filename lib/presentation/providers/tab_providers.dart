import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/providers.dart';

// Key for persisting tab index
const String _kTabIndexKey = 'selected_tab_index';

/// Tab state
class TabState {
  const TabState({this.currentIndex = 0});
  final int currentIndex;

  TabState copyWith({int? currentIndex}) {
    return TabState(currentIndex: currentIndex ?? this.currentIndex);
  }
}

/// Tab Notifier - manages bottom navigation tab state with persistence
class TabNotifier extends StateNotifier<TabState> {
  TabNotifier(this._prefs) : super(TabState(currentIndex: _prefs?.getInt(_kTabIndexKey) ?? 0));

  final SharedPreferences? _prefs;

  void setTab(int index) {
    if (state.currentIndex != index) {
      state = TabState(currentIndex: index);
      _prefs?.setInt(_kTabIndexKey, index);
    }
  }

  int get currentIndex => state.currentIndex;
}

/// Provider for tab state - dependencies should be pre-warmed in main
final tabProvider = StateNotifierProvider<TabNotifier, TabState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return TabNotifier(prefs);
});

/// Convenience provider for current tab index
final currentTabIndexProvider = Provider<int>((ref) {
  return ref.watch(tabProvider.select((state) => state.currentIndex));
});
