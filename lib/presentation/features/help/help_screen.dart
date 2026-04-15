import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/performance_config.dart';
import '../../../core/theme/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/premium_screen_header.dart';
import '../../widgets/premium_shell_palette.dart' show PremiumShellPalette;

extension _CtxColors on BuildContext {
  AppColorsExtension get colors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  Future<void> _launchEmail(BuildContext context, String subject) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@appcraftr.store',
      queryParameters: <String, dynamic>{'subject': subject},
    );
    await _launchUri(context, uri);
  }

  Future<void> _launchWebsite(BuildContext context) async {
    await _launchUri(
      context,
      Uri.parse('https://www.appcraftr.store'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _launchRateUs(BuildContext context) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final perf = PerformanceConfig.of(context);
    final lowEffects =
        perf.reduceEffects || perf.lowPowerMode || perf.isLowEndDevice;

    final palette = Theme.of(context).extension<PremiumShellPalette>()!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      appBar: PremiumScreenHeader(
        title: loc.helpSupport,
        leading: PremiumHeaderLeading.menu,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              palette.gradientStart.withValues(alpha: 0.9),
              palette.footerGradient.colors[2].withValues(alpha: 0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              _FrostedCard(
                lowEffects: lowEffects,
                child: Column(
                  children: [
                    _HelpTile(
                      icon: Icons.question_answer_rounded,
                      title: loc.faqHowToUse,
                      subtitle: loc.faqHowToUseDesc,
                    ),
                    Divider(
                      height: 1,
                      color: context.colors.cardBorder.withValues(alpha: 0.4),
                    ),
                    _HelpTile(
                      icon: Icons.menu_book_rounded,
                      title: loc.helpReaderToolsTitle,
                      subtitle: loc.helpReaderToolsDesc,
                    ),
                    Divider(
                      height: 1,
                      color: context.colors.cardBorder.withValues(alpha: 0.4),
                    ),
                    _HelpTile(
                      icon: Icons.offline_pin_rounded,
                      title: loc.helpOfflineServiceTitle,
                      subtitle: loc.helpOfflineServiceDesc,
                    ),
                    Divider(
                      height: 1,
                      color: context.colors.cardBorder.withValues(alpha: 0.4),
                    ),
                    _HelpTile(
                      icon: Icons.tune_rounded,
                      title: loc.helpSourceManagementTitle,
                      subtitle: loc.helpSourceManagementDesc,
                    ),
                    Divider(
                      height: 1,
                      color: context.colors.cardBorder.withValues(alpha: 0.4),
                    ),
                    _HelpTile(
                      icon: Icons.lock_rounded,
                      title: loc.faqDataSecure,
                      subtitle: loc.faqDataSecureDesc,
                    ),
                    Divider(
                      height: 1,
                      color: context.colors.cardBorder.withValues(alpha: 0.4),
                    ),
                    _HelpTile(
                      icon: Icons.update_rounded,
                      title: loc.faqUpdates,
                      subtitle: loc.faqUpdatesDesc,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _FrostedCard(
                lowEffects: lowEffects,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SupportIconButton(
                          icon: Icons.email_outlined,
                          semanticLabel: loc.contactSupport,
                          onTap: () => _launchEmail(context, loc.helpInquiry),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SupportIconButton(
                          icon: Icons.language_rounded,
                          semanticLabel: loc.visitWebsite,
                          onTap: () => _launchWebsite(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SupportIconButton(
                          icon: Icons.star_rate_rounded,
                          semanticLabel: loc.rateApp,
                          onTap: () => _launchRateUs(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.colors.proBlue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: context.colors.proBlue, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.8,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
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
    );
  }
}

class _SupportIconButton extends StatelessWidget {
  const _SupportIconButton({
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
                  color: Colors.black.withValues(alpha: 0.08),
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
