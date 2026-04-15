import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'premium_shell_palette.dart';

import '../../core/theme/theme.dart' show AppThemeRulesExtension;

/// Full-screen theme transition that masks shell chrome repaint lag.
class ThemeWaveTransition extends StatefulWidget {
  const ThemeWaveTransition({
    required this.themeKey,
    required this.child,
    super.key,
    this.duration = const Duration(milliseconds: 1000),
  });

  final Object themeKey;
  final Widget child;
  final Duration duration;

  @override
  State<ThemeWaveTransition> createState() => ThemeWaveTransitionState();
}

class ThemeWaveTransitionState extends State<ThemeWaveTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final GlobalKey _boundaryKey = GlobalKey();
  
  ui.Image? _screenshot;
  bool _firstFrame = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _screenshot?.dispose();
        _screenshot = null;
        if (mounted) setState(() {});
      }
    });
  }

  /// Captures the current state of the child as a screenshot.
  /// This should be called BEFORE the theme mode is updated in the app state.
  Future<void> captureBeforeThemeChange() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      // We capture at the current device pixel ratio for maximum fidelity
      final pixelRatio = View.of(context).devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      if (mounted) {
        setState(() {
          _screenshot?.dispose();
          _screenshot = image;
        });
      }
    } catch (e) {
      debugPrint('ThemeWaveTransition: Capture failed: $e');
    }
  }

  @override
  void didUpdateWidget(covariant ThemeWaveTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_firstFrame) {
      _firstFrame = false;
      return;
    }
    if (oldWidget.themeKey != widget.themeKey) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _screenshot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }

    final visual = _ThemeWaveVisual.fromTheme(Theme.of(context));

    return RepaintBoundary(
      key: _boundaryKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_controller.isAnimating || _screenshot != null)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = _controller.value;
                  if (t >= 0.999 && _screenshot == null) {
                    return const SizedBox.shrink();
                  }

                  // We use a custom curve for the wave sweep to make it feel more "liquid"
                  final waveT = Curves.easeInOutCubic.transform(t);

                  return CustomPaint(
                    painter: _WavePainter(
                      progress: waveT,
                      screenshot: _screenshot,
                      baseColor: visual.baseTint,
                      waveColor: visual.waveTint,
                      topGlow: visual.topEdgeTint,
                      bottomGlow: visual.bottomEdgeTint,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.progress,
    required this.screenshot,
    required this.baseColor,
    required this.waveColor,
    required this.topGlow,
    required this.bottomGlow,
  });

  final double progress;
  final ui.Image? screenshot;
  final Color baseColor;
  final Color waveColor;
  final Color topGlow;
  final Color bottomGlow;

  @override
  void paint(Canvas canvas, Size size) {
    // waveHeight defines the vertical displacement of the ripple peaks
    final double waveHeight = size.height * 0.12; 
    // sweepY is the average vertical position of the wave front
    final double sweepY = (size.height + waveHeight * 2) * progress - waveHeight;
    
    final int segments = 4;
    final double segmentWidth = size.width / segments;

    // Helper to generate the wave path (bottom edge of the revealed area)
    Path createWavePath(double y) {
      final path = Path();
      path.moveTo(0, y);
      for (int i = 0; i < segments; i++) {
        final double x1 = (i + 0.5) * segmentWidth;
        final double x2 = (i + 1) * segmentWidth;
        final double yOffset = (i % 2 == 0 ? 1 : -1) * waveHeight * 0.4;
        path.quadraticBezierTo(x1, y + yOffset, x2, y);
      }
      return path;
    }

    final waveEdgePath = createWavePath(sweepY);

    // 1. If we have a screenshot, draw the "old" state on the un-revealed area
    if (screenshot != null) {
      final maskPath = Path();
      maskPath.moveTo(0, size.height);
      maskPath.lineTo(0, sweepY);
      
      // Append the wave edge
      for (int i = 0; i < segments; i++) {
        final double x1 = (i + 0.5) * segmentWidth;
        final double x2 = (i + 1) * segmentWidth;
        final double yOffset = (i % 2 == 0 ? 1 : -1) * waveHeight * 0.4;
        maskPath.quadraticBezierTo(x1, sweepY + yOffset, x2, sweepY);
      }
      
      maskPath.lineTo(size.width, size.height);
      maskPath.close();

      canvas.save();
      canvas.clipPath(maskPath);
      
      // Draw screenshot scaled to fit the canvas
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: screenshot!,
        fit: BoxFit.fill,
      );
      
      canvas.restore();
    }

    // 2. Draw the "Body" of the new theme color slightly overlapping the wave edge
    // This helps hide any minor alignment gaps between the screenshot and live child.
    final bodyPaint = Paint()..style = PaintingStyle.fill;
    final bodyPath = Path();
    bodyPath.moveTo(0, 0);
    bodyPath.lineTo(0, sweepY);
    for (int i = 0; i < segments; i++) {
      final double x1 = (i + 0.5) * segmentWidth;
      final double x2 = (i + 1) * segmentWidth;
      final double yOffset = (i % 2 == 0 ? 1 : -1) * waveHeight * 0.4;
      bodyPath.quadraticBezierTo(x1, sweepY + yOffset, x2, sweepY);
    }
    bodyPath.lineTo(size.width, 0);
    bodyPath.close();

    // Use a slight gradient at the edge of the new theme reveal
    bodyPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        baseColor.withValues(alpha: 0.1),
        baseColor.withValues(alpha: 0.8),
      ],
      stops: const [0.0, 0.7, 1.0],
    ).createShader(Rect.fromLTWH(0, sweepY - waveHeight, size.width, waveHeight * 2));
    
    canvas.drawPath(bodyPath, bodyPaint);

    // 3. Draw the "leading edge" glow/wave shimmer
    final shimmerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16.0);

    shimmerPaint.shader = LinearGradient(
      colors: [
        topGlow.withValues(alpha: 0.0),
        waveColor.withValues(alpha: 0.7),
        topGlow.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromLTWH(0, sweepY - waveHeight, size.width, waveHeight * 2));
    
    canvas.drawPath(waveEdgePath, shimmerPaint);
    
    // Add a sharper "sparkle" line at the very front
    final sparklePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = waveColor.withValues(alpha: 0.9);
    canvas.drawPath(waveEdgePath, sparklePaint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.screenshot != screenshot;
}

class _ThemeWaveVisual {
  const _ThemeWaveVisual({
    required this.baseTint,
    required this.waveTint,
    required this.topEdgeTint,
    required this.bottomEdgeTint,
  });

  factory _ThemeWaveVisual.fromTheme(ThemeData theme) {
    final rules = theme.extension<AppThemeRulesExtension>();
    final palette = theme.extension<PremiumShellPalette>()!;
    
    final baseTint = theme.scaffoldBackgroundColor;
    
    return _ThemeWaveVisual(
      baseTint: baseTint,
      waveTint: rules?.themeWaveColor ?? palette.waveColor,
      topEdgeTint: palette.gradientStart,
      bottomEdgeTint: palette.gradientEnd,
    );
  }

  final Color baseTint;
  final Color waveTint;
  final Color topEdgeTint;
  final Color bottomEdgeTint;
}


