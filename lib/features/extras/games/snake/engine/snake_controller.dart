import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../engine/snake_engine.dart';

/// Controller that bridges game engine and UI using Ticker
class SnakeController with ChangeNotifier {
  SnakeController({
    required TickerProvider vsync,
    int gridSize = 20,
    this.onFoodEaten,
    this.onGameOver,
    this.onTick,
  }) : _engine = SnakeEngine(gridSize: gridSize),
       gameState = ValueNotifier(
         GameState(
           snake: [],
           food: const Point(0, 0),
           direction: const Point(1, 0),
           score: 0,
           gameOver: false,
           paused: false,
           gridSize: gridSize,
         ),
       ) {
    _ticker = vsync.createTicker(_onTick);
    reset();
  }
  final SnakeEngine _engine;
  late final Ticker _ticker;
  final ValueNotifier<GameState> gameState;

  Duration _lastTick = Duration.zero;
  bool _isRunning = false;

  // Callbacks
  final VoidCallback? onFoodEaten;
  final VoidCallback? onGameOver;
  final VoidCallback? onTick;

  /// Ticker callback - provides frame-accurate timing
  void _onTick(Duration elapsed) {
    if (!_isRunning) return;

    final int speed = _engine.getSpeed();
    if (elapsed - _lastTick > Duration(milliseconds: speed)) {
      final bool ateFood = _engine.tick();

      // Update state
      gameState.value = _engine.state;

      // Tick callback (for replay recording, etc.)
      if (onTick != null) {
        onTick!();
      }

      // Callbacks
      if (ateFood && onFoodEaten != null) {
        onFoodEaten!();
      }

      if (_engine.isGameOver) {
        stop();
        if (onGameOver != null) {
          onGameOver!();
        }
      }

      _lastTick = elapsed;
      notifyListeners();
    }
  }

  /// Start game loop
  void start() {
    if (_engine.isGameOver) return;
    _isRunning = true;
    _lastTick = Duration.zero;
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  /// Stop game loop
  void stop() {
    _isRunning = false;
  }

  /// Pause game
  void pause() {
    _isRunning = false;
    gameState.value = gameState.value.copyWith(paused: true);
    notifyListeners();
  }

  /// Resume game
  void resume() {
    _lastTick = Duration.zero; // Reset timing to avoid jump
    gameState.value = gameState.value.copyWith(paused: false);
    _isRunning = true;
    notifyListeners();
  }

  /// Reset game to initial state
  void reset() {
    stop();
    _engine.reset();
    gameState.value = _engine.state;
    _lastTick = Duration.zero;
    notifyListeners();
  }

  /// Queue direction change
  void changeDirection(Point<int> direction) {
    _engine.queueDirection(direction);
  }

  /// Get current score
  int get score => _engine.score;

  /// Check if game is running
  bool get isRunning => _isRunning;

  /// Check if game is over
  bool get isGameOver => _engine.isGameOver;

  @override
  void dispose() {
    _ticker.dispose();
    gameState.dispose();
    super.dispose();
  }
}
