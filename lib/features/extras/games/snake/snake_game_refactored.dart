import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';

import 'engine/snake_controller.dart';
import 'ui/snake_board.dart';
import 'ui/stats_screen.dart';
import 'audio/game_audio.dart';
import 'achievements/achievements_manager.dart';
import 'stats/game_stats.dart';
import 'replay/replay_system.dart';

/// Refactored Snake Game using new architecture
/// Features:
/// - Separated game engine
/// - Ticker-based game loop
/// - O(1) collision detection
/// - Optimized rendering
/// - Audio management
class SnakeGameRefactored extends StatefulWidget {
  const SnakeGameRefactored({super.key});

  @override
  State<SnakeGameRefactored> createState() => _SnakeGameRefactoredState();
}

class _SnakeGameRefactoredState extends State<SnakeGameRefactored>
    with SingleTickerProviderStateMixin {
  late SnakeController _controller;
  late GameAudio _audio;
  late ConfettiController _confetti;
  late AchievementsManager _achievements;
  late GameStats _stats;
  late ReplayRecorder _replayRecorder;

  int _highScore = 0;
  final String _selectedTheme = 'classic';
  int _foodEatenThisGame = 0;
  int _maxSnakeLengthThisGame = 3;
  List<Achievement> _newAchievements = [];

  // Game states
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _showMenu = true;

  @override
  void initState() {
    super.initState();

    // Initialize controller with callbacks
    _controller = SnakeController(
      vsync: this,
      onFoodEaten: _onFoodEaten,
      onGameOver: _onGameOver,
      onTick: () {
        // Record replay frame on every tick
        if (_replayRecorder.isRecording) {
          _replayRecorder.recordFrame(
            snake: _controller.gameState.value.snake,
            food: _controller.gameState.value.food,
            direction: _controller.gameState.value.direction,
            score: _controller.score,
          );
        }
      },
    );

    // Initialize audio
    _audio = GameAudio();
    _audio.init();

    // Initialize confetti
    _confetti = ConfettiController(duration: const Duration(seconds: 2));

    // Initialize achievements and stats
    _achievements = AchievementsManager();
    _stats = GameStats();
    _replayRecorder = ReplayRecorder();

    // Load high score and stats
    _loadHighScore();
    _stats.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _audio.dispose();
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('snake_high_score') ?? 0;
    });
  }

  Future<void> _saveHighScore(int score) async {
    if (score > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('snake_high_score', score);
      setState(() {
        _highScore = score;
      });
    }
  }

  void _onFoodEaten() {
    _audio.playEat();
    _audio.vibrate();
    _foodEatenThisGame++;

    // Update max snake length
    final currentLength = _controller.gameState.value.snake.length;
    if (currentLength > _maxSnakeLengthThisGame) {
      _maxSnakeLengthThisGame = currentLength;
    }
  }

  void _onGameOver() async {
    _audio.playGameOver();
    _audio.vibrate();
    _saveHighScore(_controller.score);

    // Stop replay recording
    _replayRecorder.stopRecording();

    // Record game stats
    await _stats.recordGame(
      score: _controller.score,
      foodEaten: _foodEatenThisGame,
      maxSnakeLength: _maxSnakeLengthThisGame,
      finalSpeed:
          _controller.gameState.value.score >= 50
              ? _controller.score ~/ 50 * 10
              : 0,
    );

    // Check for new achievements
    final newlyUnlocked = await _achievements.checkAchievements(
      score: _controller.score,
      totalGames: _stats.totalGames,
      snakeLength: _maxSnakeLengthThisGame,
      speed: 200 - (_controller.score ~/ 50 * 10).clamp(0, 150),
    );

    _newAchievements = newlyUnlocked;

    // Show confetti if new high score or achievement unlocked
    if (_controller.score >= _highScore || newlyUnlocked.isNotEmpty) {
      _confetti.play();
    }

    setState(() {
      _isPlaying = false;
    });
  }

  void _startGame() {
    _controller.reset();
    _controller.start();

    // Reset game-specific tracking
    _foodEatenThisGame = 0;
    _maxSnakeLengthThisGame = 3;
    _newAchievements.clear();

    // Start replay recording
    _replayRecorder.startRecording();

    setState(() {
      _isPlaying = true;
      _isPaused = false;
      _showMenu = false;
    });
  }

  void _pauseGame() {
    _controller.pause();
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeGame() {
    _controller.resume();
    setState(() {
      _isPaused = false;
    });
  }

  void _quitGame() {
    _controller.stop();
    setState(() {
      _isPlaying = false;
      _showMenu = true;
    });
  }

  // Theme colors
  Map<String, Color> get _colors {
    switch (_selectedTheme) {
      case 'neon':
        return {
          'bg': const Color(0xFF0a0e27),
          'snake': const Color(0xFF00ff88),
          'food': const Color(0xFFff006e),
          'grid': const Color(0xFF1a1f3a),
        };
      case 'retro':
        return {
          'bg': const Color(0xFF2d2d2d),
          'snake': const Color(0xFF00ff00),
          'food': const Color(0xFFff0000),
          'grid': const Color(0xFF404040),
        };
      default: // classic
        return {
          'bg': const Color(0xFFf5f5f0),
          'snake': const Color(0xFF4a90e2),
          'food': const Color(0xFFe74c3c),
          'grid': const Color(0xFFdcdcdc),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;

    return Scaffold(
      backgroundColor: colors['bg'],
      appBar: AppBar(
        title: const Text('Snake Game'),
        backgroundColor: colors['bg'],
        foregroundColor: colors['snake'],
        elevation: 0,
        actions: [
          // Stats screen
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'View Stats',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatsScreen()),
              );
            },
          ),
          // Mute toggle
          IconButton(
            icon: Icon(_audio.isMuted ? Icons.volume_off : Icons.volume_up),
            onPressed: () {
              setState(() {
                _audio.toggleMute();
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main game area
          Column(
            children: [
              // Score header
              _buildHeader(colors),

              const SizedBox(height: 20),

              // Game board
              Padding(
                padding: const EdgeInsets.all(16),
                child: SnakeBoard(
                  gameState: _controller.gameState,
                  snakeColor: colors['snake']!,
                  foodColor: colors['food']!,
                  gridColor: colors['grid']!,
                  backgroundColor: colors['bg']!,
                ),
              ),

              const SizedBox(height: 20),

              // Controls
              if (_isPlaying && !_isPaused) _buildControls(colors),
            ],
          ),

          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),

          // Main menu overlay
          if (_showMenu) _buildMainMenu(colors),

          // Pause menu overlay
          if (_isPaused) _buildPauseMenu(colors),

          // Game over overlay
          if (!_isPlaying && !_showMenu && !_isPaused)
            _buildGameOverOverlay(colors),
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, Color> colors) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard('Score', _controller.score, colors),
              _buildStatCard('High', _highScore, colors),
              _buildStatCard(
                'Speed',
                _controller.gameState.value.score ~/ 50 + 1,
                colors,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, int value, Map<String, Color> colors) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colors['grid'],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colors['snake'],
          ),
        ),
      ],
    );
  }

  Widget _buildControls(Map<String, Color> colors) {
    return Column(
      children: [
        // Pause button
        IconButton(
          icon: const Icon(Icons.pause),
          iconSize: 32,
          color: colors['snake'],
          onPressed: _pauseGame,
        ),

        const SizedBox(height: 20),

        // D-pad controls
        Column(
          children: [
            _buildControlButton(Icons.arrow_drop_up, () {
              _controller.changeDirection(const Point(0, -1));
            }, colors),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlButton(Icons.arrow_left, () {
                  _controller.changeDirection(const Point(-1, 0));
                }, colors),
                const SizedBox(width: 80),
                _buildControlButton(Icons.arrow_right, () {
                  _controller.changeDirection(const Point(1, 0));
                }, colors),
              ],
            ),
            _buildControlButton(Icons.arrow_drop_down, () {
              _controller.changeDirection(const Point(0, 1));
            }, colors),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButton(
    IconData icon,
    VoidCallback onTap,
    Map<String, Color> colors,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors['snake']!.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors['snake']!, width: 2),
        ),
        child: Icon(icon, size: 32, color: colors['snake']),
      ),
    );
  }

  Widget _buildMainMenu(Map<String, Color> colors) {
    return Container(
      color: colors['bg']!.withOpacity(0.95),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SNAKE',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: colors['snake'],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors['snake'],
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
              ),
              child: const Text('START GAME', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            Text(
              'High Score: $_highScore',
              style: TextStyle(fontSize: 16, color: colors['grid']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPauseMenu(Map<String, Color> colors) {
    return Container(
      color: colors['bg']!.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'PAUSED',
              style: TextStyle(fontSize: 32, color: colors['snake']),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _resumeGame,
              style: ElevatedButton.styleFrom(backgroundColor: colors['snake']),
              child: const Text('RESUME'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _quitGame,
              child: Text('QUIT', style: TextStyle(color: colors['food'])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay(Map<String, Color> colors) {
    final isNewHighScore = _controller.score >= _highScore;

    return Container(
      color: colors['bg']!.withOpacity(0.95),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isNewHighScore) ...[
                Text(
                  '🎉 NEW HIGH SCORE! 🎉',
                  style: TextStyle(
                    fontSize: 24,
                    color: colors['food'],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Show new achievements
              if (_newAchievements.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '🏆 ACHIEVEMENT UNLOCKED!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._newAchievements
                          .take(3)
                          .map(
                            (ach) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                '${ach.icon} ${ach.title}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colors['snake'],
                                ),
                              ),
                            ),
                          ),
                      if (_newAchievements.length > 3)
                        Text(
                          '+${_newAchievements.length - 3} more!',
                          style: TextStyle(fontSize: 14, color: colors['grid']),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              Text(
                'GAME OVER',
                style: TextStyle(fontSize: 32, color: colors['snake']),
              ),
              const SizedBox(height: 20),
              Text(
                'Score: ${_controller.score}',
                style: TextStyle(fontSize: 24, color: colors['grid']),
              ),
              const SizedBox(height: 12),
              Text(
                'Food Eaten: $_foodEatenThisGame',
                style: TextStyle(fontSize: 16, color: colors['grid']),
              ),
              Text(
                'Max Length: $_maxSnakeLengthThisGame',
                style: TextStyle(fontSize: 16, color: colors['grid']),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors['snake'],
                ),
                child: const Text('PLAY AGAIN'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StatsScreen()),
                      );
                    },
                    child: Text(
                      'VIEW STATS',
                      style: TextStyle(color: colors['snake']),
                    ),
                  ),
                  const SizedBox(width: 20),
                  TextButton(
                    onPressed: _quitGame,
                    child: Text(
                      'MAIN MENU',
                      style: TextStyle(color: colors['grid']),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
