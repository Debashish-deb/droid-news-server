import 'dart:math';
import 'package:flutter/material.dart';

/// Custom painter for efficient board rendering
class BoardPainter extends CustomPainter {
  const BoardPainter({
    required this.snake,
    required this.food,
    required this.gridSize,
    required this.snakeColor,
    required this.foodColor,
    required this.gridColor,
  });
  final List<Point<int>> snake;
  final Point<int> food;
  final int gridSize;
  final Color snakeColor;
  final Color foodColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double cellSize = size.width / gridSize;

    // Draw grid (subtle)
    final gridPaint =
        Paint()
          ..color = gridColor
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke;

    for (int i = 0; i <= gridSize; i++) {
      final double pos = i * cellSize;
      // Vertical lines
      canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), gridPaint);
      // Horizontal lines
      canvas.drawLine(Offset(0, pos), Offset(size.width, pos), gridPaint);
    }

    // Draw food (circle)
    final foodPaint =
        Paint()
          ..color = foodColor
          ..style = PaintingStyle.fill;

    final foodCenter = Offset(
      food.x * cellSize + cellSize / 2,
      food.y * cellSize + cellSize / 2,
    );
    canvas.drawCircle(foodCenter, cellSize * 0.4, foodPaint);

    // Draw snake
    final snakePaint =
        Paint()
          ..color = snakeColor
          ..style = PaintingStyle.fill;

    for (int i = 0; i < snake.length; i++) {
      final segment = snake[i];
      final rect = Rect.fromLTWH(
        segment.x * cellSize + 1,
        segment.y * cellSize + 1,
        cellSize - 2,
        cellSize - 2,
      );

      // Head is slightly different (rounder)
      if (i == 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.3)),
          snakePaint,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.15)),
          snakePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) {
    return snake != oldDelegate.snake ||
        food != oldDelegate.food ||
        gridSize != oldDelegate.gridSize;
  }
}
