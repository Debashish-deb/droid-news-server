import 'dart:collection';
import 'dart:math';

/// Immutable game state snapshot
class GameState {
  const GameState({
    required this.snake,
    required this.food,
    required this.direction,
    required this.score,
    required this.gameOver,
    required this.paused,
    required this.gridSize,
  });
  final List<Point<int>> snake;
  final Point<int> food;
  final Point<int> direction;
  final int score;
  final bool gameOver;
  final bool paused;
  final int gridSize;

  GameState copyWith({
    List<Point<int>>? snake,
    Point<int>? food,
    Point<int>? direction,
    int? score,
    bool? gameOver,
    bool? paused,
    int? gridSize,
  }) {
    return GameState(
      snake: snake ?? this.snake,
      food: food ?? this.food,
      direction: direction ?? this.direction,
      score: score ?? this.score,
      gameOver: gameOver ?? this.gameOver,
      paused: paused ?? this.paused,
      gridSize: gridSize ?? this.gridSize,
    );
  }
}

/// Pure game logic engine - no UI dependencies
class SnakeEngine {
  // Input buffering

  SnakeEngine({int gridSize = 20}) {
    _gridSize = gridSize;
    reset();
  }
  late List<Point<int>> _snake;
  late Set<Point<int>> _snakeSet; // O(1) collision detection
  late Point<int> _food;
  late Point<int> _direction;
  late Point<int> _nextDirection;
  late int _score;
  late bool _gameOver;
  late int _gridSize;

  final Random _random = Random();
  final Queue<Point<int>> _directionQueue = Queue();

  /// Get current immutable state
  GameState get state => GameState(
    snake: List.unmodifiable(_snake),
    food: _food,
    direction: _direction,
    score: _score,
    gameOver: _gameOver,
    paused: false,
    gridSize: _gridSize,
  );

  /// Reset game to initial state
  void reset() {
    final int center = _gridSize ~/ 2;
    _snake = [
      Point(center, center),
      Point(center - 1, center),
      Point(center - 2, center),
    ];
    _snakeSet = _snake.toSet();
    _direction = const Point(1, 0); // Moving right
    _nextDirection = _direction;
    _directionQueue.clear();
    _score = 0;
    _gameOver = false;
    _generateFood();
  }

  /// Queue direction change (prevents opposite direction)
  void queueDirection(Point<int> newDir) {
    if (_gameOver) return;

    // Get the last direction in queue or current direction
    final Point<int> lastDir =
        _directionQueue.isEmpty ? _direction : _directionQueue.last;

    // Prevent opposite direction (x + newX == 0 AND y + newY == 0)
    if (lastDir.x + newDir.x == 0 && lastDir.y + newDir.y == 0) {
      return;
    }

    // Prevent duplicate consecutive directions
    if (lastDir == newDir) return;

    // Limit queue size to 2 (prevents spamming)
    if (_directionQueue.length < 2) {
      _directionQueue.add(newDir);
    }
  }

  /// Main game tick - updates game state
  bool tick() {
    if (_gameOver) return false;

    // Consume queued direction
    if (_directionQueue.isNotEmpty) {
      _direction = _directionQueue.removeFirst();
    }

    // Calculate new head position
    final Point<int> head = _snake.first;
    final Point<int> newHead = Point(
      (head.x + _direction.x) % _gridSize,
      (head.y + _direction.y) % _gridSize,
    );

    // Check collision with self (O(1) with Set)
    if (_snakeSet.contains(newHead)) {
      _gameOver = true;
      return false;
    }

    // Add new head
    _snake.insert(0, newHead);
    _snakeSet.add(newHead);

    // Check if food eaten
    final bool ateFood = newHead == _food;
    if (ateFood) {
      _score += 10;
      _generateFood();
    } else {
      // Remove tail (snake doesn't grow)
      final Point<int> tail = _snake.removeLast();
      _snakeSet.remove(tail);
    }

    return ateFood;
  }

  /// Generate new food position
  void _generateFood() {
    Point<int> newFood;
    int attempts = 0;
    const int maxAttempts = 100;

    do {
      newFood = Point(_random.nextInt(_gridSize), _random.nextInt(_gridSize));
      attempts++;

      // Fallback if board is nearly full
      if (attempts > maxAttempts) {
        // Find first empty spot
        for (int y = 0; y < _gridSize; y++) {
          for (int x = 0; x < _gridSize; x++) {
            final Point<int> candidate = Point(x, y);
            if (!_snakeSet.contains(candidate)) {
              _food = candidate;
              return;
            }
          }
        }
        // Board is completely full (shouldn't happen)
        _gameOver = true;
        return;
      }
    } while (_snakeSet.contains(newFood));

    _food = newFood;
  }

  /// Get current speed based on score (dynamic difficulty)
  int getSpeed() {
    const int baseSpeed = 200;
    const int minSpeed = 50;
    const int speedDecrement = 10;
    const int scoreInterval = 50;

    final int speedReduction = (_score ~/ scoreInterval) * speedDecrement;
    return (baseSpeed - speedReduction).clamp(minSpeed, baseSpeed);
  }

  /// Check if game is over
  bool get isGameOver => _gameOver;

  /// Get current score
  int get score => _score;

  /// Get grid size
  int get gridSize => _gridSize;

  // Test helper
  void setSnakeForTesting(List<Point<int>> newSnake) {
    _snake = List.from(newSnake);
    _snakeSet = _snake.toSet();
  }
}
