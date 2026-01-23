import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Audio management system for Snake game
class GameAudio {
  final AudioPlayer _player = AudioPlayer();
  bool _muted = false;
  bool _vibrationEnabled = true;

  static const String _mutedKey = 'snake_audio_muted';
  static const String _vibrationKey = 'snake_vibration';

  /// Initialize and load settings
  Future<void> init() async {
    await loadSettings();
  }

  /// Load audio settings from preferences
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _muted = prefs.getBool(_mutedKey) ?? false;
      _vibrationEnabled = prefs.getBool(_vibrationKey) ?? true;
    } catch (e) {
      // Use defaults
      _muted = false;
      _vibrationEnabled = true;
    }
  }

  /// Save audio settings
  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mutedKey, _muted);
      await prefs.setBool(_vibrationKey, _vibrationEnabled);
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Play eat food sound
  Future<void> playEat() async {
    if (_muted) return;
    try {
      await _player.play(AssetSource('sounds/eat.mp3'), volume: 0.5);
    } catch (e) {
      // Silently fail if sound not found
    }
  }

  /// Play game over sound
  Future<void> playGameOver() async {
    if (_muted) return;
    try {
      await _player.play(AssetSource('sounds/game_over.mp3'), volume: 0.7);
    } catch (e) {
      // Silently fail if sound not found
    }
  }

  /// Vibrate device
  void vibrate() {
    if (!_vibrationEnabled) return;
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      // Ignore vibration errors
    }
  }

  /// Toggle mute
  void toggleMute() {
    _muted = !_muted;
    saveSettings();
  }

  /// Toggle vibration
  void toggleVibration() {
    _vibrationEnabled = !_vibrationEnabled;
    saveSettings();
  }

  /// Setters
  void setMuted(bool muted) {
    _muted = muted;
    saveSettings();
  }

  void setVibration(bool enabled) {
    _vibrationEnabled = enabled;
    saveSettings();
  }

  /// Getters
  bool get isMuted => _muted;
  bool get isVibrationEnabled => _vibrationEnabled;

  /// Clean up
  void dispose() {
    _player.dispose();
  }
}
