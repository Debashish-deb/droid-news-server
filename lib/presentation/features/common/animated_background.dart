import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/theme_mode.dart';
import '../../../core/theme/theme.dart';
import '../../../core/config/performance_config.dart';
import '../../providers/theme_providers.dart';

/// Full-screen animated background with gradient overlay
/// and optional frosted blur effect.
class AnimatedBackground extends ConsumerStatefulWidget {
  const AnimatedBackground({
    super.key,
    this.child,
    this.duration = const Duration(seconds: 20),
    this.blurSigma = 20,
    this.overlayOpacity = 0.3,
    this.animate = true,
  });

  final Widget? child;
  final Duration duration;
  final double blurSigma;
  final double overlayOpacity;
  final bool animate;

  @override
  ConsumerState<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends ConsumerState<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _shouldAnimate = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final perf = PerformanceConfig.of(context);
    final shouldAnimate = widget.animate &&
        !perf.reduceMotion &&
        !perf.lowPowerMode &&
        !perf.isLowEndDevice;
    if (shouldAnimate == _shouldAnimate) return;
    _shouldAnimate = shouldAnimate;
    if (_shouldAnimate) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perf = PerformanceConfig.of(context);

    final AppThemeMode themeMode = ref.watch(currentThemeModeProvider);
    final List<Color> baseColors = _resolveGradient(themeMode);
    final bool allowBlur =
        widget.blurSigma > 0 &&
        !perf.lowPowerMode &&
        !perf.isLowEndDevice &&
        !perf.reduceEffects;
    final double blurSigma = allowBlur
        ? widget.blurSigma.clamp(0.0, 12.0)
        : 0.0;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    baseColors
                        .map((Color c) => c.withValues(alpha: widget.overlayOpacity))
                        .toList(),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),

        if (_shouldAnimate)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext _, Widget? _) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors:
                          baseColors.reversed
                              .map(
                                (Color c) =>
                                    c.withValues(alpha: widget.overlayOpacity * 0.6),
                              )
                              .toList(),
                      begin: Alignment(-1 + (_controller.value * 2), -1),
                      end: Alignment(1 - (_controller.value * 2), 1),
                    ),
                  ),
                );
              },
            ),
          ),

        if (blurSigma > 0)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: Container(color: Colors.transparent),
            ),
          ),

        if (widget.child != null) widget.child!,
      ],
    );
  }

  List<Color> _resolveGradient(AppThemeMode mode) {
    return AppGradients.getBackgroundGradient(mode);
  }
}
