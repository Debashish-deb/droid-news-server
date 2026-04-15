import 'package:flutter/material.dart';



@immutable
class PremiumShellPalette extends ThemeExtension<PremiumShellPalette> {
  const PremiumShellPalette({
    required this.gradientStart,
    required this.gradientMid,
    required this.gradientEnd,
    required this.waveColor,
    required this.iconBackground,
    required this.iconBorder,
    required this.textColor,
    required this.subtitleColor,
    required this.glossColor,
    required this.borderColor,
    required this.headerGradient,
    required this.footerGradient,
    required this.glossGradient,
  });

  final Color gradientStart;
  final Color gradientMid;
  final Color gradientEnd;
  final Color waveColor;
  final Color iconBackground;
  final Color iconBorder;
  final Color textColor;
  final Color subtitleColor;
  final Color glossColor;
  final Color borderColor;
  final LinearGradient headerGradient;
  final LinearGradient footerGradient;
  final LinearGradient glossGradient;

  @override
  PremiumShellPalette copyWith({
    Color? gradientStart,
    Color? gradientMid,
    Color? gradientEnd,
    Color? waveColor,
    Color? iconBackground,
    Color? iconBorder,
    Color? textColor,
    Color? subtitleColor,
    Color? glossColor,
    Color? borderColor,
    LinearGradient? headerGradient,
    LinearGradient? footerGradient,
    LinearGradient? glossGradient,
  }) {
    return PremiumShellPalette(
      gradientStart: gradientStart ?? this.gradientStart,
      gradientMid: gradientMid ?? this.gradientMid,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      waveColor: waveColor ?? this.waveColor,
      iconBackground: iconBackground ?? this.iconBackground,
      iconBorder: iconBorder ?? this.iconBorder,
      textColor: textColor ?? this.textColor,
      subtitleColor: subtitleColor ?? this.subtitleColor,
      glossColor: glossColor ?? this.glossColor,
      borderColor: borderColor ?? this.borderColor,
      headerGradient: headerGradient ?? this.headerGradient,
      footerGradient: footerGradient ?? this.footerGradient,
      glossGradient: glossGradient ?? this.glossGradient,
    );
  }

  @override
  PremiumShellPalette lerp(
    ThemeExtension<PremiumShellPalette>? other,
    double t,
  ) {
    if (other is! PremiumShellPalette) return this;
    return PremiumShellPalette(
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientMid: Color.lerp(gradientMid, other.gradientMid, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      waveColor: Color.lerp(waveColor, other.waveColor, t)!,
      iconBackground: Color.lerp(iconBackground, other.iconBackground, t)!,
      iconBorder: Color.lerp(iconBorder, other.iconBorder, t)!,
      textColor: Color.lerp(textColor, other.textColor, t)!,
      subtitleColor: Color.lerp(subtitleColor, other.subtitleColor, t)!,
      glossColor: Color.lerp(glossColor, other.glossColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      headerGradient: LinearGradient.lerp(headerGradient, other.headerGradient, t)!,
      footerGradient: LinearGradient.lerp(footerGradient, other.footerGradient, t)!,
      glossGradient: LinearGradient.lerp(glossGradient, other.glossGradient, t)!,
    );
  }
}

