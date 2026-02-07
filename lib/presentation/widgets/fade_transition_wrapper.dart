
import 'dart:ui';
import 'package:flutter/material.dart';

class FadeTransitionWrapper extends PageRouteBuilder {
  FadeTransitionWrapper({required this.child})
    : super(
        transitionDuration: const Duration(milliseconds: 800),
        reverseTransitionDuration: const Duration(milliseconds: 500),
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) => child,
        transitionsBuilder: (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          
          final Animation<double> blur = Tween<double>(
            begin: 0,
            end: 8,
          ).animate(
            CurvedAnimation(parent: animation, curve: const Interval(0, 0.5)),
          );
          final Animation<double> frostOpacity = Tween<double>(
            begin: 0,
            end: 0.1,
          ).animate(
            CurvedAnimation(parent: animation, curve: const Interval(0, 0.5)),
          );

          final CurvedAnimation fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          final Animation<double> scale = Tween<double>(
            begin: 0.95,
            end: 1.0,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          );

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: blur.value,
                  sigmaY: blur.value,
                ),
                child: Container(
                  color: Colors.white.withOpacity(frostOpacity.value),
                ),
              ),

              FadeTransition(
                opacity: fade,
                child: ScaleTransition(scale: scale, child: child),
              ),
            ],
          );
        },
      );

  final Widget child;
}
