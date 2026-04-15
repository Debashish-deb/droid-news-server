import 'dart:ui';
import '../../../../core/theme/theme_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/performance_config.dart';
import '../../../providers/theme_providers.dart';

/// Premium 3D Container wrapping a standard Icon to give it depth and presence
class Settings3DIcon extends ConsumerWidget {
  const Settings3DIcon({
    required this.icon,
    super.key,
    this.color,
    this.size = 22, // Larger default size
    this.compact = false,
    this.useColorAsBackground = false,
  });
  final IconData icon;
  final Color? color;
  final double size;
  final bool compact;
  final bool useColorAsBackground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final baseLabelColor = scheme.onSurface;

    final Color faceColor = scheme.surfaceVariant.withValues(
      alpha: isDark ? 0.20 : 0.32,
    );

    final Color iconColor = baseLabelColor;

    final Color shadowColor = scheme.shadow.withValues(
      alpha: isDark ? 0.2 : 0.12,
    );
    final Color highlightColor = scheme.surface.withValues(
      alpha: isDark ? 0.25 : 0.65,
    );

    final double boxSize = compact ? 34 : 42; // More compact
    final double borderRadius = compact ? 10 : 12;

    return Container(
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        borderRadius: ThemeSkeleton.shared.circular(borderRadius),
        color: faceColor,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface.withValues(alpha: isDark ? 0.18 : 0.92),
            scheme.surface.withValues(alpha: isDark ? 0.06 : 0.72),
            scheme.surfaceVariant.withValues(alpha: isDark ? 0.12 : 0.55),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 6,
            offset: const Offset(2, 2),
          ),
          BoxShadow(
            color: highlightColor.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(-2, -2),
          ),
        ],
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.72 : 0.82),
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: compact ? size * 1.1 : size * 1.3,
        color: iconColor,
        shadows: [
          Shadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.25 : 0.1),
            blurRadius: 2,
            offset: const Offset(0.5, 0.5),
          ),
        ],
      ),
    );
  }
}

/// Premium 3D Button implementation for Settings actions
class Settings3DButton extends ConsumerStatefulWidget {
  const Settings3DButton({
    required this.onTap,
    super.key,
    this.label,
    this.icon,
    this.isSelected = false,
    this.isDestructive = false,
    this.width,
    this.height,
    this.fontSize,
    this.iconSize,
    this.padding,
  });

  final VoidCallback onTap;
  final String? label;
  final IconData? icon;
  final bool isSelected;
  final bool isDestructive;
  final double? width;
  final double? height;
  final double? fontSize;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;

  @override
  ConsumerState<Settings3DButton> createState() => _Settings3DButtonState();
}

class _Settings3DButtonState extends ConsumerState<Settings3DButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perf = PerformanceConfig.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = ref.watch(navIconColorProvider);
    final baseLabelColor = scheme.onSurface;
    final buttonBorderColor = scheme.outline.withValues(
      alpha: isDark ? 0.78 : 0.84,
    );
    final bool disableMotion =
        perf.reduceMotion || perf.lowPowerMode || perf.isLowEndDevice;
    final bool allowGlassBlur =
        !perf.reduceEffects &&
        !perf.lowPowerMode &&
        !perf.isLowEndDevice &&
        perf.performanceTier == DevicePerformanceTier.flagship;

    final Color activeColor = widget.isDestructive ? scheme.error : accent;

    return GestureDetector(
      onTapDown: (_) {
        if (!disableMotion) {
          _animController.forward();
        }
      },
      onTapUp: (_) {
        if (disableMotion) {
          widget.onTap();
          return;
        }
        _animController.reverse().then((_) => widget.onTap());
      },
      onTapCancel: () {
        if (!disableMotion) {
          _animController.reverse();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: AnimatedContainer(
          duration: disableMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: widget.width,
          height: widget.height ?? 54,
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: ThemeSkeleton.shared.circular(
              12,
            ), // Rounded rectangle for switch look
            color: isDark
                ? scheme.surface.withValues(alpha: 0.45)
                : scheme.surfaceVariant.withValues(alpha: 0.26),
            border: Border.all(
              color: buttonBorderColor,
              width: widget.isSelected ? 1.35 : 1.1,
            ),
          ),
          child: ClipRRect(
            borderRadius: ThemeSkeleton.shared.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Frosted Glass Background
                if (allowGlassBlur)
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(color: Colors.transparent),
                  ),

                // Electric Switch Indicator (Left side)
                if (widget.isSelected)
                  Positioned(
                    left: 0,
                    top: 10,
                    bottom: 10,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.only(
                          topRight: ThemeSkeleton.shared.radius(4),
                          bottomRight: ThemeSkeleton.shared.radius(4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.6),
                            blurRadius: 6,
                            offset: const Offset(2, 0),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Content
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null)
                      Icon(
                        widget.icon,
                        size: widget.iconSize ?? 20,
                        color: baseLabelColor,
                      ),
                    if (widget.icon != null && widget.label != null)
                      const SizedBox(height: ThemeSkeleton.size2),
                    if (widget.label != null)
                      Text(
                        widget.label!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: widget.fontSize ?? 11,
                          fontWeight: widget.isSelected
                              ? FontWeight.w800
                              : FontWeight.w700,
                          color: baseLabelColor.withValues(
                            alpha: widget.isSelected ? 1.0 : 0.92,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
