import 'package:shared_preferences/shared_preferences.dart';

/// Game statistics tracker
class GameStats {
  int totalGames = 0;
  int totalScore = 0;
  int highScore = 0;
  int totalFoodEaten = 0;
  int longestSnake = 0;
  int fastestSpeed = 200;

  DateTime? firstGameDate;
  DateTime? lastGameDate;

  /// Load stats from storage
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    totalGames = prefs.getInt('snake_total_games') ?? 0;
    totalScore = prefs.getInt('snake_total_score') ?? 0;
    highScore = prefs.getInt('snake_high_score') ?? 0;
    totalFoodEaten = prefs.getInt('snake_total_food') ?? 0;
    longestSnake = prefs.getInt('snake_longest_snake') ?? 0;
    fastestSpeed = prefs.getInt('snake_fastest_speed') ?? 200;

    final firstDate = prefs.getString('snake_first_game_date');
    if (firstDate != null) {
      firstGameDate = DateTime.tryParse(firstDate);
    }

    final lastDate = prefs.getString('snake_last_game_date');
    if (lastDate != null) {
      lastGameDate = DateTime.tryParse(lastDate);
    }
  }

  /// Save stats to storage
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('snake_total_games', totalGames);
    await prefs.setInt('snake_total_score', totalScore);
    await prefs.setInt('snake_high_score', highScore);
    await prefs.setInt('snake_total_food', totalFoodEaten);
    await prefs.setInt('snake_longest_snake', longestSnake);
    await prefs.setInt('snake_fastest_speed', fastestSpeed);

    if (firstGameDate != null) {
      await prefs.setString(
        'snake_first_game_date',
        firstGameDate!.toIso8601String(),
      );
    }

    if (lastGameDate != null) {
      await prefs.setString(
        'snake_last_game_date',
        lastGameDate!.toIso8601String(),
      );
    }
  }

  /// Record a completed game
  Future<void> recordGame({
    required int score,
    required int foodEaten,
    required int maxSnakeLength,
    required int finalSpeed,
  }) async {
    totalGames++;
    totalScore += score;
    totalFoodEaten += foodEaten;

    if (score > highScore) {
      highScore = score;
    }

    if (maxSnakeLength > longestSnake) {
      longestSnake = maxSnakeLength;
    }

    if (finalSpeed < fastestSpeed) {
      fastestSpeed = finalSpeed;
    }

    lastGameDate = DateTime.now();

    firstGameDate ??= DateTime.now();

    await save();
  }

  /// Get average score
  double get averageScore {
    if (totalGames == 0) return 0;
    return totalScore / totalGames;
  }

  /// Get average food per game
  double get averageFoodPerGame {
    if (totalGames == 0) return 0;
    return totalFoodEaten / totalGames;
  }

  /// Get days since first game
  int? get daysSinceFirstGame {
    if (firstGameDate == null) return null;
    return DateTime.now().difference(firstGameDate!).inDays;
  }

  /// Reset all stats
  Future<void> reset() async {
    totalGames = 0;
    totalScore = 0;
    highScore = 0;
    totalFoodEaten = 0;
    longestSnake = 0;
    fastestSpeed = 200;
    firstGameDate = null;
    lastGameDate = null;

    await save();
  }
}
