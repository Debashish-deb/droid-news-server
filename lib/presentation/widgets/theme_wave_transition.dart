import 'package:flutter/material.dart';
import '../../core/theme/theme.dart' show AppThemeRulesExtension;

/// Lightweight top-to-bottom sweep shown when app theme changes.
///
/// This masks partial repaint perception on large trees and makes the
/// transition feel intentional even on constrained Android devices.
class ThemeWaveTransition extends StatefulWidget {
  const ThemeWaveTransition({
    required this.themeKey,
    required this.child,
    super.key,
    this.duration = const Duration(milliseconds: 420),
  });

  final Object themeKey;
  final Widget child;
  final Duration duration;

  @override
  State<ThemeWaveTransition> createState() => _ThemeWaveTransitionState();
}

class _ThemeWaveTransitionState extends State<ThemeWaveTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _heightFactor;
  bool _firstFrame = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _heightFactor = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant ThemeWaveTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_firstFrame) {
      _firstFrame = false;
      return;
    }
    if (oldWidget.themeKey != widget.themeKey) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rules = Theme.of(context).extension<AppThemeRulesExtension>();
    final wave = rules?.themeWaveColor ?? const Color(0x40FFFFFF);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _heightFactor,
            builder: (context, child) {
              final t = _heightFactor.value;
              if (t <= 0 || t >= 1) {
                return const SizedBox.shrink();
              }

              return Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  widthFactor: 1,
                  heightFactor: t,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          wave,
                          wave.withValues(alpha: 0.16),
                          Colors.transparent,
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
