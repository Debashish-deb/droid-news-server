// File: lib/features/extras/extras_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/theme.dart';
import '/core/theme_provider.dart';
import '/features/common/appBar.dart';
import '/widgets/app_drawer.dart';
import '../movies/movie_widget.dart' show FullScreenMoviePage;
import '../history/history_widget.dart';
import '../quiz/daily_quiz_widget.dart';
// Import the Snake widget page
import '../../widgets/snake_widget.dart';

class ExtrasScreen extends StatelessWidget {
  const ExtrasScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ThemeProvider>();
    final mode = prov.appThemeMode;
    final gradient = AppGradients.getGradientColors(mode);
    final start = gradient[0], end = gradient[1];
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const AppBarTitle('Extras'),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: const SizedBox.expand(),
          ),
        ),
      ),
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [start.withOpacity(0.85), end.withOpacity(0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _infoCard(
                      context: context,
                      icon: Icons.movie,
                      title: 'CineSpot',
                      subtitle: 'Tap to explore cinema',
                      gradient: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => const FullScreenMoviePage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _infoCard(
                      context: context,
                      icon: Icons.history,
                      title: 'OnThisDay...',
                      subtitle: 'Events, Birthdays & Inventions',
                      gradient: const [Color(0xFFFC4A1A), Color(0xFFF7B733)],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => const HistoryWidget(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _infoCard(
                      context: context,
                      icon: Icons.quiz,
                      title: 'BrainBuzz',
                      subtitle: 'Trivia game, track streaks, earn badges!',
                      gradient: const [Color(0xFF36D1DC), Color(0xFF5B86E5)],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => const DailyQuizWidget(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Snake game card
                    _infoCard(
                      context: context,
                      icon: Icons.videogame_asset,
                      title: 'Snake Circuit',
                      subtitle: "১৯৯০ দশকের ক্লাসিক স্নেক গেমটি খেলুন",
                      gradient: const [Color.fromARGB(255, 4, 104, 92), Color(0xFF96C93D)],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => const SnakeGame(),
                        ),
                      ),

                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    final prov = context.read<ThemeProvider>();
    final theme = Theme.of(context);
    final titleStyle = prov.floatingTextStyle(fontSize: 20);
    final subtitleStyle = prov.floatingTextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: theme.textTheme.bodyMedium!.color!.withOpacity(0.7),
    );

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 180,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradient[0].withOpacity(0.35),
                  gradient[1].withOpacity(0.25),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradient.last.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: Colors.white),
                const SizedBox(height: 14),
                Text(title, style: titleStyle),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle, style: subtitleStyle, textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
