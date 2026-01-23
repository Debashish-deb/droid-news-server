import 'package:flutter/material.dart';
import '../stats/game_stats.dart';
import '../achievements/achievements_manager.dart';

/// Stats and achievements screen
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final GameStats _stats = GameStats();
  final AchievementsManager _achievements = AchievementsManager();

  bool _isLoading = true;
  List<Achievement> _unlocked = [];
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _stats.load();
    _unlocked = await _achievements.getUnlockedAchievements();
    _progress = await _achievements.getUnlockProgress();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Game Stats'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall stats card
            _buildStatsCard(),

            const SizedBox(height: 24),

            // Achievements section
            _buildAchievementsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart, size: 28),
                SizedBox(width: 12),
                Text(
                  'Statistics',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Grid of stats
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildStatTile(
                  'Games Played',
                  _stats.totalGames.toString(),
                  Icons.games,
                ),
                _buildStatTile(
                  'High Score',
                  _stats.highScore.toString(),
                  Icons.emoji_events,
                ),
                _buildStatTile(
                  'Avg Score',
                  _stats.averageScore.toStringAsFixed(1),
                  Icons.trending_up,
                ),
                _buildStatTile(
                  'Total Food',
                  _stats.totalFoodEaten.toString(),
                  Icons.apple,
                ),
                _buildStatTile(
                  'Longest Snake',
                  _stats.longestSnake.toString(),
                  Icons.show_chart,
                ),
                _buildStatTile(
                  'Best Speed',
                  '${_stats.fastestSpeed}ms',
                  Icons.speed,
                ),
              ],
            ),

            if (_stats.firstGameDate != null) ...[
              const SizedBox(height: 20),
              Text(
                'Playing for ${_stats.daysSinceFirstGame} days',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blue[700]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.stars, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Achievements',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_unlocked.length}/${AchievementsManager.achievements.length}',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
              ),
            ),

            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toStringAsFixed(0)}% Complete',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),

            const SizedBox(height: 24),

            // Achievement list
            ...AchievementsManager.achievements.map((achievement) {
              final isUnlocked = _unlocked.any((a) => a.id == achievement.id);
              return _buildAchievementTile(achievement, isUnlocked);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementTile(Achievement achievement, bool unlocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked ? Colors.green[300]! : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: unlocked ? Colors.green[100] : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                achievement.icon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: unlocked ? Colors.green[900] : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: unlocked ? Colors.green[700] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Checkmark if unlocked
          if (unlocked)
            Icon(Icons.check_circle, color: Colors.green[700], size: 28),
        ],
      ),
    );
  }
}
