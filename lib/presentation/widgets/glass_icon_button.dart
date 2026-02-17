import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart' show AppPerformance;
import '../../core/performance_config.dart';

class GlassIconButton extends StatefulWidget {

  const GlassIconButton({
    required this.onPressed, required this.icon, required this.isDark, super.key,
    this.size = 20,
    this.color,
    this.backgroundColor,
    this.glowIntensity,
    this.tooltip,
  });
  final VoidCallback? onPressed;
  final IconData icon;
  final bool isDark;
  final double size;
  final Color? color;
  final Color? backgroundColor;

  final double? glowIntensity;
  final String? tooltip;

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _reduceMotion = AppPerformance.reduceMotion;
  bool _reduceEffects = AppPerformance.reduceEffects;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppPerformance.reduceMotion
          ? AppPerformance.animationDuration
          : const Duration(milliseconds: 100),
    );

    const double endScale = AppPerformance.reduceMotion ? 1.0 : 0.92;
    _scale = Tween<double>(begin: 1.0, end: endScale)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final perf = PerformanceConfig.of(context);
    if (perf.reduceMotion != _reduceMotion || perf.reduceEffects != _reduceEffects) {
      _reduceMotion = perf.reduceMotion;
      _reduceEffects = perf.reduceEffects;
      _controller.duration = _reduceMotion
          ? AppPerformance.animationDuration
          : const Duration(milliseconds: 100);
      if (_reduceMotion) {
        _controller.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed != null) {
      if (!_reduceMotion) {
        _controller.forward();
      }
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (!_reduceMotion) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (!_reduceMotion) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
// Removed unused variable 'theme'
    final borderColor = widget.isDark 
        ? Colors.white.withOpacity(0.2) 
        : Colors.black.withOpacity(0.12);
    
    final glassColor = widget.backgroundColor ?? (widget.isDark 
        ? Colors.white.withOpacity(0.08) 
        : Colors.black.withOpacity(0.05));
    final bool reduceEffects = _reduceEffects;

    final Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: () {
        if (widget.onPressed != null) {
          widget.onPressed!();
        }
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: reduceEffects
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: glassColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.2),
                    ),
                    child: Icon(
                      widget.icon,
                      size: widget.size,
                      color:
                          widget.color ?? (widget.isDark ? Colors.white : Colors.black87),
                    ),
                  )
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: glassColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 1.3),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: widget.isDark
                              ? [
                                  Colors.white.withOpacity(0.18),
                                  Colors.white.withOpacity(0.02),
                                ]
                              : [
                                  Colors.white.withOpacity(0.95),
                                  Colors.white.withOpacity(0.6),
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(widget.isDark ? 0.4 : 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: -10,
                            left: 4,
                            right: 4,
                            child: Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.0),
                                    Colors.white.withOpacity(
                                      widget.isDark ? 0.3 : 0.8,
                                    ),
                                    Colors.white.withOpacity(0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Icon(
                            widget.icon,
                            size: widget.size,
                            color: widget.color ??
                                (widget.isDark ? Colors.white : Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip,
        child: button,
      );
    }
    return button;
  }
}
