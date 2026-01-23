import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';

// ============================================================================
// THEME SYSTEM
// ============================================================================

class SnakeTheme {
  const SnakeTheme({
    required this.name,
    required this.backgroundColors,
    required this.surfaceColor,
    required this.accentColor,
    required this.snakeColor,
    required this.foodColor,
    required this.gridColor,
    this.textColor = Colors.white,
  });

  final String name;
  final List<Color> backgroundColors;
  final Color surfaceColor;
  final Color accentColor;
  final Color snakeColor;
  final Color foodColor;
  final Color gridColor;
  final Color textColor;

  static const SnakeTheme modernDark = SnakeTheme(
    name: 'Modern Dark',
    backgroundColors: [Color(0xFF121212), Color(0xFF1E1E1E)],
    surfaceColor: Color(0xFF2C2C2C),
    accentColor: Color(0xFFBB86FC),
    snakeColor: Color(0xFF03DAC6),
    foodColor: Color(0xFFCF6679),
    gridColor: Colors.white10,
  );

  static const SnakeTheme arcade = SnakeTheme(
    name: 'Arcade',
    backgroundColors: [Color(0xFF222034), Color(0xFF222034)],
    surfaceColor: Color(0xFF45283c),
    accentColor: Color(0xFFdf7126),
    snakeColor: Color(0xFF99e550),
    foodColor: Color(0xFFac3232),
    gridColor: Colors.white12,
  );

  static const SnakeTheme classic = SnakeTheme(
    name: 'Classic',
    backgroundColors: [Color(0xFF9bbc0f), Color(0xFF8bac0f)],
    surfaceColor: Color(0xFF306230),
    accentColor: Color(0xFF0f380f),
    snakeColor: Color(0xFF0f380f),
    foodColor: Color(0xFF0f380f),
    gridColor: Color(0xFF0f380f),
    textColor: Color(0xFF0f380f),
  );

  static SnakeTheme getTheme(String name) {
    switch (name) {
      case 'Arcade':
        return arcade;
      case 'Classic':
        return classic;
      default:
        return modernDark;
    }
  }
}

// ============================================================================
// UI COMPONENTS (Flat, Clean, Mobile-Style)
// ============================================================================

class GamePanel extends StatelessWidget {
  const GamePanel({
    required this.child,
    super.key,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.border,
    this.theme,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final BoxBorder? border;
  final SnakeTheme? theme;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? theme?.surfaceColor ?? Colors.grey[900]!;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: border ?? Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class GameButton extends StatefulWidget {
  const GameButton({
    required this.label,
    required this.theme,
    super.key,
    this.onTap,
    this.icon,
    this.primary = false,
  });

  final String label;
  final SnakeTheme theme;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool primary;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor =
        widget.primary ? widget.theme.accentColor : widget.theme.surfaceColor;
    final Color contentColor =
        widget.primary ? Colors.black : widget.theme.textColor;

    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder:
            (_, child) =>
                Transform.scale(scale: _scaleAnim.value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: contentColor, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label.toUpperCase(),
                style: TextStyle(
                  color: contentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MAIN SNAKE GAME
// ============================================================================

class SnakeWidget extends StatelessWidget {
  const SnakeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const SnakeGame();
  }
}

class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});

  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Constants
  static const int rows = 30;
  static const int cols = 20;
  static const List<int> speeds = [200, 150, 100, 70, 50]; // Faster base speeds

  // State
  List<Point<int>> _snake = [];
  Point<int> _food = const Point(0, 0);
  Point<int> _direction = const Point(0, -1);
  Point<int> _nextDirection = const Point(0, -1);

  // Game Status
  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isPaused = false;
  int _score = 0;
  int _highScore = 0;

  // Options
  int _speedLevel = 2;
  String _themeName = 'Modern Dark';
  SnakeTheme _theme = SnakeTheme.modernDark;

  Timer? _timer;
  final Random _rng = Random();
  final AudioPlayer _audio = AudioPlayer();
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _loadHighScore();
    _loadSettings();

    // Set system UI to edge-to-edge for game feel without layout thrashing
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _audio.stop();
    _audio.dispose();
    _confetti.stop();
    _confetti.dispose();
    // Restore system UI to default
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isPlaying) {
      if (!_isPaused) _pauseGame();
    }
  }

  // --- Logic ---

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _highScore = prefs.getInt('snake_hs') ?? 0);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeName = prefs.getString('snake_theme') ?? 'Modern Dark';
      _theme = SnakeTheme.getTheme(_themeName);
    });
  }

  void _startGame() {
    setState(() {
      // Start in middle
      const midX = cols ~/ 2;
      const midY = rows ~/ 2;
      _snake = [
        const Point(midX, midY),
        const Point(midX, midY + 1),
        const Point(midX, midY + 2),
      ];
      _direction = const Point(0, -1);
      _nextDirection = const Point(0, -1);
      _score = 0;
      _isPlaying = true;
      _isGameOver = false;
      _isPaused = false;
      _spawnFood();
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: speeds[_speedLevel]),
      (_) => _tick(),
    );
  }

  void _pauseGame() {
    _timer?.cancel();
    setState(() => _isPaused = true);
  }

  void _resumeGame() {
    setState(() => _isPaused = false);
    _startTimer();
  }

  void _quitGame() {
    _timer?.cancel();
    Navigator.pop(context);
  }

  void _tick() {
    setState(() {
      _direction = _nextDirection;
      final head = _snake.first;

      // Calculate new head
      int newX = head.x + _direction.x;
      int newY = head.y + _direction.y;

      // Wall wrap logic (standard for mobile snake usually)
      if (newX < 0) newX = cols - 1;
      if (newX >= cols) newX = 0;
      if (newY < 0) newY = rows - 1;
      if (newY >= rows) newY = 0;

      final newHead = Point(newX, newY);

      // Self collision
      if (_snake.contains(newHead)) {
        _gameOver();
        return;
      }

      // Move
      _snake.insert(0, newHead);

      // Eat
      if (newHead == _food) {
        _score += 10;
        HapticFeedback.mediumImpact();
        // Play sound if available: _audio.play(AssetSource('sounds/eat.wav'));
        _spawnFood();
      } else {
        _snake.removeLast();
      }
    });
  }

  void _spawnFood() {
    Point<int> p;
    do {
      p = Point(_rng.nextInt(cols), _rng.nextInt(rows));
    } while (_snake.contains(p));
    _food = p;
  }

  void _gameOver() async {
    _timer?.cancel();
    HapticFeedback.heavyImpact();

    if (_score > _highScore) {
      _highScore = _score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('snake_hs', _highScore);
      _confetti.play();
    }

    setState(() => _isGameOver = true);
  }

  void _changeDir(Point<int> newDir) {
    // Prevent 180 turn
    if (newDir.x == -_direction.x && newDir.y == -_direction.y) return;
    // Prevent multiple moves in one tick
    if (_direction != _nextDirection) {
      return; // Basic input debounce approximation
    }
    _nextDirection = newDir;
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.backgroundColors.first,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _theme.backgroundColors,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: cols / rows,
                        child: _buildGameBoard(),
                      ),
                    ),
                  ),
                  _buildControls(),
                ],
              ),
              if (_isGameOver) _buildGameOverOverlay(),
              if (!_isPlaying && !_isGameOver) _buildMainMenu(),
              if (_isPaused && !_isGameOver) _buildPauseMenu(),

              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirection: pi / 2,
                  numberOfParticles: 20,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: _theme.textColor),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Text(
                'SCORE: $_score',
                style: TextStyle(
                  color: _theme.textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
              Text(
                '$_highScore',
                style: TextStyle(
                  color: _theme.textColor.withOpacity(0.7),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              if (_isPlaying)
                IconButton(
                  icon: Icon(
                    _isPaused ? Icons.play_arrow : Icons.pause,
                    color: _theme.textColor,
                  ),
                  onPressed: _isPaused ? _resumeGame : _pauseGame,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameBoard() {
    return GamePanel(
      theme: _theme,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final cellSize = constraints.maxWidth / cols;
          return GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.delta.dy > 5) {
                _changeDir(const Point(0, 1));
              } else if (details.delta.dy < -5)
                _changeDir(const Point(0, -1));
            },
            onHorizontalDragUpdate: (details) {
              if (details.delta.dx > 5) {
                _changeDir(const Point(1, 0));
              } else if (details.delta.dx < -5)
                _changeDir(const Point(-1, 0));
            },
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: BoardPainter(
                snake: _snake,
                food: _food,
                cellSize: cellSize,
                theme: _theme,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControls() {
    final color = _theme.textColor.withOpacity(0.1);
    final iconColor = _theme.textColor;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDpadBtn(
            Icons.keyboard_arrow_up,
            () => _changeDir(const Point(0, -1)),
            color,
            iconColor,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDpadBtn(
                Icons.keyboard_arrow_left,
                () => _changeDir(const Point(-1, 0)),
                color,
                iconColor,
              ),
              const SizedBox(width: 60),
              _buildDpadBtn(
                Icons.keyboard_arrow_right,
                () => _changeDir(const Point(1, 0)),
                color,
                iconColor,
              ),
            ],
          ),
          _buildDpadBtn(
            Icons.keyboard_arrow_down,
            () => _changeDir(const Point(0, 1)),
            color,
            iconColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDpadBtn(IconData icon, VoidCallback onTap, Color bg, Color fg) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        customBorder: const CircleBorder(),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          child: Icon(icon, color: fg, size: 32),
        ),
      ),
    );
  }

  // --- Overlays ---

  Widget _buildMainMenu() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SNAKE',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                color: _theme.accentColor,
                letterSpacing: 4,
                shadows: [
                  Shadow(
                    color: _theme.accentColor.withOpacity(0.5),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            GameButton(
              label: 'NEW GAME',
              theme: _theme,
              primary: true,
              onTap: _startGame,
              icon: Icons.play_arrow_rounded,
            ),
            const SizedBox(height: 16),
            GameButton(
              label: 'THEME: ${_themeName.toUpperCase()}',
              theme: _theme,
              onTap: _cycleTheme,
              icon: Icons.palette_outlined,
            ),
            const SizedBox(height: 16),
            GameButton(
              label: 'SPEED: ${_speedLabel()}',
              theme: _theme,
              onTap: _cycleSpeed,
              icon: Icons.speed_rounded,
            ),
            const SizedBox(height: 16),
            GameButton(
              label: 'EXIT',
              theme: _theme,
              onTap: () => Navigator.of(context).pop(),
              icon: Icons.exit_to_app_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: GamePanel(
          theme: _theme,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'GAME OVER',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Score: $_score',
                style: TextStyle(color: _theme.textColor, fontSize: 24),
              ),
              const SizedBox(height: 32),
              GameButton(
                label: 'TRY AGAIN',
                theme: _theme,
                primary: true,
                onTap: _startGame,
                icon: Icons.replay,
              ),
              const SizedBox(height: 16),
              GameButton(
                label: 'EXIT',
                theme: _theme,
                onTap: _quitGame,
                icon: Icons.exit_to_app,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPauseMenu() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: GamePanel(
          theme: _theme,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PAUSED',
                style: TextStyle(
                  color: _theme.textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 32),
              GameButton(
                label: 'RESUME',
                theme: _theme,
                primary: true,
                onTap: _resumeGame,
                icon: Icons.play_arrow,
              ),
              const SizedBox(height: 16),
              GameButton(
                label: 'QUIT',
                theme: _theme,
                onTap: _quitGame,
                icon: Icons.close,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helpers ---

  void _cycleTheme() {
    setState(() {
      if (_themeName == 'Modern Dark') {
        _themeName = 'Arcade';
      } else if (_themeName == 'Arcade') {
        _themeName = 'Classic';
      } else {
        _themeName = 'Modern Dark';
      }
      _theme = SnakeTheme.getTheme(_themeName);
    });
    SharedPreferences.getInstance().then(
      (p) => p.setString('snake_theme', _themeName),
    );
  }

  void _cycleSpeed() {
    setState(() {
      _speedLevel = (_speedLevel + 1) % speeds.length;
    });
  }

  String _speedLabel() {
    switch (_speedLevel) {
      case 0:
        return 'SLOW';
      case 1:
        return 'NORMAL';
      case 2:
        return 'FAST';
      case 3:
        return 'TURBO';
      case 4:
        return 'INSANE';
      default:
        return 'NORMAL';
    }
  }
}

// ============================================================================
// PAINTER
// ============================================================================

class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.snake,
    required this.food,
    required this.cellSize,
    required this.theme,
  });

  final List<Point<int>> snake;
  final Point<int> food;
  final double cellSize;
  final SnakeTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw Grid (Optional, keep it subtle)
    final gridPaint =
        Paint()
          ..color = theme.gridColor
          ..strokeWidth = 1.0;

    for (double i = 0; i <= size.width; i += cellSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i <= size.height; i += cellSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Draw Food
    final foodCenter = Offset(
      (food.x + 0.5) * cellSize,
      (food.y + 0.5) * cellSize,
    );
    final foodRadius = cellSize * 0.4;

    // Food Glow
    canvas.drawCircle(
      foodCenter,
      foodRadius * 1.5,
      Paint()
        ..color = theme.foodColor.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Food Body
    canvas.drawCircle(foodCenter, foodRadius, Paint()..color = theme.foodColor);

    // Draw Snake
    if (snake.isEmpty) return;

    final snakePaint = Paint()..color = theme.snakeColor;
    final headPaint =
        Paint()..color = Color.lerp(theme.snakeColor, Colors.white, 0.4)!;

    for (int i = 0; i < snake.length; i++) {
      final p = snake[i];
      final isHead = i == 0;

      final rect = Rect.fromLTWH(
        p.x * cellSize + 1,
        p.y * cellSize + 1,
        cellSize - 2,
        cellSize - 2,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        isHead ? headPaint : snakePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) {
    // Return true to ensure updates when snake moves
    return true;
  }
}
