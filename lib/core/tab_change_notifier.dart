import 'package:flutter/material.dart';

/// Notifies listeners when the active tab index changes
/// Used to reset scroll position when switching tabs
class TabChangeNotifier extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setTab(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }
}
