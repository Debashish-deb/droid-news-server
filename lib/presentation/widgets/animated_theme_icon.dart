import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_providers.dart'
    show currentThemeModeProvider, navIconColorProvider;
import '../../core/enums/theme_mode.dart';

/// Premium animated icon widget with enhanced performance, gradient support,
/// and smooth theme-aware transitions
class AnimatedThemeIcon extends ConsumerStatefulWidget {
  const AnimatedThemeIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.hoverColor,
    this.gradient,
    this.semanticLabel,
    this.padding = EdgeInsets.zero,
    this.animationDuration = const Duration(milliseconds: 350),
    this.animationCurve = Curves.easeInOutCubic,
    this.enableHoverEffect = false,
    this.enablePulseEffect = false,
    this.enableColorTransition = true,
    this.shadows,
    this.border,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.shape = BoxShape.circle,
    this.borderRadius,
    this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color? hoverColor;
  final Gradient? gradient;
  final String? semanticLabel;
  final EdgeInsets padding;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool enableHoverEffect;
  final bool enablePulseEffect;
  final bool enableColorTransition;
  final List<Shadow>? shadows;
  final BoxBorder? border;
  final Color? backgroundColor;
  final Color? hoverBackgroundColor;
  final BoxShape shape;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  ConsumerState<AnimatedThemeIcon> createState() => _AnimatedThemeIconState();
}

class _AnimatedThemeIconState extends ConsumerState<AnimatedThemeIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isHovering = false;
  bool _isPulsing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    if (widget.enablePulseEffect) {
      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: 1.2,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeInOutSine,
        ),
      );

      _opacityAnimation = Tween<double>(
        begin: 1.0,
        end: 0.5,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeInOutSine,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startPulse() {
    if (!widget.enablePulseEffect || _isPulsing) return;

    _isPulsing = true;
    _controller
        .forward()
        .then((_) => _controller.reverse())
        .then((_) => _isPulsing = false);
  }

  void _handleHover(bool hovering) {
    if (!widget.enableHoverEffect) return;

    setState(() {
      _isHovering = hovering;
    });
  }

  Color _getCurrentColor(BuildContext context) {
    if (_isHovering && widget.hoverColor != null) {
      return widget.hoverColor!;
    }

    if (widget.color != null) {
      return widget.color!;
    }

    // Fallback to theme color
    final theme = Theme.of(context);
    return theme.iconTheme.color ?? theme.colorScheme.onSurface;
  }

  Color _getCurrentBackgroundColor(BuildContext context) {
    if (_isHovering && widget.hoverBackgroundColor != null) {
      return widget.hoverBackgroundColor!;
    }

    if (widget.backgroundColor != null) {
      return widget.backgroundColor!;
    }

    return Colors.transparent;
  }

  Widget _buildIcon(BuildContext context) {
    final currentColor = _getCurrentColor(context);
    final backgroundColor = _getCurrentBackgroundColor(context);
    final selectionColor = ref.watch(navIconColorProvider);

    Widget iconWidget = Icon(
      widget.icon,
      size: widget.size,
      color: currentColor,
      semanticLabel: widget.semanticLabel,
    );

    // Apply gradient if specified
    if (widget.gradient != null) {
      iconWidget = ShaderMask(
        shaderCallback: (bounds) => widget.gradient!.createShader(bounds),
        child: iconWidget,
      );
    }

    // Apply shadows if specified
    if (widget.shadows != null) {
      iconWidget = Text(
        String.fromCharCode(widget.icon.codePoint),
        style: TextStyle(
          fontSize: widget.size,
          fontFamily: widget.icon.fontFamily,
          color: currentColor,
          shadows: widget.shadows,
        ),
      );
    }

    // Build the container with optional background
    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: widget.shape,
        borderRadius: widget.shape == BoxShape.rectangle
            ? widget.borderRadius ?? BorderRadius.circular(8)
            : null,
        border: widget.border,
        gradient: _isHovering && widget.hoverBackgroundColor == null
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  selectionColor.withOpacity(0.1),
                  Colors.transparent,
                ],
              )
            : null,
        boxShadow: _isHovering
            ? [
                BoxShadow(
                  color: selectionColor.withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(child: iconWidget),
    );
  }

  Widget _buildAnimatedIcon(BuildContext context) {
    if (!widget.enableColorTransition && !widget.enablePulseEffect) {
      return _buildIcon(context);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        Color? animatedColor;
        if (widget.enableColorTransition) {
          animatedColor = Color.lerp(
            widget.color,
            ref.watch(navIconColorProvider),
            _controller.value * 0.5,
          );
        }

        return Transform.scale(
          scale: widget.enablePulseEffect ? _scaleAnimation.value : 1.0,
          child: Opacity(
            opacity: widget.enablePulseEffect ? _opacityAnimation.value : 1.0,
            child: widget.enableColorTransition
                ? Icon(
                    widget.icon,
                    size: widget.size,
                    color: animatedColor ?? _getCurrentColor(context),
                    semanticLabel: widget.semanticLabel,
                  )
                : _buildIcon(context),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget icon = _buildAnimatedIcon(context);

    if (widget.onTap != null) {
      icon = MouseRegion(
        onEnter: (_) => _handleHover(true),
        onExit: (_) => _handleHover(false),
        child: GestureDetector(
          onTap: () {
            _startPulse();
            widget.onTap?.call();
          },
          onTapDown: (_) {
            if (widget.enableHoverEffect) {
              setState(() => _isHovering = true);
            }
          },
          onTapUp: (_) {
            if (widget.enableHoverEffect) {
              setState(() => _isHovering = false);
            }
          },
          onTapCancel: () {
            if (widget.enableHoverEffect) {
              setState(() => _isHovering = false);
            }
          },
          child: icon,
        ),
      );
    }

    if (widget.tooltip != null) {
      icon = Tooltip(
        message: widget.tooltip,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 500),
        child: icon,
      );
    }

    return icon;
  }
}

/// A specialized animated icon that adapts to theme changes with premium effects
class PremiumThemeIcon extends ConsumerWidget {
  const PremiumThemeIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.lightColor,
    this.darkColor,
    this.bangladeshColor,
    this.semanticLabel,
    this.enableGlowEffect = true,
    this.enableTransition = true,
    this.padding = const EdgeInsets.all(4),
  });

  final IconData icon;
  final double size;
  final Color? lightColor;
  final Color? darkColor;
  final Color? bangladeshColor;
  final String? semanticLabel;
  final bool enableGlowEffect;
  final bool enableTransition;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(currentThemeModeProvider);
    final selectionColor = ref.watch(navIconColorProvider);

    Color getColor() {
      switch (themeMode) {
        case AppThemeMode.light:
          return lightColor ?? Colors.black87;
        case AppThemeMode.dark:
        case AppThemeMode.amoled:
          return darkColor ?? Colors.white;
        case AppThemeMode.bangladesh:
          return bangladeshColor ?? const Color(0xFF006A4E);
        case AppThemeMode.system:
          final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
          return brightness == Brightness.dark
              ? (darkColor ?? Colors.white)
              : (lightColor ?? Colors.black87);
      }
    }

    final iconColor = getColor();

    return AnimatedThemeIcon(
      icon,
      size: size,
      color: iconColor,
      hoverColor: selectionColor,
      animationDuration: const Duration(milliseconds: 500),
      enableHoverEffect: true,
      enableColorTransition: enableTransition,
      shadows: enableGlowEffect
          ? [
              Shadow(
                color: iconColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
      backgroundColor: Colors.transparent,
      hoverBackgroundColor: selectionColor.withOpacity(0.1),
      padding: padding,
      borderRadius: BorderRadius.circular(12),
      semanticLabel: semanticLabel,
    );
  }
}

/// Animated icon with gradient support for premium UI elements
class GradientThemeIcon extends StatelessWidget {
  const GradientThemeIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.gradient,
    this.semanticLabel,
    this.enableAnimation = true,
  });

  final IconData icon;
  final double size;
  final Gradient? gradient;
  final String? semanticLabel;
  final bool enableAnimation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        theme.colorScheme.primary,
        theme.colorScheme.secondary,
      ],
    );

    return AnimatedThemeIcon(
      icon,
      size: size,
      gradient: gradient ?? defaultGradient,
      animationDuration:
          enableAnimation ? const Duration(milliseconds: 500) : Duration.zero,
      enableColorTransition: enableAnimation,
      shadows: [
        Shadow(
          color: theme.colorScheme.primary.withOpacity(0.3),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
      semanticLabel: semanticLabel,
    );
  }
}

/// Floating action button style animated icon
class FloatingThemeIcon extends ConsumerWidget {
  const FloatingThemeIcon(
    this.icon, {
    super.key,
    this.size = 28,
    this.color,
    this.backgroundColor,
    this.elevation = 8,
    this.onTap,
    this.tooltip,
    this.enableShadow = true,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final double elevation;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool enableShadow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionColor = ref.watch(navIconColorProvider);

    return AnimatedThemeIcon(
      icon,
      size: size,
      color: color ?? Colors.white,
      animationDuration: const Duration(milliseconds: 300),
      animationCurve: Curves.easeOutBack,
      enableHoverEffect: true,
      enablePulseEffect: true,
      backgroundColor: backgroundColor ?? selectionColor,
      hoverBackgroundColor: backgroundColor?.withOpacity(0.9) ??
          selectionColor.withOpacity(0.9),
      padding: const EdgeInsets.all(12),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1.5,
      ),
      shadows: enableShadow
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: elevation,
                spreadRadius: elevation / 3,
                offset: Offset(0, elevation / 2),
              ),
            ]
          : null,
      onTap: onTap,
      tooltip: tooltip,
    );
  }
}