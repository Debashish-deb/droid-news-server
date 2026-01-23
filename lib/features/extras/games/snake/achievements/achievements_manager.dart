import 'package:shared_preferences/shared_preferences.dart';

/// Achievement model
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.targetValue,
    required this.icon,
  });
  final String id;
  final String title;
  final String description;
  final int targetValue;
  final String icon;
}

/// Achievements manager for Snake game
class AchievementsManager {
  static const String _prefix = 'snake_achievement_';

  // Achievement definitions
  static const achievements = [
    Achievement(
      id: 'first_game',
      title: 'First Steps',
      description: 'Play your first game',
      targetValue: 1,
      icon: '🎮',
    ),
    Achievement(
      id: 'score_50',
      title: 'Getting Started',
      description: 'Reach a score of 50',
      targetValue: 50,
      icon: '🌟',
    ),
    Achievement(
      id: 'score_100',
      title: 'Century',
      description: 'Reach a score of 100',
      targetValue: 100,
      icon: '💯',
    ),
    Achievement(
      id: 'score_200',
      title: 'Expert',
      description: 'Reach a score of 200',
      targetValue: 200,
      icon: '🏆',
    ),
    Achievement(
      id: 'score_500',
      title: 'Master',
      description: 'Reach a score of 500',
      targetValue: 500,
      icon: '👑',
    ),
    Achievement(
      id: 'games_10',
      title: 'Dedicated',
      description: 'Play 10 games',
      targetValue: 10,
      icon: '🎯',
    ),
    Achievement(
      id: 'games_50',
      title: 'Enthusiast',
      description: 'Play 50 games',
      targetValue: 50,
      icon: '🔥',
    ),
    Achievement(
      id: 'games_100',
      title: 'Legendary',
      description: 'Play 100 games',
      targetValue: 100,
      icon: '⭐',
    ),
    Achievement(
      id: 'snake_50',
      title: 'Long Snake',
      description: 'Grow snake to length 50',
      targetValue: 50,
      icon: '🐍',
    ),
    Achievement(
      id: 'speed_demon',
      title: 'Speed Demon',
      description: 'Reach maximum speed',
      targetValue: 1,
      icon: '⚡',
    ),
  ];

  /// Check and unlock achievements based on game stats
  Future<List<Achievement>> checkAchievements({
    required int score,
    required int totalGames,
    required int snakeLength,
    required int speed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Achievement> newlyUnlocked = [];

    for (final achievement in achievements) {
      // Skip if already unlocked
      if (await isUnlocked(achievement.id)) continue;

      bool shouldUnlock = false;

      switch (achievement.id) {
        case 'first_game':
          shouldUnlock = totalGames >= 1;
          break;
        case 'score_50':
          shouldUnlock = score >= 50;
          break;
        case 'score_100':
          shouldUnlock = score >= 100;
          break;
        case 'score_200':
          shouldUnlock = score >= 200;
          break;
        case 'score_500':
          shouldUnlock = score >= 500;
          break;
        case 'games_10':
          shouldUnlock = totalGames >= 10;
          break;
        case 'games_50':
          shouldUnlock = totalGames >= 50;
          break;
        case 'games_100':
          shouldUnlock = totalGames >= 100;
          break;
        case 'snake_50':
          shouldUnlock = snakeLength >= 50;
          break;
        case 'speed_demon':
          shouldUnlock = speed <= 50; // Max speed is 50ms
          break;
      }

      if (shouldUnlock) {
        await unlock(achievement.id);
        newlyUnlocked.add(achievement);
      }
    }

    return newlyUnlocked;
  }

  /// Check if achievement is unlocked
  Future<bool> isUnlocked(String achievementId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$achievementId') ?? false;
  }

  /// Unlock achievement
  Future<void> unlock(String achievementId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$achievementId', true);
    await prefs.setString(
      '$_prefix${achievementId}_date',
      DateTime.now().toIso8601String(),
    );
  }

  /// Get all unlocked achievements
  Future<List<Achievement>> getUnlockedAchievements() async {
    final List<Achievement> unlocked = [];

    for (final achievement in achievements) {
      if (await isUnlocked(achievement.id)) {
        unlocked.add(achievement);
      }
    }

    return unlocked;
  }

  /// Get unlock date for achievement
  Future<DateTime?> getUnlockDate(String achievementId) async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString('$_prefix${achievementId}_date');
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  /// Get unlock progress (percentage)
  Future<double> getUnlockProgress() async {
    final unlockedCount = (await getUnlockedAchievements()).length;
    return unlockedCount / achievements.length;
  }

  /// Reset all achievements (for testing)
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final achievement in achievements) {
      await prefs.remove('$_prefix${achievement.id}');
      await prefs.remove('$_prefix${achievement.id}_date');
    }
  }
}
