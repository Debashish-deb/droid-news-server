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

  ParticlePainter({
    required this.particles,
    required this.animationValue,
  });
  final List<Particle> particles;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      final offsetY = (particle.y + animationValue * particle.speed) % 1.0;
      final opacity = particle.color.opacity *
          (0.5 + 0.5 * sin(animationValue * 2 * pi + particle.x * pi));

      paint.color = particle.color.withOpacity(opacity);

      canvas.drawCircle(
        Offset(particle.x * size.width, offsetY * size.height),
        particle.size * (1 + 0.3 * sin(animationValue * pi)),
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
