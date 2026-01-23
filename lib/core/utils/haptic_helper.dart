import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Haptic feedback helper for consistent tactile responses
class HapticHelper {
  HapticHelper._();

  /// Light impact - for selections, switches
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium impact - for buttons, actions
  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact - for important actions, errors
  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  /// Selection - for picker changes
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }

  /// Vibrate - for notifications
  static Future<void> vibrate() async {
    await HapticFeedback.vibrate();
  }

  /// Success feedback - medium impact
  static Future<void> success() async {
    await medium();
  }

  /// Error feedback - heavy impact
  static Future<void> error() async {
    await heavy();
  }

  /// Tap feedback - light impact for taps
  static Future<void> tap() async {
    await light();
  }
}

/// Extension on Widget for easy haptic feedback
extension HapticGestureDetector on Widget {
  /// Wrap widget with GestureDetector that provides haptic feedback on tap
  Widget withHapticTap({
    required VoidCallback onTap,
    HitTestBehavior? behavior,
  }) {
    return GestureDetector(
      behavior: behavior,
      onTap: () {
        HapticHelper.tap();
        onTap();
      },
      child: this,
    );
  }
}

/// Extension on InkWell/InkResponse for haptic feedback
extension HapticInkWell on InkWell {
  /// Create InkWell with automatic haptic feedback
  static InkWell withHaptic({
    required VoidCallback onTap,
    Widget? child,
    BorderRadius? borderRadius,
    Color? splashColor,
    Color? highlightColor,
  }) {
    return InkWell(
      onTap: () {
        HapticHelper.tap();
        onTap();
      },
      borderRadius: borderRadius,
      splashColor: splashColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}
