// File: lib/features/snake/snake_widget.dart

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SnakeWidget extends StatelessWidget {
  const SnakeWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.videogame_asset, size: 24),
        label: const Text('Play Snake'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          foregroundColor: theme.colorScheme.onPrimary,
          backgroundColor: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: theme.colorScheme.primary.withOpacity(0.5),
        ),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SnakeGame()),
        ),
      ),
    );
  }
}

class SnakeGame extends StatefulWidget {
  const SnakeGame({Key? key}) : super(key: key);
  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> {
  // ─── Configuration ───────────────────────────────────────────────
  static const int rows = 20, cols = 20;
  static const List<int> speeds = [300, 250, 200, 150, 100];
  static const _highScoreKey = 'snake_high_score';

  // ─── Game State ──────────────────────────────────────────────────
  late List<Point<int>> _snake;
  late Point<int> _food;
  Point<int> _direction = const Point(1, 0);

  late Timer _timer;
  bool _running = true, _gameOver = false;

  int _level = 2; // default speed
  int _score = 0, _highScore = 0;
  bool _justBeatHigh = false;

  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _loadHighScore().then((_) => _startNewGame());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _highScore = prefs.getInt(_highScoreKey) ?? 0);
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_highScoreKey, _highScore);
  }

  void _startNewGame() {
    _snake = [
      Point(cols ~/ 2, rows ~/ 2),
      Point(cols ~/ 2 - 1, rows ~/ 2),
    ];
    _spawnFood();
    _direction = const Point(1, 0);
    _running = true;
    _gameOver = false;
    _score = 0;
    _justBeatHigh = false;

    _timer = Timer.periodic(
      Duration(milliseconds: speeds[_level]),
      (_) => _tick(),
    );
    setState(() {});
  }

  void _spawnFood() {
    Point<int> pos;
    do {
      pos = Point(_rng.nextInt(cols), _rng.nextInt(rows));
    } while (_snake.contains(pos));
    _food = pos;
  }

  void _tick() {
    if (!_running || _gameOver) return;

    final head = _snake.first;
    final newHead = Point(
      (head.x + _direction.x + cols) % cols,
      (head.y + _direction.y + rows) % rows,
    );
    if (_snake.skip(1).contains(newHead)) {
      _endGame();
      return;
    }

    setState(() {
      _snake.insert(0, newHead);
      if (newHead == _food) {
        _score += 10;
        _spawnFood();
      } else {
        _snake.removeLast();
      }
    });
  }

  void _endGame() {
    _running = false;
    _gameOver = true;
    _timer.cancel();
    if (_score > _highScore) {
      _highScore = _score;
      _justBeatHigh = true;
      _saveHighScore();
    }
    setState(() {});
  }

  void _togglePause() => setState(() => _running = !_running);

  void _changeDir(Point<int> d) {
    if (d.x + _direction.x == 0 && d.y + _direction.y == 0) return;
    _direction = d;
  }

  void _changeSpeed(int lvl) {
    _level = lvl.clamp(0, speeds.length - 1);
    if (!_gameOver) {
      _timer.cancel();
      _timer = Timer.periodic(
        Duration(milliseconds: speeds[_level]),
        (_) => _tick(),
      );
    }
    setState(() {});
  }

  Widget _buildLevelPicker() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(speeds.length, (i) {
          return ListTile(
            title: Text(
              ['Slow', 'Mid', 'Fast', 'X-Fast', 'Ultra'][i],
              style: const TextStyle(color: Colors.white),
            ),
            trailing: i == _level
                ? const Icon(Icons.check, color: Colors.tealAccent)
                : null,
            onTap: () {
              _changeSpeed(i);
              Navigator.pop(context);
            },
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.black, // OLED black
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 2,
        title: Row(
          children: [
            const Text('Snake', style: TextStyle(color: Colors.white)),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Score: $_score',
                    style: text.bodyLarge?.copyWith(color: Colors.tealAccent)),
                Text('High: $_highScore',
                    style: text.bodySmall?.copyWith(color: Colors.tealAccent)),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (ctx, constraints) {
          // Board is at most half screen height, with 16px padding
          final maxSize = constraints.maxHeight * 0.5;
          final boardSize = min(constraints.maxWidth - 32, maxSize);

          return Stack(children: [
            // Slider + Board column
            Column(children: [
              // Speed slider
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                child: Row(children: [
                  const Icon(Icons.speed, color: Colors.tealAccent),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.tealAccent,
                        thumbColor: Colors.tealAccent,
                        inactiveTrackColor: Colors.grey.shade800,
                      ),
                      child: Slider(
                        min: 0,
                        max: (speeds.length - 1).toDouble(),
                        divisions: speeds.length - 1,
                        value: _level.toDouble(),
                        label: ['Slow', 'Mid', 'Fast', 'X-Fast', 'Ultra']
                            [_level],
                        onChanged: (v) => _changeSpeed(v.toInt()),
                      ),
                    ),
                  ),
                ]),
              ),

              // Centered board
              Center(
                child: Container(
                  width: boardSize,
                  height: boardSize,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.tealAccent, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: GestureDetector(
                    onVerticalDragUpdate: (d) => _changeDir(
                        Point(0, d.delta.dy.sign.toInt())),
                    onHorizontalDragUpdate: (d) => _changeDir(
                        Point(d.delta.dx.sign.toInt(), 0)),
                    child: CustomPaint(
                      painter: _SnakePainter(_snake, _food),
                      size: Size(boardSize, boardSize),
                    ),
                  ),
                ),
              ),

              // Spacer under board
              const SizedBox(height: 120),
            ]),

            // Centered D-pad
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 6)],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Up
                    GestureDetector(
                      onTap: () => _changeDir(const Point(0, -1)),
                      child: Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        child: const Icon(Icons.arrow_drop_up,
                            size: 40, color: Colors.tealAccent),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Left + + + Right
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      GestureDetector(
                        onTap: () => _changeDir(const Point(-1, 0)),
                        child: Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          child: const Icon(Icons.arrow_left,
                              size: 36, color: Colors.tealAccent),
                        ),
                      ),
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: const Text(
                          '+',
                          style: TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 28,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _changeDir(const Point(1, 0)),
                        child: Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          child: const Icon(Icons.arrow_right,
                              size: 36, color: Colors.tealAccent),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    // Down
                    GestureDetector(
                      onTap: () => _changeDir(const Point(0, 1)),
                      child: Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        child: const Icon(Icons.arrow_drop_down,
                            size: 40, color: Colors.tealAccent),
                      ),
                    ),
                  ]),
                ),
              ),
            ),

            // Bottom nav bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavButton(
                    icon: Icons.home,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  _NavButton(
                    icon: _running ? Icons.pause : Icons.play_arrow,
                    onPressed: _togglePause,
                  ),
                  _NavButton(
                    icon: Icons.stop,
                    onPressed: _startNewGame,
                  ),
                  _NavButton(
                    icon: Icons.grid_view,
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.black87,
                      builder: (_) => _buildLevelPicker(),
                    ),
                  ),
                ],
              ),
            ),

            // Game Over overlay
            if (_gameOver)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        _justBeatHigh ? 'New High Score! 🎉' : 'Game Over',
                        style: text.headlineMedium
                            ?.copyWith(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text('Score: $_score',
                          style: text.titleLarge?.copyWith(color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('High: $_highScore',
                          style: text.titleMedium?.copyWith(color: Colors.white70)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent),
                        onPressed: _startNewGame,
                        child: const Text('Play Again', style: TextStyle(color: Colors.black)),
                      ),
                    ]),
                  ),
                ),
              ),
          ]);
        }),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _NavButton({required this.icon, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white12,
      shape: const CircleBorder(),
      elevation: 4,
      child: IconButton(
        iconSize: 28,
        icon: Icon(icon, color: Colors.tealAccent),
        onPressed: onPressed,
      ),
    );
  }
}

class _SnakePainter extends CustomPainter {
  final List<Point<int>> snake;
  final Point<int> food;
  const _SnakePainter(this.snake, this.food);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _SnakeGameState.cols;

    // Black background
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

    // Food glow + core
    final fc = Offset((food.x + .5) * cell, (food.y + .5) * cell);
    final glow = Paint()
      ..color = Colors.redAccent.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(fc, cell * .5, glow);
    canvas.drawCircle(fc, cell * .3, Paint()..color = Colors.redAccent);

    // Snake gradient
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.greenAccent, Colors.tealAccent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    for (var p in snake) {
      final r = Rect.fromLTWH(p.x * cell, p.y * cell, cell, cell).deflate(1);
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(cell * .2)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnakePainter old) => true;
}
