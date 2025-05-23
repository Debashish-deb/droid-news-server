import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '/l10n/app_localizations.dart';
import '../../core/theme_provider.dart';
import '../common/animated_background.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      titleBuilder: (loc) => loc.bdNewsreader,
      descriptionBuilder: (loc) => loc.latest,
      animationAsset: 'assets/lottie/news.json',
    ),
    _OnboardingPage(
      titleBuilder: (loc) => loc.fastReliable ?? 'Fast & Reliable',
      descriptionBuilder: (loc) => loc.digitalTech,
      animationAsset: 'assets/lottie/rocket.json',
    ),
    _OnboardingPage(
      titleBuilder: (loc) => loc.personalizedExperience ?? 'Personalized Experience',
      descriptionBuilder: (loc) => loc.settings,
      animationAsset: 'assets/lottie/settings.json',
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingCompleted', true);
    context.go('/login');
  }

  void _nextPage() {
    if (_currentIndex < _pages.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.ease);
    } else {
      _completeOnboarding();
    }
  }

  void _skipToLast() {
    _controller.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.ease,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: AnimatedBackground(
        overlayOpacity: 0.15,
        blurSigma: 30,
        child: SafeArea(
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/app-icon.png', width: 96, height: 96),
                        const SizedBox(height: 24),
                        Expanded(
                          child: Lottie.asset(page.animationAsset, repeat: true),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          page.titleBuilder(loc),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.descriptionBuilder(loc),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface.withOpacity(0.85)),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
              if (_currentIndex < _pages.length - 1)
                Positioned(
                  right: 16,
                  top: 16,
                  child: TextButton(
                    onPressed: _skipToLast,
                    child: Text(loc.close, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary)),
                  ),
                ),
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (idx) {
                          final selected = idx == _currentIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: selected ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: selected ? scheme.primary : scheme.onSurface.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_currentIndex == _pages.length - 1 ? loc.getStarted : loc.next),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final String Function(AppLocalizations) titleBuilder;
  final String Function(AppLocalizations) descriptionBuilder;
  final String animationAsset;

  const _OnboardingPage({
    required this.titleBuilder,
    required this.descriptionBuilder,
    required this.animationAsset,
  });
}
