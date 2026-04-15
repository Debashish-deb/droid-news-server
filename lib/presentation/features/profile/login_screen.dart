// lib/features/auth/login_screen.dart — Android Optimised
//
// PERF FIXES vs original:
// • AnimatedBuilder was wrapping the ENTIRE build() → split:
//   - _orbScale AnimatedBuilder → orbs only (RepaintBoundary cached after 600ms)
//   - _fade+_slide AnimatedBuilder → content column only
//   After the 1100ms entrance, zero further rebuilds from the controller.
// • _PremiumField is now a StatefulWidget that owns its focus state.
//   Tapping a field no longer rebuilds the parent Scaffold.
// • _loading / _error are ValueNotifiers → only the button/banner widget
//   rebuilds on login attempts, not the entire screen.
// • BackdropFilter wrapped in RepaintBoundary → blur layer composites only
//   the card's layer, not the entire ancestor tree.
// • _GrainPainter + orbs in RepaintBoundary → GPU texture cached forever.
// • withOpacity() in const positions replaced with const Color hex literals.

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/performance_config.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/feature_providers.dart' show authServiceProvider;
import '../../../core/navigation/app_paths.dart';
import '../../widgets/platform_surface_treatment.dart';

class _Token {
  static const Color goldBright = Color(0xFFD4A853);
  static const Color goldMid = Color(0xFFB8892B);
  static const Color goldDim = Color(0xFF7A5C1E);
  static const Color silver = Color(
    0xFF1C1C28,
  ); // Text color swapped for light theme
  static const Color silverMuted = Color(0xFF6E6E82);
  static const Color silverFaint = Color(0xFFD1D1D6);
  static const Color errorRed = Color(0xFFFF3B30);
  static const Color errorRedSurf = Color(0x22FF3B30);
  static const double radiusCard = 28.0;
  static const double radiusField = 16.0;
  static const double radiusButton = 18.0;
}

const String _emailVerificationRequiredPrefix =
    'Please verify your email address before logging in.';
const String _verificationEmailCooldownMessage =
    'Verification email was sent recently. Please wait before requesting another one.';

bool _isEmailVerificationMessage(String msg) {
  return msg.startsWith(_emailVerificationRequiredPrefix) ||
      msg == _verificationEmailCooldownMessage;
}

String _localizedAuthMessage(AppLocalizations loc, String msg) {
  if (msg.startsWith(_emailVerificationRequiredPrefix)) {
    return loc.emailNotVerified;
  }
  if (msg == _verificationEmailCooldownMessage) {
    return loc.verificationEmailCooldown;
  }
  return msg;
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _passwordFocus = FocusNode();

  late final AnimationController _ctrl;
  late final Animation<double> _fade, _slide, _orbScale;

  // ValueNotifiers: changing them never rebuilds the Scaffold.
  final _loading = ValueNotifier<bool>(false);
  final _error = ValueNotifier<String?>(null);

  bool _obscurePassword = true;
  bool _didApplyEntrancePolicy = false;
  bool _authRouteTransitionInFlight = false;

  static const _orbs = [
    _OrbDef(dx: -0.15, dy: 0.05, size: 340, opacity: 0.18),
    _OrbDef(dx: 0.60, dy: -0.10, size: 260, opacity: 0.12),
    _OrbDef(dx: 0.80, dy: 0.70, size: 200, opacity: 0.09),
    _OrbDef(dx: -0.05, dy: 0.85, size: 180, opacity: 0.07),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.20, 1.0, curve: Curves.easeOut),
    );
    _slide = Tween<double>(begin: 48, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.10, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _orbScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
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
      _ctrl.value = 1.0;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ctrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _emailCtl.dispose();
    _passCtl.dispose();
    _passwordFocus.dispose();
    _loading.dispose();
    _error.dispose();
    super.dispose();
  }

  String? _validateEmail() {
    final email = _emailCtl.text.trim();
    if (email.isEmpty) return null;
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _error.value = 'Please enter a valid email address';
      return 'invalid';
    }
    return null;
  }

  Future<void> _login() async {
    if (_validateEmail() != null) return;
    if (_emailCtl.text.trim().isEmpty || _passCtl.text.isEmpty) {
      _error.value = 'Please fill in all fields';
      return;
    }
    _loading.value = true;
    _error.value = null;
    try {
      final auth = ref.read(authServiceProvider);
      final msg = await auth.login(_emailCtl.text.trim(), _passCtl.text);
      if (!mounted) return;
      if (msg == null || auth.currentUser != null) {
        _loading.value = false;
        context.go(AppPaths.home);
      } else {
        _loading.value = false;
        _error.value = msg;
      }
    } on TimeoutException {
      if (mounted) {
        final auth = ref.read(authServiceProvider);
        if (auth.currentUser != null) {
          _loading.value = false;
          context.go(AppPaths.home);
        } else {
          _loading.value = false;
          _error.value = 'Connection timed out. Please try again.';
        }
      }
    } catch (e) {
      if (mounted) {
        _loading.value = false;
        _error.value = 'Unable to sign in right now. Please try again.';
      }
    }
  }

  Future<void> _resendEmailVerification() async {
    if (_loading.value) return;
    if (_emailCtl.text.trim().isEmpty || _passCtl.text.isEmpty) {
      _error.value = 'Please fill in all fields';
      return;
    }

    _loading.value = true;
    try {
      final auth = ref.read(authServiceProvider);
      final msg = await auth.resendEmailVerification(
        _emailCtl.text.trim(),
        _passCtl.text,
      );
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      final snackMessage = msg == null
          ? loc.verificationEmailResent
          : _localizedAuthMessage(loc, msg);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(snackMessage)));
      if (msg == null || _isEmailVerificationMessage(msg)) {
        _error.value = _emailVerificationRequiredPrefix;
      } else {
        _error.value = msg;
      }
    } catch (e) {
      if (mounted) {
        _error.value = 'Unable to resend verification email right now.';
      }
    } finally {
      if (mounted) {
        _loading.value = false;
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    _loading.value = true;
    _error.value = null;
    try {
      final auth = ref.read(authServiceProvider);
      final result = await auth.signInWithGoogle();
      if (!mounted) return;
      if (result == null || auth.currentUser != null) {
        _loading.value = false;
        context.go(AppPaths.home);
      } else {
        _loading.value = false;
        _error.value = result;
      }
    } on TimeoutException {
      if (!mounted) return;
      final auth = ref.read(authServiceProvider);
      if (auth.currentUser != null) {
        _loading.value = false;
        context.go(AppPaths.home);
      } else {
        _loading.value = false;
        _error.value = 'Google sign-in is taking longer than expected.';
      }
    } catch (e) {
      if (mounted) {
        _loading.value = false;
        _error.value = 'Google sign-in failed. Please try again.';
      }
    }
  }

  void _openSignup() {
    if (!mounted || _authRouteTransitionInFlight) return;
    _authRouteTransitionInFlight = true;
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(AppPaths.signup);
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (mounted) {
          _authRouteTransitionInFlight = false;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Orbs — AnimatedBuilder scoped to _orbScale only
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _orbScale,
              builder: (_, _) => Stack(
                children: _orbs
                    .map(
                      (o) => _AmbientOrb(
                        def: o,
                        screenSize: size,
                        scale: _orbScale.value,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),

          // Top gold rule
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    _Token.goldMid,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content — AnimatedBuilder scoped to fade+slide only
          SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([_fade, _slide]),
              child: _LoginBody(
                // stable child — not rebuilt by animation ticks
                emailCtl: _emailCtl,
                passCtl: _passCtl,
                passwordFocus: _passwordFocus,
                loading: _loading,
                error: _error,
                obscurePassword: _obscurePassword,
                onToggleObscure: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                onLogin: _login,
                onGoogle: _loginWithGoogle,
                onResendVerification: _resendEmailVerification,
                onRetryVerification: _login,
                onCreateAccount: _openSignup,
                loc: loc,
              ),
              builder: (_, child) => FadeTransition(
                opacity: _fade,
                child: Transform.translate(
                  offset: Offset(0, _slide.value),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Body (stateless) ─────────────────────────────────────
class _LoginBody extends StatelessWidget {
  const _LoginBody({
    required this.emailCtl,
    required this.passCtl,
    required this.passwordFocus,
    required this.loading,
    required this.error,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.onLogin,
    required this.onGoogle,
    required this.onResendVerification,
    required this.onRetryVerification,
    required this.onCreateAccount,
    required this.loc,
  });
  final TextEditingController emailCtl, passCtl;
  final FocusNode passwordFocus;
  final ValueNotifier<bool> loading;
  final ValueNotifier<String?> error;
  final bool obscurePassword;
  final VoidCallback onToggleObscure,
      onLogin,
      onGoogle,
      onResendVerification,
      onRetryVerification,
      onCreateAccount;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.055,
        vertical: 24,
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildHeader(loc),
          const SizedBox(height: 40),
          _buildFormCard(context),
          const SizedBox(height: 28),
          _buildFooter(context, loc),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations loc) => Column(
    children: [
      Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _Token.silverFaint, width: 1.5),
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/play_store_512-app.png',
            width: 88,
            height: 88,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(
              Icons.article_rounded,
              size: 42,
              color: _Token.silverMuted,
            ),
          ),
        ),
      ),
      const SizedBox(height: 22),
      const Text(
        'BD NewsReader',
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: _Token.silver,
          letterSpacing: -0.8,
          height: 1.0,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        width: 48,
        height: 1.5,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, _Token.goldBright, Colors.transparent],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        loc.loginToContinue,
        style: const TextStyle(
          fontSize: 13,
          color: _Token.silverMuted,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );

  // BackdropFilter isolated in RepaintBoundary — blur only composites this card's layer
  Widget _buildFormCard(BuildContext context) {
    final theme = Theme.of(context);
    final perf = PerformanceConfig.of(context);
    final preferMaterialChrome = preferAndroidMaterialSurfaceChrome(context);
    final bool cheapComposite =
        perf.reduceEffects ||
        perf.lowPowerMode ||
        perf.isLowEndDevice ||
        preferMaterialChrome;
    final Color cardColor = preferMaterialChrome
        ? materialSurfaceOverlayColor(
            theme.colorScheme,
            tone: MaterialSurfaceTone.highest,
            surfaceAlpha: 0.97,
            tintAlpha: 0.04,
          )
        : Colors.white.withValues(alpha: 0.85);
    final Color borderColor = preferMaterialChrome
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.68)
        : Colors.white;
    final List<BoxShadow> boxShadows = preferMaterialChrome
        ? const <BoxShadow>[
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ]
        : const <BoxShadow>[
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 48,
              offset: Offset(0, 24),
            ),
            BoxShadow(
              color: Color(0x05D4A853),
              blurRadius: 80,
              spreadRadius: 8,
            ),
          ];

    final formContent = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_Token.radiusCard),
        color: cardColor,
        border: Border.all(color: borderColor),
        boxShadow: boxShadows,
      ),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              _GoldDot(),
              SizedBox(width: 10),
              Text(
                'SIGN IN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _Token.goldBright,
                  letterSpacing: 2.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Each _PremiumField manages its own focus; no parent rebuild on tap
          _PremiumField(
            controller: emailCtl,
            nextFocus: passwordFocus,
            label: 'Email address',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),

          _PremiumField(
            controller: passCtl,
            focusNode: passwordFocus,
            label: 'Password',
            icon: Icons.shield_outlined,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onLogin(),
            suffixChild: GestureDetector(
              onTap: onToggleObscure,
              child: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: obscurePassword ? _Token.silverMuted : _Token.goldBright,
              ),
            ),
          ),

          // Only error banner rebuilds when error changes
          ValueListenableBuilder<String?>(
            valueListenable: error,
            builder: (_, msg, _) {
              if (msg == null || msg.isEmpty) {
                return const SizedBox.shrink();
              }

              final isVerificationMessage = _isEmailVerificationMessage(msg);
              return Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Column(
                  children: [
                    _ErrorBanner(message: _localizedAuthMessage(loc, msg)),
                    if (isVerificationMessage) ...[
                      const SizedBox(height: 12),
                      ValueListenableBuilder<bool>(
                        valueListenable: loading,
                        builder: (_, isLoading, _) =>
                            _VerificationRecoveryPanel(
                              loc: loc,
                              loading: isLoading,
                              onResend: onResendVerification,
                              onRetry: onRetryVerification,
                            ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          // Only button rebuilds when loading changes
          ValueListenableBuilder<bool>(
            valueListenable: loading,
            builder: (_, isLoading, _) => _GoldButton(
              label: 'Continue',
              loading: isLoading,
              onTap: isLoading ? null : onLogin,
            ),
          ),
          const SizedBox(height: 20),
          const _Divider(),
          const SizedBox(height: 20),
          ValueListenableBuilder<bool>(
            valueListenable: loading,
            builder: (_, isLoading, _) => _GoogleButton(
              loading: isLoading,
              onTap: isLoading ? null : onGoogle,
            ),
          ),
        ],
      ),
    );

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_Token.radiusCard),
        child: cheapComposite
            ? formContent
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: formContent,
              ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, AppLocalizations loc) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        loc.noAccount,
        style: const TextStyle(fontSize: 13, color: _Token.silverMuted),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onCreateAccount,
        child: const Text(
          'Create account',
          style: TextStyle(
            fontSize: 13,
            color: _Token.goldBright,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    ],
  );
}

// ── _PremiumField — StatefulWidget, owns focus state ─────
class _PremiumField extends StatefulWidget {
  const _PremiumField({
    required this.controller,
    required this.label,
    required this.icon,
    this.focusNode,
    this.nextFocus,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffixChild,
  });
  final TextEditingController controller;
  final FocusNode? focusNode, nextFocus;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixChild;
  @override
  State<_PremiumField> createState() => _PremiumFieldState();
}

class _PremiumFieldState extends State<_PremiumField> {
  late final FocusNode _focus;
  bool _ownsFocus = false, _hasFocus = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focus = widget.focusNode!;
    } else {
      _focus = FocusNode();
      _ownsFocus = true;
    }
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (_hasFocus != _focus.hasFocus) {
      setState(() => _hasFocus = _focus.hasFocus);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_Token.radiusField),
        color: _hasFocus ? Colors.white : const Color(0xFFF9F9FB),
        border: Border.all(
          color: _hasFocus ? const Color(0x99D4A853) : _Token.silverFaint,
          width: _hasFocus ? 1.5 : 1.0,
        ),
        boxShadow: _hasFocus
            ? const [
                BoxShadow(
                  color: Color(0x33D4A853),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onSubmitted:
            widget.onSubmitted ?? (_) => widget.nextFocus?.requestFocus(),
        style: const TextStyle(
          color: _Token.silver,
          fontSize: 15,
          letterSpacing: 0.2,
        ),
        cursorColor: _Token.goldBright,
        cursorWidth: 1.5,
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
            color: _hasFocus ? _Token.goldBright : _Token.silverMuted,
          ),
          floatingLabelStyle: const TextStyle(
            fontSize: 12,
            color: _Token.goldBright,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              widget.icon,
              size: 18,
              color: _hasFocus ? _Token.goldBright : _Token.silverMuted,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          suffixIcon: widget.suffixChild != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: widget.suffixChild,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}

// ── Misc reusable widgets ─────────────────────────────────
class _GoldButton extends StatefulWidget {
  const _GoldButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  @override
  State<_GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<_GoldButton> {
  bool _p = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _p = true),
    onTapUp: (_) {
      setState(() => _p = false);
      widget.onTap?.call();
    },
    onTapCancel: () => setState(() => _p = false),
    child: AnimatedScale(
      scale: _p ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_Token.radiusButton),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _p
                ? [_Token.goldMid, _Token.goldDim]
                : [_Token.goldBright, _Token.goldMid],
          ),
          boxShadow: _p
              ? []
              : const [
                  BoxShadow(
                    color: Color(0x4DD4A853),
                    blurRadius: 28,
                    offset: Offset(0, 8),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: widget.loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF0D0A00)),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Color(0xFF0D0A00),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Color(0xFF0D0A00),
                  ),
                ],
              ),
      ),
    ),
  );
}

class _GoogleButton extends StatefulWidget {
  const _GoogleButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback? onTap;
  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
  bool _p = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _p = true),
    onTapUp: (_) {
      setState(() => _p = false);
      widget.onTap?.call();
    },
    onTapCancel: () => setState(() => _p = false),
    child: AnimatedScale(
      scale: _p ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_Token.radiusButton),
          color: _p ? const Color(0xFFF9F9FB) : Colors.white,
          border: Border.all(color: _Token.silverFaint),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/google_logo.png', width: 24, height: 24),
            const SizedBox(width: 12),
            const Text(
              'Continue with Google',
              style: TextStyle(
                color: _Token.silver,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: _Token.errorRedSurf,
      border: Border.all(color: const Color(0x4DFF5757)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          size: 18,
          color: _Token.errorRed,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: _Token.errorRed,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _VerificationRecoveryPanel extends StatelessWidget {
  const _VerificationRecoveryPanel({
    required this.loc,
    required this.loading,
    required this.onResend,
    required this.onRetry,
  });

  final AppLocalizations loc;
  final bool loading;
  final VoidCallback onResend;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: const Color(0x14D4A853),
      border: Border.all(color: const Color(0x44D4A853)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.verifyEmailTitle,
          style: const TextStyle(
            color: _Token.goldBright,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          loc.checkInboxPrompt,
          style: const TextStyle(
            color: _Token.silverMuted,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: loading ? null : onResend,
              child: Text(loc.resendVerificationEmail),
            ),
            TextButton(
              onPressed: loading ? null : onRetry,
              child: Text(loc.iVerifiedTryAgain),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Expanded(child: Divider(color: _Token.silverFaint, thickness: 1)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'OR',
          style: TextStyle(
            fontSize: 11,
            color: _Token.silverMuted,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Expanded(child: Divider(color: _Token.silverFaint, thickness: 1)),
    ],
  );
}

class _GoldDot extends StatelessWidget {
  const _GoldDot();
  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    decoration: const BoxDecoration(
      color: _Token.goldBright,
      shape: BoxShape.circle,
    ),
  );
}

class _OrbDef {
  const _OrbDef({
    required this.dx,
    required this.dy,
    required this.size,
    required this.opacity,
  });
  final double dx, dy, size, opacity;
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({
    required this.def,
    required this.screenSize,
    required this.scale,
  });
  final _OrbDef def;
  final Size screenSize;
  final double scale;
  @override
  Widget build(BuildContext context) => Positioned(
    left: screenSize.width * (def.dx + 0.5) - def.size / 2,
    top: screenSize.height * def.dy - def.size / 2,
    child: Transform.scale(
      scale: scale,
      child: Container(
        width: def.size,
        height: def.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              _Token.goldBright.withValues(alpha: def.opacity),
              Colors.transparent,
            ],
          ),
        ),
      ),
    ),
  );
}
