import 'package:flutter/material.dart';

/// Design tokens specific to the WebView Screen components.
class WT {
  WT._();

  static const double headerHeight = 92.0;
  static const double toolbarHeight = 72.0;
  static const double progressHeight = 3.0;

  static const Color progressGold = Color(0xFFD4A853);
  static const Color progressGoldBg = Color(0x22D4A853);

  static const Duration toolPress = Duration(milliseconds: 80);
  static const Duration toolRelease = Duration(milliseconds: 420);

  /// Minimum milliseconds between progress-bar setState calls.
  static const int progressThrottleMs = 16; // ~1 frame

  /// Scroll-save debounce duration.
  static const Duration scrollSaveDebounce = Duration(milliseconds: 500);
}
