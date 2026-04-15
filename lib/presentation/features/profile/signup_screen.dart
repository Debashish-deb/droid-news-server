import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/performance_config.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/feature_providers.dart' show authServiceProvider;
import '../../providers/theme_providers.dart'
    show currentThemeModeProvider, navIconColorProvider;
import '../../../core/theme/theme.dart' show AppGradients;
import '../../../core/navigation/app_paths.dart';
import '../../widgets/platform_surface_treatment.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_skeleton.dart';
import 'package:lottie/lottie.dart';

part 'widgets/signup_widgets.dart';

// ─────────────────────────────────────────────
// DESIGN TOKENS  (unchanged from original)
// ─────────────────────────────────────────────
class _T {
  _T._();
  static const Color ink = Color(0xFF0A0A0F);
  static const Color inkMuted = Color(0xFF1C1C28);
  static const Color goldBright = Color(0xFFD4A853);
  static const Color goldMid = Color(0xFFB8892B);
  static const Color goldDim = Color(0xFF7A5C1E);
  static const Color silver = Color(0xFFC8C8D4);
  static const Color silverMuted = Color(0xFF6E6E82);
  static const Color silverFaint = Color(0xFF2A2A3A);
  static const Color errorRed = Color(0xFFFF5757);

  static const double radiusCard = 28.0;
  static const double radiusField = 16.0;
  static const double radiusButton = 18.0;

  static const Duration press = Duration(milliseconds: 90);
  static const Duration release = Duration(milliseconds: 520);

  static const Color strengthWeak = Color(0xFFFF5757);
  static const Color strengthFair = Color(0xFFFFB347);
  static const Color strengthGood = Color(0xFF34D399);
  static const Color strengthStrong = Color(0xFF10B981);
}

// ─────────────────────────────────────────────
// PASSWORD STRENGTH  (module-level, no alloc)
// ─────────────────────────────────────────────
enum _Strength { empty, weak, fair, good, strong }

_Strength _evalStrength(String p) {
  if (p.isEmpty) return _Strength.empty;
  int score = 0;
  if (p.length >= 8) score++;
  if (p.length >= 12) score++;
  if (RegExp(r'[A-Z]').hasMatch(p)) score++;
  if (RegExp(r'[0-9]').hasMatch(p)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
  if (score <= 1) return _Strength.weak;
  if (score == 2) return _Strength.fair;
  if (score == 3) return _Strength.good;
  return _Strength.strong;
}

Color _strengthColor(_Strength s) => switch (s) {
  _Strength.weak => _T.strengthWeak,
  _Strength.fair => _T.strengthFair,
  _Strength.good => _T.strengthGood,
  _Strength.strong => _T.strengthStrong,
  _Strength.empty => _T.silverFaint,
};

String _strengthLabel(_Strength s) => switch (s) {
  _Strength.weak => 'Weak',
  _Strength.fair => 'Fair',
  _Strength.good => 'Good',
  _Strength.strong => 'Strong',
  _Strength.empty => '',
};

double _strengthFill(_Strength s) => switch (s) {
  _Strength.empty => 0.0,
  _Strength.weak => 0.25,
  _Strength.fair => 0.50,
  _Strength.good => 0.75,
  _Strength.strong => 1.0,
};

// ─────────────────────────────────────────────
// EMAIL VALIDATOR
// ─────────────────────────────────────────────
final _emailRegex = RegExp(
  r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
);

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with TickerProviderStateMixin {
  // ── Controllers ─────────────────────────────
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  // ── Hot-path ValueNotifiers ──────────────────
  // Each drives only its own sub-widget – no full Scaffold rebuild.
  final _obscureNotifier = ValueNotifier<bool>(true);
  final _strengthNotifier = ValueNotifier<_Strength>(_Strength.empty);
  final _avatarNotifier = ValueNotifier<String>('?');
  final _loadingNotifier = ValueNotifier<bool>(false);
  final _errorNotifier = ValueNotifier<String?>(null);

  // ── Submission guard ─────────────────────────
  bool _submitting = false;

  // ── Strength debounce ────────────────────────
  Timer? _strengthDebounce;
  bool _didApplyEntrancePolicy = false;
  bool _authRouteTransitionInFlight = false;

  // ── Entrance animations ──────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double> _cardFade;
  late final Animation<double> _cardSlide;
  late final List<Animation<double>> _fieldFades;
  late final List<Animation<double>> _fieldSlides;

  @override
  void initState() {
    super.initState();

    // Entrance controller
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _cardFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _cardSlide = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.05, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _fieldFades = List.generate(
      3,
      (i) => CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(
          0.15 + i * 0.10,
          0.60 + i * 0.10,
          curve: Curves.easeOut,
        ),
      ),
    );
    _fieldSlides = List.generate(
      3,
      (i) => Tween<double>(begin: 20, end: 0).animate(
        CurvedAnimation(
          parent: _entranceCtrl,
          curve: Interval(
            0.15 + i * 0.10,
            0.60 + i * 0.10,
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );

    // Password strength – debounced 150 ms to avoid re-evaluating
    // on every character when typing quickly.
    _passCtl.addListener(() {
      _strengthDebounce?.cancel();
      _strengthDebounce = Timer(const Duration(milliseconds: 150), () {
        final s = _evalStrength(_passCtl.text);
        if (s != _strengthNotifier.value) {
          _strengthNotifier.value = s;
        }
      });
    });

    // Avatar initial – only updates when first char changes.
    _nameCtl.addListener(() {
      final t = _nameCtl.text.trim();
      final initial = t.isEmpty ? '?' : t[0].toUpperCase();
      if (initial != _avatarNotifier.value) {
        _avatarNotifier.value = initial;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didApplyEntrancePolicy) return;
    _didApplyEntrancePolicy = true;

    final perf = PerformanceConfig.of(context);
    final bool skipEntranceAnimation =
        perf.reduceMotion ||
        perf.reduceEffects ||
        perf.lowPowerMode ||
        perf.isLowEndDevice ||
        preferAndroidMaterialSurfaceChrome(context) ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);

    if (skipEntranceAnimation) {
      _entranceCtrl.value = 1.0;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _entranceCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _strengthDebounce?.cancel();
    _entranceCtrl.dispose();
    _nameCtl.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _obscureNotifier.dispose();
    _strengthNotifier.dispose();
    _avatarNotifier.dispose();
    _loadingNotifier.dispose();
    _errorNotifier.dispose();
    super.dispose();
  }

  // ─── Network check ──────────────────────────
  Future<bool> _hasNetwork() async {
    try {
      final r = await InternetAddress.lookup(
        'firebase.google.com',
      ).timeout(const Duration(seconds: 5));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _goToLogin() {
    if (!mounted || _authRouteTransitionInFlight) return;
    _authRouteTransitionInFlight = true;
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(AppPaths.login);
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (mounted) {
          _authRouteTransitionInFlight = false;
        }
      });
    });
  }

  // ─── Signup ──────────────────────────────────
  Future<void> _signup() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();

    final name = _nameCtl.text.trim();
    final email = _emailCtl.text.trim();
    final pass = _passCtl.text;

    // ── Client-side validation ───────────────────────────
    if (name.isEmpty) {
      _errorNotifier.value = 'Please enter your full name';
      return;
    }
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      _errorNotifier.value = 'Please enter a valid email address';
      return;
    }
    if (pass.length < 8) {
      _errorNotifier.value = 'Password must be at least 8 characters';
      return;
    }

    _submitting = true;
    _loadingNotifier.value = true;
    _errorNotifier.value = null;
    HapticFeedback.lightImpact();

    // ── Network check ────────────────────────────────────
    if (!await _hasNetwork()) {
      _submitting = false;
      _loadingNotifier.value = false;
      _errorNotifier.value =
          'No internet connection. Please check your network.';
      return;
    }

    // ── Auth call ────────────────────────────────────────
    try {
      final auth = ref.read(authServiceProvider);
      final msg = await auth.signUp(name, email, pass);

      if (!mounted) return;
      _loadingNotifier.value = false;
      if (msg != null) {
        _errorNotifier.value = msg;
      } else {
        HapticFeedback.mediumImpact();
        final currentUser = auth.currentUser;
        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).verificationEmailSent),
            ),
          );
          context.go(AppPaths.login);
        } else {
          context.go(AppPaths.home);
        }
      }
    } on TimeoutException {
      if (!mounted) return;
      _loadingNotifier.value = false;
      _errorNotifier.value = 'Request timed out. Please try again.';
    } catch (e) {
      if (!mounted) return;
      _loadingNotifier.value = false;
      _errorNotifier.value = 'An unexpected error occurred. Please try again.';
    } finally {
      _submitting = false;
    }
  }

  // ─── Google sign-in ──────────────────────────
  Future<void> _signupWithGoogle() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();

    _submitting = true;
    _loadingNotifier.value = true;
    _errorNotifier.value = null;
    HapticFeedback.lightImpact();

    if (!await _hasNetwork()) {
      _submitting = false;
      _loadingNotifier.value = false;
      _errorNotifier.value =
          'No internet connection. Please check your network.';
      return;
    }

    try {
      final auth = ref.read(authServiceProvider);
      final result = await auth.signInWithGoogle();

      if (!mounted) return;
      _loadingNotifier.value = false;
      if (result == null || auth.currentUser != null) {
        HapticFeedback.mediumImpact();
        context.go(AppPaths.home);
      } else {
        _errorNotifier.value = result;
      }
    } on TimeoutException {
      if (!mounted) return;
      final auth = ref.read(authServiceProvider);
      if (auth.currentUser != null) {
        _loadingNotifier.value = false;
        HapticFeedback.mediumImpact();
        context.go(AppPaths.home);
      } else {
        _loadingNotifier.value = false;
        _errorNotifier.value = 'Google sign-in is taking longer than expected.';
      }
    } catch (e) {
      if (!mounted) return;
      _loadingNotifier.value = false;
      _errorNotifier.value = 'Google sign-in failed. Please try again.';
    } finally {
      _submitting = false;
    }
  }

  // ─── Build ───────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final mode = ref.watch(currentThemeModeProvider);
    final accent = ref.watch(navIconColorProvider);
    final gradient = AppGradients.getBackgroundGradient(mode);
    final width = MediaQuery.sizeOf(context).width;
    final topPad = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            // ── Ambient background ───────────────
            // RepaintBoundary: only repaints on theme change,
            // never on field focus or typing events.
            RepaintBoundary(
              child: _AmbientBg(gradient: gradient, accent: accent),
            ),

            // ── Top gold rule ────────────────────
            const Positioned(top: 0, left: 0, right: 0, child: _TopRule()),

            // ── Main content ─────────────────────
            SafeArea(
              // Wrap entrance animation child in a pre-built
              // variable so AnimatedBuilder doesn't recreate the
              // inner widget tree on every animation tick.
              child: _EntranceContent(
                cardFade: _cardFade,
                cardSlide: _cardSlide,
                fieldFades: _fieldFades,
                fieldSlides: _fieldSlides,
                entranceCtrl: _entranceCtrl,
                width: width,
                loc: loc,
                accent: accent,
                // Notifiers passed down – no rebuild propagation.
                nameCtl: _nameCtl,
                emailCtl: _emailCtl,
                passCtl: _passCtl,
                nameFocus: _nameFocus,
                emailFocus: _emailFocus,
                passFocus: _passFocus,
                obscureNotifier: _obscureNotifier,
                strengthNotifier: _strengthNotifier,
                avatarNotifier: _avatarNotifier,
                loadingNotifier: _loadingNotifier,
                errorNotifier: _errorNotifier,
                onSignup: _signup,
                onGoogle: _signupWithGoogle,
                onBackToLogin: _goToLogin,
              ),
            ),

            // ── Back button ──────────────────────
            Positioned(
              top: topPad + 8,
              left: 16,
              child: _BackButton(onTap: _goToLogin),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ENTRANCE CONTENT
// Extracted as a separate StatelessWidget so that
// AnimatedBuilder.child is set once and never rebuilt
// by the animation controller – only the Transform
// wrapper rebuilds on each tick.
// ─────────────────────────────────────────────
