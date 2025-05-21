// lib/widgets/fade_transition_wrapper.dart

import 'dart:ui';
import 'package:flutter/material.dart';

/// A page route that “crystalizes” the transition:
/// 1) Blurs the old page behind a frosted overlay.
/// 2) Fades and gently scales in the new page.
class FadeTransitionWrapper extends PageRouteBuilder {
  FadeTransitionWrapper({required this.child})
      : super(
          transitionDuration: const Duration(milliseconds: 800),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              child,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            // 1) Frosted blur overlay on the old page:
            final blur = Tween<double>(begin: 0, end: 8).animate(
              CurvedAnimation(parent: animation, curve: const Interval(0, 0.5)),
            );
            final frostOpacity = Tween<double>(begin: 0, end: 0.1).animate(
              CurvedAnimation(parent: animation, curve: const Interval(0, 0.5)),
            );

            // 2) Fade and scale the incoming page:
            final fade = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
            final scale = Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                // The old page is still in the background; we just blur+frost it.
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur.value, sigmaY: blur.value),
                  child: Container(color: Colors.white.withOpacity(frostOpacity.value)),
                ),

                // Then bring in the new child with fade+scale:
                FadeTransition(
                  opacity: fade,
                  child: ScaleTransition(
                    scale: scale,
                    alignment: Alignment.center,
                    child: child,
                  ),
                ),
              ],
            );
          },
        );

  final Widget child;
}
