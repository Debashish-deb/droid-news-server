// ignore_for_file: avoid_classes_with_only_static_members

// lib/features/onboarding/onboarding_screen.dart
//
// PERF FIXES vs original:
// • _onPageScroll: setState→ValueNotifier, only _BackgroundLayer rebuilds on drag
// • AnimatedBuilder scoped to Opacity+Transform only (not full itemBuilder subtree)
//   and skipped entirely for pages that are not the current active page
// • _AppStrip + _BottomActions isolated in RepaintBoundary — never repaint on scroll
// • _GrainPainter wrapped in RepaintBoundary: GPU bitmap cached after first frame
// • withOpacity() hot-path replaced with const Color hex literals where possible

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/theme/theme.dart' show AppColorsExtension;

extension _CtxColors on BuildContext {
  AppColorsExtension get colors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}

class _T {
  static const double displaySize = 38.0;
  static const double captionSize = 11.0;
  static const double labelSize = 13.0;
  static const double bodySize = 15.0;
  static const double pagePadH = 28.0;

  static const Duration entrance = Duration(milliseconds: 520);
  static const Duration indicator = Duration(milliseconds: 380);
  static const Duration press = Duration(milliseconds: 90);
  static const Duration release = Duration(milliseconds: 480);

  static List<Color> slideAccents(BuildContext context) {
    final c = context.colors;
    return [c.slideBlue, c.slideGreen, c.slideRed];
  }
}

class _PageData {
  const _PageData({
    required this.eyebrow,
    required this.title,
    required this.titleAccent,
    required this.body,
    required this.animationAsset,
    required this.featureTags,
  });
  final String eyebrow;
  final String title;
  final String titleAccent;
  final String body;
  final String animationAsset;
  final List<String> featureTags;
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pageCtrl = PageController();

  int _currentIndex = 0;
  bool _transitioning = false;

  // Parallax lives in a ValueNotifier — changing it does NOT call setState on
  // this State object; only _BackgroundLayer (via ValueListenableBuilder) rebuilds.
  final _parallaxOffset = ValueNotifier<double>(0.0);

  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;
  late final Animation<double> _scaleIn;

  List<_PageData> _getPages(AppLocalizations loc) => [
    _PageData(
      eyebrow: '01 / TRUSTED JOURNALISM',
      title: 'Your daily news,\ncurated for you',
      titleAccent: 'curated',
      body: loc.appDescription,
      animationAsset: 'assets/lottie/news.json',
      featureTags: const ['Live Updates', 'Verified Sources', '10+ Papers'],
    ),
    const _PageData(
      eyebrow: '02 / PREMIUM CONTENT',
      title: 'Magazines &\nlong-form reads',
      titleAccent: 'long-form',
      body:
          'Deep dives, features and analysis from Bangladesh\'s top editorial teams — beautifully formatted.',
      animationAsset: 'assets/lottie/magazine.json',
      featureTags: ['40+ Magazines', 'Offline Reading', 'Save & Share'],
    ),
    const _PageData(
      eyebrow: '03 / STAY INFORMED',
      title: 'Breaking alerts\nin real-time',
      titleAccent: 'real-time',
      body:
          'Instant notifications for the stories that matter. Personalise your feed by topic, region or source.',
      animationAsset: 'assets/lottie/news.json',
      featureTags: ['Smart Alerts', 'Topic Filter', 'Personalised'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(vsync: this, duration: _T.entrance);
    _fadeIn = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _slideUp = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.1, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    _scaleIn = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _pageCtrl.addListener(_onPageScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceCtrl.forward();
    });
  }

  // No setState — only the ValueNotifier is mutated.
  void _onPageScroll() => _parallaxOffset.value = _pageCtrl.page ?? 0;

  Future<void> _goToPage(int index, int total) async {
    if (_transitioning) return;
    HapticFeedback.lightImpact();
    if (index < total) {
      _transitioning = true;
      await _pageCtrl.animateToPage(
        index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
      _entranceCtrl.reset();
      _entranceCtrl.forward();
      if (mounted) setState(() => _transitioning = false);
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) context.go(AppPaths.login);
  }

  @override
  void dispose() {
    _pageCtrl.removeListener(_onPageScroll);
    _pageCtrl.dispose();
    _entranceCtrl.dispose();
    _parallaxOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final pages = _getPages(loc);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accents = _T.slideAccents(context);
    final accent = accents[_currentIndex];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: Stack(
          children: [
            // BACKGROUND — only this widget rebuilds on page drag
            RepaintBoundary(
              child: ValueListenableBuilder<double>(
                valueListenable: _parallaxOffset,
                builder: (_, offset, _) => _BackgroundLayer(
                  accent: accent,
                  isDark: isDark,
                  cs: cs,
                  pageOffset: offset,
                ),
              ),
            ),

            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 20),
                  child: _currentIndex < pages.length - 1
                      ? _SkipButton(isDark: isDark, onTap: _completeOnboarding)
                      : const SizedBox.shrink(),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Static — RepaintBoundary prevents repaint from parallax changes
                  RepaintBoundary(
                    child: _AppStrip(accent: accent, isDark: isDark, cs: cs),
                  ),

                  Expanded(
                    child: PageView.builder(
                      controller: _pageCtrl,
                      itemCount: pages.length,
                      onPageChanged: (i) {
                        setState(() => _currentIndex = i);
                        _entranceCtrl.reset();
                        _entranceCtrl.forward();
                        HapticFeedback.selectionClick();
                      },
                      itemBuilder: (ctx, i) {
                        final pageAccent = accents[i];

                        // Non-active pages: skip AnimatedBuilder entirely.
                        // Active page: AnimatedBuilder wraps only the
                        // Opacity + Transform, NOT the full content tree.
                        final content = _PageContent(
                          page: pages[i],
                          accent: pageAccent,
                          isDark: isDark,
                          cs: cs,
                        );

                        if (i != _currentIndex) return content;

                        return AnimatedBuilder(
                          animation: _entranceCtrl,
                          child:
                              content, // stable child — not rebuilt by animation
                          builder: (_, child) => Opacity(
                            opacity: _fadeIn.value.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(0, _slideUp.value),
                              child: Transform.scale(
                                scale: _scaleIn.value,
                                child: child,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  RepaintBoundary(
                    child: _BottomActions(
                      pages: pages,
                      currentIndex: _currentIndex,
                      accent: accent,
                      isDark: isDark,
                      cs: cs,
                      loc: loc,
                      onNext: () => _goToPage(_currentIndex + 1, pages.length),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Background ───────────────────────────────────────────
class _BackgroundLayer extends StatelessWidget {
  const _BackgroundLayer({
    required this.accent,
    required this.isDark,
    required this.cs,
    required this.pageOffset,
  });
  final Color accent;
  final bool isDark;
  final ColorScheme cs;
  final double pageOffset;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.6),
          radius: 1.2,
          colors: [
            accent.withValues(alpha: isDark ? 0.18 : 0.10),
            cs.surface,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -60,
            child: Transform.translate(
              offset: Offset(-pageOffset * 18, pageOffset * 8),
              child: _GlowCircle(
                size: 320,
                color: accent.withValues(alpha: isDark ? 0.12 : 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: -40,
            child: Transform.translate(
              offset: Offset(pageOffset * 12, -pageOffset * 6),
              child: _GlowCircle(
                size: 240,
                color: accent.withValues(alpha: isDark ? 0.08 : 0.05),
              ),
            ),
          ),
          // RepaintBoundary caches grain to GPU; shouldRepaint→false = never redraws
          Positioned.fill(
            child: RepaintBoundary(
              child: Opacity(
                opacity: 0.028,
                child: CustomPaint(painter: _GrainPainter()),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    accent.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}

// ─── App strip ────────────────────────────────────────────
class _AppStrip extends StatelessWidget {
  const _AppStrip({
    required this.accent,
    required this.isDark,
    required this.cs,
  });
  final Color accent;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top > 0 ? 12 : 24,
        bottom: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/play_store_512-app.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                  child: const Center(
                    child: Text(
                      'BD',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BD NewsReader',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                  color: cs.onSurface,
                  height: 1.1,
                ),
              ),
              Text(
                'BANGLADESH\'S PREMIUM NEWS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: accent,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Page content (stateless — no animation state here) ──
class _PageContent extends StatelessWidget {
  const _PageContent({
    required this.page,
    required this.accent,
    required this.isDark,
    required this.cs,
  });
  final _PageData page;
  final Color accent;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _T.pagePadH),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Expanded(
            flex: 5,
            child: _AnimationBlock(
              asset: page.animationAsset,
              accent: accent,
              isDark: isDark,
            ),
          ),
          Expanded(
            flex: 4,
            child: _TextBlock(
              page: page,
              accent: accent,
              cs: cs,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimationBlock extends StatelessWidget {
  const _AnimationBlock({
    required this.asset,
    required this.accent,
    required this.isDark,
  });
  final String asset;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                accent.withValues(alpha: isDark ? 0.14 : 0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),
        SizedBox(
          height: 190,
          child: Lottie.asset(
            asset,
            repeat: true,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => CustomPaint(
              size: const Size(180, 180),
              painter: _NewspaperPainter(
                accent: accent,
                isDark: isDark,
                colors: context.colors,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NewspaperPainter extends CustomPainter {
  const _NewspaperPainter({
    required this.accent,
    required this.isDark,
    required this.colors,
  });
  final Color accent;
  final bool isDark;
  final AppColorsExtension colors;

  @override
  void paint(Canvas canvas, Size s) {
    final base = colors.textPrimary;
    final bg = colors.card;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          s.width * .1,
          s.height * .05,
          s.width * .8,
          s.height * .9,
        ),
        const Radius.circular(12),
      ),
      Paint()..color = bg,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          s.width * .1,
          s.height * .05,
          s.width * .8,
          s.height * .14,
        ),
        const Radius.circular(12),
      ),
      Paint()..color = accent,
    );
    final lp = Paint()
      ..color = base.withValues(alpha: 0.12)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final y = s.height * (0.27 + i * 0.12);
      final w = i == 0
          ? s.width * .6
          : (i % 2 == 0 ? s.width * .5 : s.width * .55);
      canvas.drawLine(
        Offset(s.width * .18, y),
        Offset(s.width * .18 + w, y),
        lp,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          s.width * .18,
          s.height * .60,
          s.width * .64,
          s.height * .25,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = accent.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.page,
    required this.accent,
    required this.cs,
    required this.isDark,
  });
  final _PageData page;
  final Color accent;
  final ColorScheme cs;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accent.withValues(alpha: 0.20)),
            ),
            child: Text(
              page.eyebrow,
              style: TextStyle(
                fontSize: _T.captionSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: accent,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _HighlightTitle(
            fullText: page.title,
            accentWord: page.titleAccent,
            accent: accent,
            baseColor: cs.onSurface,
          ),
          const SizedBox(height: 12),
          Text(
            page.body,
            style: TextStyle(
              fontSize: _T.bodySize,
              height: 1.55,
              color: cs.onSurface.withValues(alpha: 0.60),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: page.featureTags
                .map((t) => _Tag(label: t, accent: accent, isDark: isDark))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _HighlightTitle extends StatelessWidget {
  const _HighlightTitle({
    required this.fullText,
    required this.accentWord,
    required this.accent,
    required this.baseColor,
  });
  final String fullText, accentWord;
  final Color accent, baseColor;
  static const _base = TextStyle(
    fontSize: _T.displaySize,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.0,
    height: 1.10,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fullText.split('\n').map((line) {
        final idx = line.toLowerCase().indexOf(accentWord.toLowerCase());
        if (idx == -1) {
          return Text(line, style: _base.copyWith(color: baseColor));
        }
        return Text.rich(
          TextSpan(
            children: [
              if (idx > 0) TextSpan(text: line.substring(0, idx)),
              TextSpan(
                text: line.substring(idx, idx + accentWord.length),
                style: TextStyle(
                  color: accent,
                  decoration: TextDecoration.underline,
                  decorationColor: accent.withValues(alpha: 0.4),
                  decorationThickness: 2,
                ),
              ),
              if (idx + accentWord.length < line.length)
                TextSpan(text: line.substring(idx + accentWord.length)),
            ],
          ),
          style: _base.copyWith(color: baseColor),
        );
      }).toList(),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.accent, required this.isDark});
  final String label;
  final Color accent;
  final bool isDark;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark
            ? colors.textPrimary.withValues(alpha: 0.06)
            : colors.textPrimary.withValues(alpha: 0.04),
        border: Border.all(
          color: colors.textPrimary.withValues(alpha: isDark ? 0.12 : 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: _T.captionSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom actions ───────────────────────────────────────
class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.pages,
    required this.currentIndex,
    required this.accent,
    required this.isDark,
    required this.cs,
    required this.loc,
    required this.onNext,
  });
  final List<_PageData> pages;
  final int currentIndex;
  final Color accent;
  final bool isDark;
  final ColorScheme cs;
  final AppLocalizations loc;
  final VoidCallback onNext;
  bool get _isLast => currentIndex == pages.length - 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _T.pagePadH,
        12,
        _T.pagePadH,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(
              pages.length,
              (i) => Expanded(
                child: AnimatedContainer(
                  duration: _T.indicator,
                  curve: Curves.easeInOut,
                  height: i == currentIndex ? 3 : 2,
                  margin: EdgeInsets.only(right: i < pages.length - 1 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i == currentIndex
                        ? accent
                        : i < currentIndex
                        ? accent.withValues(alpha: 0.40)
                        : context.colors.textHint.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: i == currentIndex
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _CTAButton(
            label: _isLast ? loc.getStarted : loc.continueBtn,
            accent: accent,
            isLast: _isLast,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _CTAButton extends StatefulWidget {
  const _CTAButton({
    required this.label,
    required this.accent,
    required this.isLast,
    required this.onTap,
  });
  final String label;
  final Color accent;
  final bool isLast;
  final VoidCallback onTap;
  @override
  State<_CTAButton> createState() => _CTAButtonState();
}

class _CTAButtonState extends State<_CTAButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: _pressed ? _T.press : _T.release,
        curve: _pressed ? Curves.easeIn : Curves.elasticOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [widget.accent, widget.accent.withValues(alpha: 0.80)],
            ),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: context.colors.bg,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_rounded,
                color: context.colors.bg,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.isDark, required this.onTap});
  final bool isDark;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: context.colors.textPrimary.withValues(alpha: 0.05),
        border: Border.all(
          color: context.colors.textPrimary.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        'Skip',
        style: TextStyle(
          fontSize: _T.labelSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: context.colors.textSecondary,
        ),
      ),
    ),
  );
}

// Grain — never repaints; RepaintBoundary caches it to a GPU texture.
class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = _Lcg(91);
    final paint = Paint()..strokeWidth = 1;
    for (var i = 0; i < 5000; i++) {
      paint.color = Colors.white.withValues(alpha: rng.next() * 0.7 + 0.1);
      canvas.drawCircle(
        Offset(rng.next() * size.width, rng.next() * size.height),
        0.4,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _Lcg {
  _Lcg(int seed) : _s = seed;
  int _s;
  double next() {
    _s = (_s * 1664525 + 1013904223) & 0xFFFFFFFF;
    return (_s & 0x7FFFFFFF) / 0x7FFFFFFF;
  }
}
