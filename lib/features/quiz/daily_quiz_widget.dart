// lib/features/quiz/daily_quiz_widget.dart

import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '/core/theme_provider.dart';
import '/core/theme.dart';
import '/l10n/app_localizations.dart';

class QuizQuestion {
  final String prompt;
  final List<String> options;
  final String correct;

  QuizQuestion({
    required this.prompt,
    required this.options,
    required this.correct,
  });
}

class DailyQuizWidget extends StatefulWidget {
  const DailyQuizWidget({Key? key}) : super(key: key);

  @override
  State<DailyQuizWidget> createState() => _DailyQuizWidgetState();
}

class _DailyQuizWidgetState extends State<DailyQuizWidget> {
  final _confetti = ConfettiController(duration: const Duration(seconds: 3));
  final _player = AudioPlayer();

  List<QuizQuestion> _questions = [];
  int _current = 0;
  int _score = 0;
  bool _loading = true;
  bool _showResult = false;
  bool _answered = false;
  int _streak = 0;
  int _highScore = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _fetchQuiz();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _streak = prefs.getInt('quiz_streak') ?? 0;
      _highScore = prefs.getInt('quiz_high_score') ?? 0;
    });
  }

  Future<void> _saveStats() async {
    final prefs = await SharedPreferences.getInstance();
    if (_score == _questions.length) {
      _streak++;
    } else {
      _streak = 0;
    }
    if (_score > _highScore) {
      _highScore = _score;
      await prefs.setInt('quiz_high_score', _highScore);
    }
    await prefs.setInt('quiz_streak', _streak);
  }

  Future<void> _fetchQuiz() async {
    setState(() {
      _loading = true;
      _showResult = false;
      _answered = false;
    });

    try {
      final raw = await rootBundle.loadString('assets/quizzes/bn_daily_expanded.json');
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw FormatException('Quiz JSON does not contain a List');

      final pool = (decoded as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      if (pool.isEmpty) throw Exception('No valid quiz items found');

      pool.shuffle();
      final selected = pool.take(5).toList();

      final qs = selected.map((item) {
        final question = item['question']?.toString() ?? '<no prompt>';
        List<String> opts = [];
        final rawOpts = item['options'];
        if (rawOpts is List) {
          opts = rawOpts.map((o) => o.toString()).toList();
        } else if (rawOpts is Map) {
          final entries = (rawOpts as Map<String, dynamic>).entries.toList()
            ..sort((a, b) => int.tryParse(a.key)!.compareTo(int.tryParse(b.key)!));
          opts = entries.map((e) => e.value.toString()).toList();
        }
        final correctRaw = item['correct'];
        String correct;
        if (correctRaw is int && correctRaw < opts.length) {
          correct = opts[correctRaw];
        } else {
          correct = correctRaw.toString();
        }
        return QuizQuestion(prompt: question, options: opts, correct: correct);
      }).toList();

      setState(() {
        _questions = qs;
        _current = 0;
        _score = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _questions = [];
        _loading = false;
      });
    }
  }

  Future<void> _answer(String choice) async {
    if (_answered) return;
    setState(() => _answered = true);

    final prov = context.read<ThemeProvider>();
    if (choice == _questions[_current].correct) {
      _score++;
      _confetti.play();
      await _player.play(AssetSource('sounds/correct.mp3'));
    } else {
      await _player.play(AssetSource('sounds/wrong.mp3'));
    }
  }

  void _previous() {
    if (_current > 0) {
      setState(() {
        _current--;
        _answered = false;
      });
    }
  }

  Future<void> _next() async {
    if (_current + 1 < _questions.length) {
      setState(() {
        _current++;
        _answered = false;
      });
    } else {
      await _saveStats();
      setState(() => _showResult = true);
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final prov = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final colors = AppGradients.getGradientColors(prov.appThemeMode);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(loc.dailyQuiz, style: prov.floatingTextStyle(fontSize: 20)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🔥 $_streak ${loc.streak}', style: theme.textTheme.bodyMedium),
                Text('🏆 $_highScore ${loc.highScore}', style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _showResult
              ? _buildSummary(context, prov)
              : _buildQuizView(context, prov, colors),
      bottomNavigationBar:
          (_loading || _showResult) ? null : _buildFooterNav(prov, theme),
    );
  }

  Widget _buildQuizView(BuildContext context, ThemeProvider prov, List<Color> colors) {
    final q = _questions[_current];
    final theme = Theme.of(context);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors[0].withOpacity(0.8), colors[1].withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: (_current + 1) / _questions.length,
                  minHeight: 6,
                  backgroundColor: prov.glassColor,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.secondary),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _glassCard(prov, theme, child: _buildQuestion(q, theme)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 0, right: 0,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirection: pi / 2,
            numberOfParticles: 40,
            gravity: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion(QuizQuestion q, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Q${_current + 1}: ${q.prompt}',
            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onBackground)),
        const SizedBox(height: 12),
        ...q.options.map((opt) {
          final isCorrect = _answered && opt == q.correct;
          return Card(
            color: isCorrect
                ? theme.colorScheme.primary.withOpacity(0.3)
                : theme.cardColor,
            child: ListTile(
              title: Text(opt),
              onTap: () => _answer(opt),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSummary(BuildContext context, ThemeProvider prov) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _glassCard(
          prov,
          theme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Text('🎉 ${loc.quizSummary}', style: prov.floatingTextStyle(fontSize: 24))),
              const SizedBox(height: 16),
              ..._questions.asMap().entries.map((e) {
                final i = e.key;
                final q = e.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Q${i + 1}: ${q.prompt}', style: theme.textTheme.bodyLarge),
                    Text('✅ ${loc.correct}: ${q.correct}', style: theme.textTheme.bodyMedium),
                    const Divider(),
                  ],
                );
              }),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _fetchQuiz,
                  child: Text(loc.tryAgain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterNav(ThemeProvider prov, ThemeData theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navButton(
              icon: Icons.arrow_back,
              onPressed: _previous,
              prov: prov,
            ),
            _navButton(
              icon: _answered ? Icons.check : Icons.arrow_forward,
              onPressed: _answered ? _next : null,
              prov: prov,
              enabled: _answered,
            ),
            _navButton(
              icon: Icons.exit_to_app,
              onPressed: () => Navigator.pop(context),
              prov: prov,
              tonal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _navButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required ThemeProvider prov,
    bool enabled = true,
    bool tonal = false,
  }) {
    final style = tonal
      ? IconButton.styleFrom(
          backgroundColor: prov.glassColor,
          shape: const CircleBorder(),
        )
      : IconButton.styleFrom(
          backgroundColor: prov.glassColor,
          shape: const CircleBorder(),
        );
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      style: style,
    );
  }

  Widget _glassCard(ThemeProvider prov, ThemeData theme, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: prov.glassColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: prov.borderColor),
          ),
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}
