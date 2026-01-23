import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme_provider.dart';
import '../../../core/theme.dart';
import '../../../presentation/providers/theme_providers.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get theme via Provider (legacy) since this is StatefulWidget
    // Migrated to Riverpod
    final AppThemeMode themeMode = ref.watch(currentThemeModeProvider);
    final List<Color> baseColors = _resolveGradient(themeMode);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // ===== STATIC GRADIENT LAYER =====
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    baseColors
                        .map((Color c) => c.withOpacity(widget.overlayOpacity))
                        .toList(),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),

        // ===== OPTIONAL ANIMATED OVERLAY =====
        if (widget.animate)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext _, Widget? __) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors:
                          baseColors.reversed
                              .map(
                                (Color c) =>
                                    c.withOpacity(widget.overlayOpacity * 0.6),
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

        // ===== OPTIONAL GLASS BLUR =====
        if (widget.blurSigma > 0)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.blurSigma,
                sigmaY: widget.blurSigma,
              ),
              child: Container(color: Colors.transparent),
            ),
          ),

        // ===== CONTENT =====
        if (widget.child != null) widget.child!,
      ],
    );
  }

  // ======================================================
  // GRADIENT RESOLVER (SYNCED TO THEME PROVIDER)
  // ======================================================
  List<Color> _resolveGradient(AppThemeMode mode) {
    return AppGradients.getBackgroundGradient(mode);
  }
}
