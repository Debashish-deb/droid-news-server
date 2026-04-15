import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum MaterialSurfaceTone { low, medium, high, highest }

bool preferAndroidMaterialSurfaceChrome(BuildContext context) {
  if (kIsWeb) return false;
  final theme = Theme.of(context);
  return theme.useMaterial3 && theme.platform == TargetPlatform.android;
}

Color materialSurfaceOverlayColor(
  ColorScheme scheme, {
  MaterialSurfaceTone tone = MaterialSurfaceTone.high,
  double surfaceAlpha = 0.96,
  double tintAlpha = 0.08,
}) {
  final base = switch (tone) {
    MaterialSurfaceTone.low => scheme.surfaceContainerLow,
    MaterialSurfaceTone.medium => scheme.surfaceContainer,
    MaterialSurfaceTone.high => scheme.surfaceContainerHigh,
    MaterialSurfaceTone.highest => scheme.surfaceContainerHighest,
  };

  return Color.alphaBlend(
    scheme.surfaceTint.withValues(alpha: tintAlpha),
    base.withValues(alpha: surfaceAlpha),
  );
}
