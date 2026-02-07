import 'package:flutter/widgets.dart';

/// Inherited configuration for performance-related settings.
class PerformanceConfig extends InheritedWidget {
  const PerformanceConfig({
    required this.reduceMotion, required this.reduceEffects, required this.dataSaver, required super.child, super.key,
  });

  final bool reduceMotion;
  final bool reduceEffects;
  final bool dataSaver;

  static PerformanceConfig? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PerformanceConfig>();
  }

  static PerformanceConfig of(BuildContext context) {
    return maybeOf(context) ??
        const PerformanceConfig(
          reduceMotion: false,
          reduceEffects: false,
          dataSaver: false,
          child: SizedBox.shrink(),
        );
  }

  @override
  bool updateShouldNotify(PerformanceConfig oldWidget) {
    return reduceMotion != oldWidget.reduceMotion ||
        reduceEffects != oldWidget.reduceEffects ||
        dataSaver != oldWidget.dataSaver;
  }
}
