import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({
    super.key,
    this.duration = const Duration(seconds: 20),
    this.child,
    this.overlayOpacity = 0.3,
  });

  final Duration duration;
  final Widget? child;
  final double overlayOpacity;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  List<double> getAnimatedStops(double value) {
    return <double>[
      0.1 + value * 0.3,
      0.3 + value * 0.2,
      0.6 - value * 0.2,
      0.9 - value * 0.3,
    ];
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _buildDynamicGradient(ColorScheme colorScheme) {
    return [
      colorScheme.primary.withOpacity(0.6),
      colorScheme.secondary.withOpacity(0.5),
      colorScheme.tertiary.withOpacity(0.4),
      colorScheme.primaryContainer.withOpacity(0.3),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final gradientColors = _buildDynamicGradient(colorScheme);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/theme/image1.png',
              fit: BoxFit.cover,
            ),
            Container(
              color: Colors.black.withOpacity(widget.overlayOpacity),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: getAnimatedStops(_controller.value),
                  tileMode: TileMode.mirror,
                ),
              ),
            ),
            if (widget.child != null) widget.child!,
          ],
        );
      },
    );
  }
}
