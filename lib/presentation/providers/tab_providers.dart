import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// Tab State Management (Riverpod)
// ============================================================================

/// Tab state
class TabState {
  const TabState({this.currentIndex = 0});
  final int currentIndex;

  TabState copyWith({int? currentIndex}) {
    return TabState(currentIndex: currentIndex ?? this.currentIndex);
  }
}

/// Tab Notifier - manages bottom navigation tab state
class TabNotifier extends StateNotifier<TabState> {
  TabNotifier() : super(const TabState());

  void setTab(int index) {
    if (state.currentIndex != index) {
      state = TabState(currentIndex: index);
    }
  }

  int get currentIndex => state.currentIndex;
}

/// Provider for tab state
final tabProvider = StateNotifierProvider<TabNotifier, TabState>((ref) {
  return TabNotifier();
});

/// Convenience provider for current tab index
final currentTabIndexProvider = Provider<int>((ref) {
  return ref.watch(tabProvider.select((state) => state.currentIndex));
});
