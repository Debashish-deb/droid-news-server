import 'package:flutter/material.dart';
import '../engine/snake_engine.dart';
import 'board_painter.dart';

/// Optimized board widget - only repaints when game state changes
class SnakeBoard extends StatelessWidget {
  const SnakeBoard({
    required this.gameState,
    required this.snakeColor,
    required this.foodColor,
    required this.gridColor,
    required this.backgroundColor,
    super.key,
  });
  final ValueNotifier<GameState> gameState;
  final Color snakeColor;
  final Color foodColor;
  final Color gridColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gridColor.withOpacity(0.3), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ValueListenableBuilder<GameState>(
          valueListenable: gameState,
          builder: (context, state, _) {
            return AspectRatio(
              aspectRatio: 1.0,
              child: CustomPaint(
                painter: BoardPainter(
                  snake: state.snake,
                  food: state.food,
                  gridSize: state.gridSize,
                  snakeColor: snakeColor,
                  foodColor: foodColor,
                  gridColor: gridColor,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
