// lib/core/widgets/accessible_button.dart
// =========================================
// ACCESSIBLE BUTTON WITH SEMANTICS
// =========================================

import 'package:flutter/material.dart';

/// Button wrapper with proper accessibility semantics
class AccessibleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final String? semanticHint;
  final bool excludeSemantics;

  const AccessibleButton({
    required this.child,
    required this.semanticLabel,
    this.onPressed,
    this.semanticHint,
    this.excludeSemantics = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: true,
      enabled: onPressed != null,
      excludeSemantics: excludeSemantics,
      child: InkWell(
        onTap: onPressed,
        child: child,
      ),
    );
  }
}

/// Image with accessibility semantics
class AccessibleImage extends StatelessWidget {
  final ImageProvider image;
  final String semanticLabel;
  final double? width;
  final double? height;
  final BoxFit fit;

  const AccessibleImage({
    required this.image,
    required this.semanticLabel,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Image(
        image: image,
        width: width,
        height: height,
        fit: fit,
        semanticLabel: semanticLabel,
      ),
    );
  }
}

/// Icon with accessibility semantics
class AccessibleIcon extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final double? size;
  final Color? color;

  const AccessibleIcon({
    required this.icon,
    required this.semanticLabel,
    this.size,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Icon(
        icon,
        size: size,
        color: color,
        semanticLabel: semanticLabel,
      ),
    );
  }
}
