import 'dart:math';

/// Replay frame - records snake state at a point in time
class ReplayFrame {
  const ReplayFrame({
    required this.snake,
    required this.food,
    required this.direction,
    required this.score,
    required this.frameNumber,
  });

  factory ReplayFrame.fromJson(Map<String, dynamic> json) {
    return ReplayFrame(
      snake:
          (json['snake'] as List)
              .map((p) => Point<int>(p['x'] as int, p['y'] as int))
              .toList(),
      food: Point<int>(json['food']['x'] as int, json['food']['y'] as int),
      direction: Point<int>(
        json['direction']['x'] as int,
        json['direction']['y'] as int,
      ),
      score: json['score'] as int,
      frameNumber: json['frameNumber'] as int,
    );
  }
  final List<Point<int>> snake;
  final Point<int> food;
  final Point<int> direction;
  final int score;
  final int frameNumber;

  Map<String, dynamic> toJson() => {
    'snake': snake.map((p) => {'x': p.x, 'y': p.y}).toList(),
    'food': {'x': food.x, 'y': food.y},
    'direction': {'x': direction.x, 'y': direction.y},
    'score': score,
    'frameNumber': frameNumber,
  };
}

/// Replay recorder - captures game state for playback
class ReplayRecorder {
  final List<ReplayFrame> _frames = [];
  int _frameCounter = 0;
  bool _isRecording = false;

  /// Start recording
  void startRecording() {
    _frames.clear();
    _frameCounter = 0;
    _isRecording = true;
  }

  /// Stop recording
  void stopRecording() {
    _isRecording = false;
  }

  /// Record a frame
  void recordFrame({
    required List<Point<int>> snake,
    required Point<int> food,
    required Point<int> direction,
    required int score,
  }) {
    if (!_isRecording) return;

    _frames.add(
      ReplayFrame(
        snake: List.from(snake), // Copy to preserve state
        food: food,
        direction: direction,
        score: score,
        frameNumber: _frameCounter++,
      ),
    );
  }

  /// Get all recorded frames
  List<ReplayFrame> get frames => List.unmodifiable(_frames);

  /// Get total frame count
  int get frameCount => _frames.length;

  /// Check if recording
  bool get isRecording => _isRecording;

  /// Clear all frames
  void clear() {
    _frames.clear();
    _frameCounter = 0;
  }
}

/// Replay player - plays back recorded games
class ReplayPlayer {
  ReplayPlayer(this._frames);
  final List<ReplayFrame> _frames;
  int _currentFrame = 0;
  bool _isPlaying = false;

  /// Get current frame
  ReplayFrame? get currentFrame {
    if (_currentFrame >= _frames.length) return null;
    return _frames[_currentFrame];
  }

  /// Move to next frame
  bool nextFrame() {
    if (_currentFrame < _frames.length - 1) {
      _currentFrame++;
      return true;
    }
    _isPlaying = false;
    return false;
  }

  /// Move to previous frame
  bool previousFrame() {
    if (_currentFrame > 0) {
      _currentFrame--;
      return true;
    }
    return false;
  }

  /// Jump to specific frame
  void jumpToFrame(int frame) {
    if (frame >= 0 && frame < _frames.length) {
      _currentFrame = frame;
    }
  }

  /// Reset to beginning
  void reset() {
    _currentFrame = 0;
    _isPlaying = false;
  }

  /// Play/pause
  void togglePlayback() {
    _isPlaying = !_isPlaying;
  }

  /// Getters
  bool get isPlaying => _isPlaying;
  int get currentFrameNumber => _currentFrame;
  int get totalFrames => _frames.length;
  double get progress => _frames.isEmpty ? 0 : _currentFrame / _frames.length;
}
