import 'dart:math' as math;
import '../../core/theme/theme_skeleton.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/config/constants.dart' show AppPerformance;
import '../../core/config/performance_config.dart';
import 'platform_surface_treatment.dart';

class GlassPillButton extends StatefulWidget {
  const GlassPillButton({
    required this.onPressed,
    required this.label,
    required this.isDark,
    super.key,
    this.icon,
    this.width,
    this.height = 44,
    this.isDestructive = false,
    this.isPrimary = false,
    this.fontSize,
  });
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isDestructive;
  final bool isPrimary;
  final bool isDark;
  final double? width;
  final double height;
  final double? fontSize;

  @override
  State<GlassPillButton> createState() => _GlassPillButtonState();
}

class _GlassPillButtonState extends State<GlassPillButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );

    _scale = Tween<double>(
      begin: 1,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed == null) return;
    _controller.forward();
    HapticFeedback.selectionClick();
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onPressed == null) return;
    _controller.reverse();
  }

  void _onTapCancel() {
    if (widget.onPressed == null) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perf = PerformanceConfig.of(context);
    final preferMaterialChrome = preferAndroidMaterialSurfaceChrome(context);
    final reduceEffects = perf.reduceEffects || preferMaterialChrome;
    final reduceMotion =
        perf.reduceMotion || MediaQuery.of(context).disableAnimations;

    Color textColor = widget.isDark ? Colors.white : Colors.black;
    Color iconColor = widget.isDark ? Colors.white : Colors.black;
    Color borderColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.86)
        : Colors.black.withValues(alpha: 0.86);
    Color glassColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    if (widget.isDestructive) {
      textColor = theme.colorScheme.primary;
      iconColor = theme.colorScheme.primary;
      borderColor = theme.colorScheme.primary.withValues(alpha: 0.35);
      glassColor = theme.colorScheme.primary.withValues(alpha: 0.08);
    } else if (widget.isPrimary) {
      textColor = widget.isDark ? Colors.white : Colors.black;
      iconColor = widget.isDark ? Colors.white : Colors.black;
      borderColor = widget.isDark
          ? Colors.white.withValues(alpha: 0.86)
          : Colors.black.withValues(alpha: 0.86);
      glassColor = theme.colorScheme.primary.withValues(alpha: 0.85);
    }

    if (preferMaterialChrome && !widget.isPrimary) {
      glassColor = materialSurfaceOverlayColor(
        theme.colorScheme,
        surfaceAlpha: widget.isDark ? 0.92 : 0.98,
        tintAlpha: widget.isDestructive ? 0.02 : 0.05,
      );
      borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.7);
      if (widget.isDestructive) {
        borderColor = theme.colorScheme.primary.withValues(alpha: 0.28);
      }
    }

    final disabled = widget.onPressed == null;
    final surface = _PillButtonSurface(
      theme: theme,
      widget: widget,
      borderColor: borderColor,
      glassColor: reduceEffects
          ? glassColor.withValues(alpha: 0.92)
          : glassColor,
      iconColor: iconColor,
      textColor: textColor,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      reduceMotion: reduceMotion,
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.label,
      child: ScaleTransition(
        scale: reduceMotion ? const AlwaysStoppedAnimation(1.0) : _scale,
        child: ClipRRect(
          borderRadius: ThemeSkeleton.shared.circular(999),
          child: RepaintBoundary(
            child: reduceEffects
                ? surface
                : BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: AppPerformance.glassBlurSigma > 5
                          ? 5
                          : AppPerformance.glassBlurSigma,
                      sigmaY: AppPerformance.glassBlurSigma > 5
                          ? 5
                          : AppPerformance.glassBlurSigma,
                    ),
                    child: surface,
                  ),
          ),
        ),
      ),
    );
  }
}

class _PillButtonSurface extends StatelessWidget {
  const _PillButtonSurface({
    required this.theme,
    required this.widget,
    required this.borderColor,
    required this.glassColor,
    required this.iconColor,
    required this.textColor,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
    required this.reduceMotion,
  });

  final ThemeData theme;
  final GlassPillButton widget;
  final Color borderColor;
  final Color glassColor;
  final Color iconColor;
  final Color textColor;
  final GestureTapDownCallback onTapDown;
  final GestureTapUpCallback onTapUp;
  final VoidCallback onTapCancel;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        onTapDown: onTapDown,
        onTapUp: onTapUp,
        onTapCancel: onTapCancel,
        borderRadius: ThemeSkeleton.shared.circular(999),
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: widget.width,
          height: math.max(widget.height, 48),
          alignment: Alignment.center, // Ensure vertical centering
          padding: ThemeSkeleton.shared.insetsSymmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: ThemeSkeleton.shared.circular(999),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: const <BoxShadow>[],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.icon != null)
                Positioned(
                  left: 12,
                  child: Icon(widget.icon, size: 18, color: iconColor),
                ),
              Padding(
                padding: ThemeSkeleton.shared.insetsSymmetric(
                  horizontal: widget.icon != null ? 36 : 12,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label.toUpperCase(),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: textColor,
                      fontSize: widget.fontSize ?? 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
