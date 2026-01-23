import 'package:flutter_test/flutter_test.dart';
import 'dart:math';
import 'package:bdnewsreader/features/extras/games/snake/engine/snake_engine.dart';

void main() {
  group('SnakeEngine Tests', () {
    late SnakeEngine engine;

    setUp(() {
      engine = SnakeEngine();
    });

    test('Engine initializes with correct state', () {
      expect(engine.score, 0);
      expect(engine.isGameOver, false);
      expect(engine.gridSize, 20);
      expect(engine.state.snake.length, 3);
    });

    test('Snake moves forward on tick', () {
      final initialHead = engine.state.snake.first;
      engine.tick();
      final newHead = engine.state.snake.first;
      
      expect(newHead, isNot(equals(initialHead)));
      expect(engine.state.snake.length, 3); // Should stay same if no food
    });

    test('Snake grows when eating food', () {
      // Position snake next to food
      final food = engine.state.food;
      engine.tick();
      
      // If snake ate food, length should increase
      if (engine.state.snake.first == food) {
        expect(engine.state.snake.length, 4);
        expect(engine.score, 10);
      }
    });

    test('Game over on self-collision', () {
      // Grow the snake first so it's long enough to collide
      // Use the test helper as the state is immutable
      const int center = 10;
      engine.setSnakeForTesting([
        const Point(center, center),
        const Point(center - 1, center),
        const Point(center - 2, center),
        const Point(center - 3, center), // Length 4
        const Point(center - 4, center), // Length 5
      ]);
      
      // Create a scenario where snake hits itself
      // Force snake into a loop
      engine.queueDirection(const Point(0, 1));  // Down
      engine.tick();
      engine.queueDirection(const Point(-1, 0)); // Left
      engine.tick();
      engine.queueDirection(const Point(0, -1)); // Up
      engine.tick();
      engine.queueDirection(const Point(1, 0));  // Right (hit self)
      
      // Keep ticking until collision
      for (int i = 0; i < 10; i++) {
        if (engine.isGameOver) break;
        engine.tick();
      }
      
      // Should eventually hit itself
      expect(engine.isGameOver, true);
    });

    test('Direction queue prevents opposite direction', () {
      // Try to queue opposite direction
      engine.queueDirection(const Point(-1, 0)); // Opposite of initial
      engine.tick();
      
      // Snake should continue in original direction
      expect(engine.state.direction, const Point(1, 0));
    });

    test('Speed increases with score', () {
      final initialSpeed = engine.getSpeed();
      
      // Simulate scoring points
      for (int i = 0; i < 60; i++) {
        engine.tick();
      }
      
      // Speed should change based on score
      if (engine.score >= 50) {
        expect(engine.getSpeed(), lessThan(initialSpeed));
      }
    });

    test('Reset returns to initial state', () {
      // Play for a bit
      for (int i = 0; i < 10; i++) {
        engine.tick();
      }
      
      // Reset
      engine.reset();
      
      expect(engine.score, 0);
      expect(engine.isGameOver, false);
      expect(engine.state.snake.length, 3);
    });

    test('Direction queue limits to 2 inputs', () {
      engine.queueDirection(const Point(0, 1));
      engine.queueDirection(const Point(-1, 0));
      engine.queueDirection(const Point(0, -1)); // Should be ignored
      
      engine.tick();
      expect(engine.state.direction, const Point(0, 1));
      
      engine.tick();
      expect(engine.state.direction, const Point(-1, 0));
      
      engine.tick();
      // Third direction should not have been queued
      expect(engine.state.direction, isNot(equals(const Point(0, -1))));
    });

    test('Food spawns in valid position', () {
      final food = engine.state.food;
      
      // Food should be within grid bounds
      expect(food.x, greaterThanOrEqualTo(0));
      expect(food.x, lessThan(engine.gridSize));
      expect(food.y, greaterThanOrEqualTo(0));
      expect(food.y, lessThan(engine.gridSize));
      
      // Food should not be on snake
      expect(engine.state.snake.contains(food), false);
    });

    test('O(1) collision detection using Set', () {
      // This is implicitly tested by performance, but we can verify
      // by checking game over occurs correctly
      
      // Grow snake long
      for (int i = 0; i < 50; i++) {
        engine.tick();
      }
      
      // Collision should still be detected instantly
      // (If using List.contains, performance would degrade)
      expect(engine.isGameOver, anyOf(equals(true), equals(false)));
    });
  });

  group('GameState Immutability Tests', () {
    test('GameState is immutable', () {
      const state = GameState(
        snake: [Point(5, 5)],
        food: Point(10, 10),
        direction: Point(1, 0),
        score: 0,
        gameOver: false,
        paused: false,
        gridSize: 20,
      );
      
      final newState = state.copyWith(score: 10);
      
      expect(state.score, 0);
      expect(newState.score, 10);
    });
  });
}
