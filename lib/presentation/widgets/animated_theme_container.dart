import 'dart:math';
import 'particle_background.dart';

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_providers.dart'
    show currentThemeModeProvider, navIconColorProvider;
import '../../core/enums/theme_mode.dart';
import '../../core/constants.dart' show AppPerformance;
import '../../core/performance_config.dart';

/// Premium animated container widget with advanced features:
/// - Glassmorphism effects
/// - Gradient transitions
/// - Particle backgrounds
/// - Border animations
/// - Performance optimizations
class AnimatedThemeContainer extends ConsumerStatefulWidget {
  const AnimatedThemeContainer({
    super.key,
    this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.decoration,
    this.color,
    this.alignment,
    this.constraints,
    this.gradient,
    this.border,
    this.borderRadius,
    this.boxShadow,
    this.enableGlassEffect = false,
    this.glassBlurSigma = 10.0,
    this.enableParticles = false,
    this.particleCount = 15,
    this.enableBorderAnimation = false,
    this.borderAnimationDuration = const Duration(milliseconds: 1000),
    this.enableHoverEffect = false,
    this.hoverElevation = 8.0,
    this.animationDuration = const Duration(milliseconds: 500),
    this.animationCurve = Curves.easeInOutCubic,
    this.onTap,
    this.onHover,
    this.semanticLabel,
    this.clipBehavior = Clip.none,
    this.transform,
    this.transformAlignment,
  });

  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxDecoration? decoration;
  final Color? color;
  final AlignmentGeometry? alignment;
  final BoxConstraints? constraints;
  final Gradient? gradient;
  final BoxBorder? border;
  final BorderRadiusGeometry? borderRadius;
  final List<BoxShadow>? boxShadow;
  final bool enableGlassEffect;
  final double glassBlurSigma;
  final bool enableParticles;
  final int particleCount;
  final bool enableBorderAnimation;
  final Duration borderAnimationDuration;
  final bool enableHoverEffect;
  final double hoverElevation;
  final Duration animationDuration;
  final Curve animationCurve;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHover;
  final String? semanticLabel;
  final Clip clipBehavior;
  final Matrix4? transform;
  final AlignmentGeometry? transformAlignment;

  @override
  ConsumerState<AnimatedThemeContainer> createState() =>
      _AnimatedThemeContainerState();
}

class _AnimatedThemeContainerState
    extends ConsumerState<AnimatedThemeContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _borderAnimation;
  bool _isHovering = false;
  List<Particle> _particles = [];
  bool _reduceEffects = AppPerformance.reduceEffects;
  bool _reduceMotion = AppPerformance.reduceMotion;

  @override
  void initState() {
    super.initState();
    _initializeParticles();
    _initializeAnimations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final perf = PerformanceConfig.of(context);
    if (perf.reduceEffects != _reduceEffects || perf.reduceMotion != _reduceMotion) {
      _reduceEffects = perf.reduceEffects;
      _reduceMotion = perf.reduceMotion;
      _controller.duration = _reduceMotion
          ? AppPerformance.animationDuration
          : widget.borderAnimationDuration;

      if (_reduceEffects || _reduceMotion) {
        _controller.stop();
      } else if (widget.enableBorderAnimation) {
        _controller.repeat(reverse: true);
      }

      if (!_reduceEffects && widget.enableParticles && _particles.isEmpty) {
        _initializeParticles();
      }
    }
  }

  void _initializeParticles() {
    if (!widget.enableParticles || _reduceEffects) return;

    final random = Random();
    _particles = List.generate(widget.particleCount, (index) {
      return Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 3 + 1,
        speed: random.nextDouble() * 0.3 + 0.1,
        color: Colors.white.withOpacity(random.nextDouble() * 0.2 + 0.05),
      );
    });
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      duration: _reduceMotion
          ? AppPerformance.animationDuration
          : widget.borderAnimationDuration,
      vsync: this,
    );

    if (widget.enableBorderAnimation && !_reduceEffects && !_reduceMotion) {
      _borderAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeInOutSine,
        ),
      );

      _controller.repeat(reverse: true);
    } else {
      _borderAnimation = const AlwaysStoppedAnimation(0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHover(bool hovering) {
    if (!widget.enableHoverEffect || _reduceEffects) return;

    setState(() {
      _isHovering = hovering;
    });
    widget.onHover?.call(hovering);
  }

  Widget _buildParticleBackground(Size size) {
    return CustomPaint(
      size: size,
      painter: ParticlePainter(
        particles: _particles,
        animationValue: _controller.value,
      ),
    );
  }

  Widget _buildGlassEffect({required Widget child}) {
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(0),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: _reduceEffects
              ? AppPerformance.glassBlurSigma
              : widget.glassBlurSigma,
          sigmaY: _reduceEffects
              ? AppPerformance.glassBlurSigma
              : widget.glassBlurSigma,
        ),
        child: child,
      ),
    );
  }

  Decoration _buildDecoration(BuildContext context) {
    final themeMode = ref.watch(currentThemeModeProvider);
    final selectionColor = ref.watch(navIconColorProvider);
    final isDark = themeMode == AppThemeMode.dark;

    // Base decoration from widget parameters
    var baseDecoration = widget.decoration ??
        BoxDecoration(
          color: widget.color,
          gradient: widget.gradient,
          border: widget.border,
          borderRadius: widget.borderRadius,
          boxShadow: widget.boxShadow,
        );

    // Add hover effects
    if (_isHovering && widget.enableHoverEffect) {
      final hoverShadow = BoxShadow(
        color: selectionColor.withOpacity(0.3),
        blurRadius: widget.hoverElevation,
        spreadRadius: 2,
        offset: const Offset(0, 4),
      );

      baseDecoration = baseDecoration.copyWith(
        boxShadow: [
          ...?baseDecoration.boxShadow,
          hoverShadow,
        ],
        gradient: baseDecoration.gradient ?? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  selectionColor.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
      );
    }

    // Add animated border if enabled
    if (widget.enableBorderAnimation) {
      final borderColor = Color.lerp(
        selectionColor.withOpacity(0.3),
        selectionColor.withOpacity(0.7),
        _borderAnimation.value,
      );

      baseDecoration = baseDecoration.copyWith(
        border: Border.all(
          color: borderColor!,
          width: 2.0,
          strokeAlign: BorderSide.strokeAlignCenter,
        ),
      );
    }

    return baseDecoration;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTapHandler = widget.onTap != null;
    final bool allowEffects = !_reduceEffects;
    final Duration animationDuration =
        _reduceMotion ? AppPerformance.animationDuration : widget.animationDuration;

    return Semantics(
      label: widget.semanticLabel,
      button: hasTapHandler,
      enabled: true,
      child: MouseRegion(
        onEnter: (_) => _handleHover(true),
        onExit: (_) => _handleHover(false),
        cursor: hasTapHandler ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: widget.margin,
            constraints: widget.constraints,
            child: AnimatedContainer(
              duration: animationDuration,
              curve: widget.animationCurve,
              width: widget.width,
              height: widget.height,
              padding: widget.padding,
              alignment: widget.alignment,
              clipBehavior: widget.clipBehavior,
              transform: widget.transform,
              transformAlignment: widget.transformAlignment,
              decoration: _buildDecoration(context),
              child: Stack(
                children: [
                  // Particle background
                  if (widget.enableParticles && allowEffects)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildParticleBackground(constraints.biggest);
                      },
                    ),

                  // Main content with optional glass effect
                  if (widget.enableGlassEffect && allowEffects)
                    _buildGlassEffect(
                      child: widget.child ?? const SizedBox.shrink(),
                    )
                  else
                    widget.child ?? const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Specialized glassmorphic container with premium effects
class GlassContainer extends ConsumerWidget {
  const GlassContainer({
    required this.child, super.key,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.borderColor,
    this.blurStrength = 15.0,
    this.enableHoverEffect = true,
    this.enableBorderAnimation = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry borderRadius;
  final Color? borderColor;
  final double blurStrength;
  final bool enableHoverEffect;
  final bool enableBorderAnimation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectionColor = ref.watch(navIconColorProvider);
    final isDark = theme.brightness == Brightness.dark;
    final bool reduceEffects = PerformanceConfig.of(context).reduceEffects;

    return AnimatedThemeContainer(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      enableGlassEffect: true,
      glassBlurSigma: reduceEffects
          ? AppPerformance.glassBlurSigma
          : blurStrength,
      enableHoverEffect: enableHoverEffect && !reduceEffects,
      enableBorderAnimation: enableBorderAnimation && !reduceEffects,
      borderAnimationDuration: const Duration(milliseconds: 1500),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(reduceEffects ? 0.04 : 0.08)
            : Colors.white.withOpacity(reduceEffects ? 0.12 : 0.25),
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor ?? selectionColor.withOpacity(reduceEffects ? 0.12 : 0.2),
          width: 1.5,
        ),
        gradient: reduceEffects
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(isDark ? 0.15 : 0.4),
                  Colors.white.withOpacity(isDark ? 0.05 : 0.2),
                ],
              ),
        boxShadow: reduceEffects
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: child,
    );
  }
}

/// Gradient container with animated transitions
class GradientContainer extends StatelessWidget {
  const GradientContainer({
    required this.child, super.key,
    this.padding,
    this.margin,
    this.borderRadius,
    this.gradient,
    this.enableAnimation = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry? borderRadius;
  final Gradient? gradient;
  final bool enableAnimation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        theme.colorScheme.primary.withOpacity(0.8),
        theme.colorScheme.secondary.withOpacity(0.6),
      ],
    );

    return AnimatedThemeContainer(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      gradient: gradient ?? defaultGradient,
      animationDuration:
          enableAnimation ? const Duration(milliseconds: 500) : Duration.zero,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Card-style container with elevation and hover effects
class PremiumCard extends ConsumerWidget {
  const PremiumCard({
    required this.child, super.key,
    this.padding = const EdgeInsets.all(24),
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.elevation = 8.0,
    this.enableHover = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry borderRadius;
  final double elevation;
  final bool enableHover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedThemeContainer(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      enableHoverEffect: enableHover,
      hoverElevation: elevation * 1.5,
      color: theme.colorScheme.surface,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
          blurRadius: elevation,
          spreadRadius: elevation / 3,
          offset: Offset(0, elevation / 2),
        ),
      ],
      border: Border.all(
        color: theme.colorScheme.outline.withOpacity(0.1),
      ),
      child: child,
    );
  }
}
