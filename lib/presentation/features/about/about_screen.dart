import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/performance_config.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/number_localization.dart' show localizeNumber;
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/language_providers.dart' show languageCodeProvider;
import '../../providers/theme_providers.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/premium_scaffold.dart' show PremiumScaffold;
import '../../widgets/premium_screen_header.dart';

extension _CtxColors on BuildContext {
  AppColorsExtension get colors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key, this.drawer, this.packageInfoLoader});

  final Widget? drawer;
  final Future<PackageInfo> Function()? packageInfoLoader;

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final loader = widget.packageInfoLoader ?? PackageInfo.fromPlatform;
      final info = await loader();
      if (!mounted) return;
      setState(() {
        _appVersion = '${info.version} (${info.buildNumber})';
      });
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        error,
        stackTrace,
        reason: 'AboutScreen package info load failed',
      );
    }
  }

  Future<void> _launchUri(
    BuildContext context,
    Uri uri, {
    LaunchMode mode = LaunchMode.platformDefault,
    String? errorMessage,
  }) async {
    final loc = AppLocalizations.of(context);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: mode);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(errorMessage ?? loc.openUrlError)));
  }

  Future<void> _launchEmail() async {
    final loc = AppLocalizations.of(context);
    final emailUri = Uri(
      scheme: 'mailto',
      path: 'support@appcraftr.store',
      queryParameters: <String, dynamic>{'subject': loc.helpInquiry},
    );
    await _launchUri(context, emailUri);
  }

  Future<void> _launchWebsite() async {
    await _launchUri(
      context,
      Uri.parse('https://www.appcraftr.store'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _launchRateUs() async {
    final loc = AppLocalizations.of(context);
    await _launchUri(
      context,
      Uri.parse(
        'https://play.google.com/store/apps/details?id=com.bd.bdnewsreader',
      ),
      mode: LaunchMode.externalApplication,
      errorMessage: loc.storeOpenError,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final langCode = ref.watch(languageCodeProvider);
    final perf = PerformanceConfig.of(context);
    final lowEffects =
        perf.reduceEffects || perf.lowPowerMode || perf.isLowEndDevice;
    final accent = ref.watch(navIconColorProvider);

    return PremiumScaffold(
      useBackground: false,
      showBackgroundParticles: false,
      drawer: widget.drawer ?? const AppDrawer(),
      title: loc.aboutUs,
      subtitle: loc.appSlogan,
      headerLeading: PremiumHeaderLeading.menu,
      headerHeight: 112,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            _FrostedCard(
              lowEffects: lowEffects,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _AboutHero(
                  accent: accent,
                  title: 'BD News Reader',
                  slogan: loc.appSlogan,
                  appVersion: _appVersion,
                  langCode: langCode,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _FrostedCard(
              lowEffects: lowEffects,
              child: Column(
                children: [
                  _AboutSection(
                    icon: Icons.auto_stories_rounded,
                    title: loc.ourStory,
                    body: loc.ourStoryDesc,
                    accent: accent,
                  ),
                  Divider(
                    height: 1,
                    color: context.colors.cardBorder.withValues(alpha: 0.4),
                    indent: 54,
                  ),
                  _AboutSection(
                    icon: Icons.track_changes_rounded,
                    title: loc.ourVision,
                    body: loc.ourVisionDesc,
                    accent: accent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _FrostedCard(
              lowEffects: lowEffects,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.contactUs,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.privacyPolicyDesc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _AboutIconButton(
                            icon: Icons.email_outlined,
                            semanticLabel: loc.contactSupport,
                            onTap: _launchEmail,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AboutIconButton(
                            icon: Icons.language_rounded,
                            semanticLabel: loc.visitWebsite,
                            onTap: _launchWebsite,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AboutIconButton(
                            icon: Icons.star_rate_rounded,
                            semanticLabel: loc.rateApp,
                            onTap: _launchRateUs,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '© ${localizeNumber(DateTime.now().year.toString(), langCode)} AppCraftr',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.colors.textHint.withValues(alpha: 0.82),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero({
    required this.accent,
    required this.title,
    required this.slogan,
    required this.appVersion,
    required this.langCode,
  });

  final Color accent;
  final String title;
  final String slogan;
  final String appVersion;
  final String langCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageBorder = Border.all(color: accent, width: 2.2);
    final imageShadow = [
      BoxShadow(
        color: accent.withValues(alpha: 0.24),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: imageBorder,
                boxShadow: imageShadow,
                color: context.colors.surface,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/play_store_512-app.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    ErrorHandler.logError(
                      error,
                      stackTrace,
                      reason: 'AboutScreen hero image load failed',
                    );
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        Icons.newspaper_rounded,
                        color: accent,
                        size: 28,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                      letterSpacing: -0.35,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slogan,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (appVersion.isNotEmpty)
              _MetaBadge(
                icon: Icons.verified_outlined,
                label: 'v${localizeNumber(appVersion, langCode)}',
              ),
            _MetaBadge(
              icon: Icons.public_rounded,
              label: localizeNumber(DateTime.now().year.toString(), langCode),
            ),
            const _MetaBadge(icon: Icons.business_rounded, label: 'AppCraftr'),
          ],
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13.3,
                    color: context.colors.textSecondary,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutIconButton extends StatelessWidget {
  const _AboutIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: semanticLabel,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Material(
          color: context.colors.card.withValues(alpha: 0.64),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.colors.cardBorder.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(icon, size: 22, color: context.colors.proBlue),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: context.colors.card.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: context.colors.cardBorder.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.colors.proBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FrostedCard extends StatelessWidget {
  const _FrostedCard({required this.lowEffects, required this.child});

  final bool lowEffects;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(
          alpha: lowEffects ? 0.95 : 0.82,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: context.colors.cardBorder.withValues(alpha: 0.5),
        ),
        boxShadow: lowEffects
            ? const <BoxShadow>[]
            : [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );

    if (lowEffects) return card;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: card,
      ),
    );
  }
}
