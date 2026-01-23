import 'package:flutter/material.dart';

/// Premium badge widget with glow effect for Pro users
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key, this.size = 80, this.glowIntensity = 0.6});

  final double size;
  final double glowIntensity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFD700), // Gold
            Color(0xFFFFA500), // Orange-gold
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(glowIntensity),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Icon(Icons.stars_rounded, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}

/// Compact premium indicator for cards
class PremiumIndicator extends StatelessWidget {
  const PremiumIndicator({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(Icons.star, color: Colors.white, size: size * 0.6),
    );
  }
}
