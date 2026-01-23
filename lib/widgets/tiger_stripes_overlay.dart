// lib/widgets/tiger_stripes_overlay.dart
// A decorative overlay that adds subtle Bengal Tiger stripes to cards
// Only visible in Bangladesh theme mode

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class TigerStripesOverlay extends StatelessWidget {
  const TigerStripesOverlay({
    super.key,
    this.opacity = 0.08,
    this.stripeWidth = 3.0,
    this.stripeSpacing = 12.0,
    this.stripeColor,
  });

  final double opacity;
  final double stripeWidth;
  final double stripeSpacing;
  final Color? stripeColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Enterprise default: pulls from theme, but keeps your orange feel if desired.
    final resolvedColor = stripeColor ?? scheme.primary;

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: CustomPaint(
            isComplex: true,
            painter: _TigerStripesPainter(
              opacity: opacity.clamp(0.0, 1.0),
              stripeWidth: stripeWidth <= 0 ? 1 : stripeWidth,
              stripeSpacing: stripeSpacing <= 0 ? 8 : stripeSpacing,
              stripeColor: resolvedColor,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _TigerStripesPainter extends CustomPainter {
  _TigerStripesPainter({
    required this.opacity,
    required this.stripeWidth,
    required this.stripeSpacing,
    required this.stripeColor,
  });

  final double opacity;
  final double stripeWidth;
  final double stripeSpacing;
  final Color stripeColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // ---- Deterministic seed so pattern stays stable per size/params ----
    final seed = _seedFor(size, stripeColor, stripeWidth, stripeSpacing);
    final rng = math.Random(seed);

    // ---- Enterprise “printed into card” blending layer ----
    final layerPaint = Paint()..blendMode = BlendMode.softLight;
    canvas.saveLayer(Offset.zero & size, layerPaint);

    // ---- Stripe shader (subtle gradient depth) ----
    final base = stripeColor;
    final shader = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(size.width, size.height),
      [
        base.withOpacity(opacity * 0.30),
        base.withOpacity(opacity * 0.95),
        base.withOpacity(opacity * 0.20),
      ],
      const [0.0, 0.55, 1.0],
    );

    // Two-pass stroke: shadow-ish + highlight-ish (still subtle)
    final strokeBack =
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true
          ..strokeWidth = stripeWidth * 1.15;

    final strokeFront =
        Paint()
          ..color = base.withOpacity(opacity * 0.90)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true
          ..strokeWidth = stripeWidth * 0.70;

    // ---- Organic stripe layout ----
    // Maintain your spacing intent, but with curved “tiger” feel.
    final total = size.width + size.height;
    final step = math.max(2.0, stripeWidth + stripeSpacing);

    // Cap stripe count for very large canvases (perf safety)
    const maxStripes = 140;
    int stripeCount = 0;

    for (double i = 0; i < total && stripeCount < maxStripes; i += step) {
      stripeCount++;

      // Original edge logic (keeps your structure), then “enterprise” curvature.
      final start = _startPoint(i, size);
      final end = _endPoint(i, size);

      // Tiger stripes are not perfect lines:
      // add a mild curvature + a pinch (like a claw stroke).
      final path = Path()..moveTo(start.dx, start.dy);

      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;

      // Curvature magnitude scales with card size but stays subtle.
      final len = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      final normal = Offset(-dy / len, dx / len);

      // Variation per stripe (deterministic)
      final curve =
          _lerp(6.0, 18.0, rng.nextDouble()) *
          (math.min(size.width, size.height) / 360.0).clamp(0.7, 1.25);

      final pinch = _lerp(0.15, 0.35, rng.nextDouble()); // “tiger pinch”
      final mid = Offset(start.dx + dx * 0.5, start.dy + dy * 0.5);

      final c1 = Offset(
        start.dx + dx * (0.30 - pinch * 0.08) + normal.dx * curve,
        start.dy + dy * (0.30 - pinch * 0.08) + normal.dy * curve,
      );

      final c2 = Offset(
        start.dx + dx * (0.70 + pinch * 0.08) - normal.dx * curve,
        start.dy + dy * (0.70 + pinch * 0.08) - normal.dy * curve,
      );

      // A tiny “kink” near the middle helps it feel organic.
      final kink = normal * (_lerp(-4.0, 4.0, rng.nextDouble()));
      final kinkMid = mid + kink;

      path
        ..cubicTo(c1.dx, c1.dy, kinkMid.dx, kinkMid.dy, mid.dx, mid.dy)
        ..cubicTo(kinkMid.dx, kinkMid.dy, c2.dx, c2.dy, end.dx, end.dy);

      // Back pass adds depth
      canvas.drawPath(path, strokeBack);

      // Front pass adds crispness (still subtle)
      canvas.drawPath(path, strokeFront);
    }

    // ---- Micro-noise texture (very subtle) ----
    // Makes the overlay feel like it’s part of the surface.
    _drawMicroNoise(canvas, size, rng, base, opacity);

    canvas.restore(); // softLight layer
  }

  static int _seedFor(Size size, Color c, double w, double s) {
    // Deterministic seed: stable across frames for the same card.
    final a = size.width.round() * 73856093;
    final b = size.height.round() * 19349663;
    final col = c.value * 83492791;
    final ww = (w * 1000).round() * 2654435761;
    final ss = (s * 1000).round() * 1597334677;
    return (a ^ b ^ col ^ ww ^ ss) & 0x7fffffff;
  }

  static Offset _startPoint(double i, Size size) {
    if (i < size.width) {
      return Offset(i, 0);
    }
    return Offset(size.width, i - size.width);
    // (top edge or right edge)
  }

  static Offset _endPoint(double i, Size size) {
    if (i < size.height) {
      return Offset(0, i);
    }
    return Offset(i - size.height, size.height);
    // (left edge or bottom edge)
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static void _drawMicroNoise(
    Canvas canvas,
    Size size,
    math.Random rng,
    Color base,
    double opacity,
  ) {
    // Keep it subtle + capped for perf.
    final area = size.width * size.height;
    final density = (area / 18000.0).clamp(25.0, 140.0); // enterprise-safe cap
    final pointsCount = density.toInt();

    final light =
        Paint()
          ..color = Colors.white.withOpacity(opacity * 0.10)
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.softLight
          ..isAntiAlias = true;

    final dark =
        Paint()
          ..color = base.withOpacity(opacity * 0.10)
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.softLight
          ..isAntiAlias = true;

    for (int i = 0; i < pointsCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final p = Offset(x, y);

      // Alternate light/dark specks for natural texture
      canvas.drawPoints(ui.PointMode.points, [p], (i.isEven ? light : dark));
    }
  }

  @override
  bool shouldRepaint(covariant _TigerStripesPainter oldDelegate) {
    return oldDelegate.opacity != opacity ||
        oldDelegate.stripeWidth != stripeWidth ||
        oldDelegate.stripeSpacing != stripeSpacing ||
        oldDelegate.stripeColor != stripeColor;
  }
}
