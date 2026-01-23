import 'package:flutter/material.dart';

/// Theme system for Snake game with predefined color schemes
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
