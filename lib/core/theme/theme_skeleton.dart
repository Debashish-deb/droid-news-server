import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Shared non-color UI structure used across all app themes.
///
/// Color combinations come from active ThemeData / ColorScheme, while this
/// skeleton keeps geometry and sizing stable to minimize churn on theme swap.
@immutable
class ThemeSkeleton {
  const ThemeSkeleton({
    required this.cardRadius,
    required this.innerCardRadius,
    required this.chipRadius,
    required this.buttonRadius,
    required this.borderWidth,
    required this.emphasisBorderWidth,
    required this.minTouchTarget,
    required this.compactTouchTarget,
    required this.glassShadowBlurRadius,
    required this.glassShadowOffsetY,
    required this.glassShadowSpreadRadius,
  });

  final double cardRadius;
  final double innerCardRadius;
  final double chipRadius;
  final double buttonRadius;
  final double borderWidth;
  final double emphasisBorderWidth;
  final double minTouchTarget;
  final double compactTouchTarget;
  final double glassShadowBlurRadius;
  final double glassShadowOffsetY;
  final double glassShadowSpreadRadius;

  @pragma('vm:prefer-inline')
  BorderRadius circular(double radius) => BorderRadius.circular(radius);

  @pragma('vm:prefer-inline')
  Radius radius(double value) => Radius.circular(value);

  @pragma('vm:prefer-inline')
  EdgeInsets insetsAll(double value) => EdgeInsets.all(value);

  @pragma('vm:prefer-inline')
  EdgeInsets insetsSymmetric({double horizontal = 0, double vertical = 0}) =>
      EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);

  @pragma('vm:prefer-inline')
  EdgeInsets insetsOnly({
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) => EdgeInsets.only(left: left, top: top, right: right, bottom: bottom);

  BorderRadius get cardBorderRadius => BorderRadius.circular(cardRadius);
  BorderRadius get innerCardBorderRadius =>
      BorderRadius.circular(innerCardRadius);
  BorderRadius get chipBorderRadius => BorderRadius.circular(chipRadius);
  BorderRadius get buttonBorderRadius => BorderRadius.circular(buttonRadius);

  // Const-friendly skeleton tokens for constructor defaults.
  static const EdgeInsets insetsAll1p5 = EdgeInsets.all(1.5);
  static const EdgeInsets insetsAll4 = EdgeInsets.all(4);
  static const EdgeInsets insetsAll8 = EdgeInsets.all(8);
  static const EdgeInsets insetsAll20 = EdgeInsets.all(20);
  static const EdgeInsets insetsAll24 = EdgeInsets.all(24);
  static const EdgeInsets insetsH12 = EdgeInsets.symmetric(horizontal: 12);
  static const EdgeInsets insetsH12V6 = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 6,
  );
  static const EdgeInsets insetsV8 = EdgeInsets.symmetric(vertical: 8);
  static const BorderRadius borderRadius20 = BorderRadius.all(
    Radius.circular(20),
  );
  static const BorderRadius borderRadius24 = BorderRadius.all(
    Radius.circular(24),
  );
  static const double size2 = 2;
  static const double size4 = 4;
  static const double size5 = 5;
  static const double size6 = 6;
  static const double size8 = 8;
  static const double size10 = 10;
  static const double size12 = 12;
  static const double size16 = 16;
  static const double size20 = 20;
  static const double size24 = 24;
  static const double size28 = 28;
  static const double size32 = 32;
  static const double size36 = 36;
  static const double size39 = 39;
  static const double size220 = 220;

  static const ThemeSkeleton shared = ThemeSkeleton(
    cardRadius: AppRadius.xl + 4, // 24
    innerCardRadius: AppRadius.xl + 2, // 22
    chipRadius: AppRadius.xxl, // 28
    buttonRadius: AppRadius.md, // 12
    borderWidth: AppBorders.regular, // 1.5
    emphasisBorderWidth: AppBorders.thick, // 2.0
    minTouchTarget: AppSize.minTouchTarget, // 48
    compactTouchTarget: AppSize.compactTouchTarget, // 44
    glassShadowBlurRadius: 10,
    glassShadowOffsetY: 4,
    glassShadowSpreadRadius: 0,
  );
}
