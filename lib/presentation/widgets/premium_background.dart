import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/config/performance_config.dart';
import '../../core/theme/theme.dart' show AppColorsExtension;
import 'premium_shell_palette.dart';

/// A reusable premium background that applies theme-aware gradients and
/// decorative particle effects based on device performance.
class PremiumBackground extends StatefulWidget {
  const PremiumBackground({
    this.child,
    this.showParticles = true,
    this.opacity = 1.0,
    super.key,
  });

  final Widget? child;
  final bool showParticles;
  final double opacity;

  @override
  State<PremiumBackground> createState() => _PremiumBackgroundState();
}

class _PremiumBackgroundState extends State<PremiumBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _particleController;
  List<Particle>? _particles;
  bool _particlesEnabled = false;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeEnableParticles();
  }

  void _maybeEnableParticles() {
    if (!widget.showParticles) {
      _disableParticles();
      return;
    }

    final perf = PerformanceConfig.of(context);
    final enabled = !perf.reduceEffects &&
        !perf.reduceMotion &&
        !perf.lowPowerMode &&
        !perf.isLowEndDevice &&
        perf.performanceTier == DevicePerformanceTier.flagship;

    if (enabled == _particlesEnabled) return;

    if (enabled) {
      _particles ??= _buildParticles();
      _particleController.repeat();
    } else {
      _disableParticles();
    }
    _particlesEnabled = enabled;
  }

  void _disableParticles() {
    _particleController.stop();
  }

  List<Particle> _buildParticles() {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    return List.generate(
      6,
      (_) => Particle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        size: _rng.nextDouble() * 3 + 1,
        speed: _rng.nextDouble() * 0.10 + 0.03,
        delay: _rng.nextDouble() * 2,
        color: colors.textPrimary.withValues(
          alpha: _rng.nextDouble() * 0.12 + 0.04,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shellPalette = theme.extension<PremiumShellPalette>()!;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Gradient Layer ──────────────────────────────────────────────────
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    shellPalette.gradientStart.withValues(alpha: widget.opacity),
                    shellPalette.footerGradient.colors[2]
                        .withValues(alpha: widget.opacity),
                  ],
                ),
              ),
              child: _particlesEnabled && _particles != null
                  ? _ParticleBackground(
                      particles: _particles!,
                      controller: _particleController,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),

        // ── Content Layer ───────────────────────────────────────────────────
        if (widget.child != null) Positioned.fill(child: widget.child!),
      ],
    );
  }
}

class _ParticleBackground extends StatelessWidget {
  const _ParticleBackground({
    required this.particles,
    required this.controller,
  });

  final List<Particle> particles;
  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) => CustomPaint(
        painter: _ParticlePainter(particles: particles, t: controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.particles, required this.t});

  final List<Particle> particles;
  final double t;
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final time = t + p.delay;
      final yFrac = (p.y + time * p.speed) % 1.0;
      final opacity = p.color.opacity *
          (0.5 + 0.5 * math.sin(time * math.pi * 2 + p.x * math.pi));
      final r = p.size *
          (1 + 0.15 * math.sin(time * math.pi * 2 + p.delay * math.pi));

      _paint.color = p.color.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, yFrac * size.height),
        r,
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

class Particle {
  const Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.delay,
    required this.color,
  });

  final double x;
  final double y;
  final double size;
  final double speed;
  final double delay;
  final Color color;
}
