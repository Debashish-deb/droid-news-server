// lib/widgets/fade_transition_wrapper.dart

import 'package:flutter/material.dart';

class FadeTransitionWrapper extends PageRouteBuilder {
  
  FadeTransitionWrapper({required this.child})
      : super(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => child,
          transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
  final Widget child;
}
