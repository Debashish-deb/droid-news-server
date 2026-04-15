import 'dart:math';
import 'package:flutter/material.dart';

/// Particle class for background effects
class Particle {
  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.color,
  });
  final double x;
  final double y;
  final double size;
  final double speed;
  final Color color;
}

/// Particle painter for background effects
class ParticlePainter extends CustomPainter {
  ParticlePainter({required this.particles, required this.animationValue});
  final List<Particle> particles;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;
    final double pi2 = 2 * pi;
    final double sinAnim = sin(animationValue * pi);
    final double animPhase = animationValue * pi2;
    final double pulseScale = 1 + 0.3 * sinAnim;

    for (final particle in particles) {
      final offsetY = (particle.y + animationValue * particle.speed) % 1.0;

      // Opacity calculation with pre-computed phase
      final opacity =
          particle.color.opacity *
          (0.5 + 0.5 * sin(animPhase + particle.x * pi));

      paint.color = particle.color.withValues(alpha: opacity);

      canvas.drawCircle(
        Offset(particle.x * size.width, offsetY * size.height),
        particle.size * pulseScale,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.particles != particles;
  }
}
