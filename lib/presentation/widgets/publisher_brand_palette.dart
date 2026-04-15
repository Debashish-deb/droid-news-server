import 'package:flutter/material.dart';

@immutable
class PublisherBrandPalette extends ThemeExtension<PublisherBrandPalette> {
  const PublisherBrandPalette({
    required this.surfaceTop,
    required this.surfaceBottom,
    required this.surfaceBorder,
    required this.accent,
    required this.favoriteGlow,
    required this.ambientGlow,
    required this.shadow,
  });

  final Color surfaceTop;
  final Color surfaceBottom;
  final Color surfaceBorder;
  final Color accent;
  final Color favoriteGlow;
  final Color ambientGlow;
  final Color shadow;

  @override
  PublisherBrandPalette copyWith({
    Color? surfaceTop,
    Color? surfaceBottom,
    Color? surfaceBorder,
    Color? accent,
    Color? favoriteGlow,
    Color? ambientGlow,
    Color? shadow,
  }) {
    return PublisherBrandPalette(
      surfaceTop: surfaceTop ?? this.surfaceTop,
      surfaceBottom: surfaceBottom ?? this.surfaceBottom,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      accent: accent ?? this.accent,
      favoriteGlow: favoriteGlow ?? this.favoriteGlow,
      ambientGlow: ambientGlow ?? this.ambientGlow,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  PublisherBrandPalette lerp(
    ThemeExtension<PublisherBrandPalette>? other,
    double t,
  ) {
    if (other is! PublisherBrandPalette) return this;
    return PublisherBrandPalette(
      surfaceTop: Color.lerp(surfaceTop, other.surfaceTop, t)!,
      surfaceBottom: Color.lerp(surfaceBottom, other.surfaceBottom, t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      favoriteGlow: Color.lerp(favoriteGlow, other.favoriteGlow, t)!,
      ambientGlow: Color.lerp(ambientGlow, other.ambientGlow, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}
