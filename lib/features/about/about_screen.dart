import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme_provider.dart';
import '../../presentation/providers/theme_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/providers/language_providers.dart';
import '../../core/utils/number_localization.dart';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

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
    final PackageInfo info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${info.version} (Build ${info.buildNumber})';
    });
  }

  Future<void> _launchEmail() async {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'customerservice@dsmobiles.com',
      queryParameters: <String, dynamic>{'subject': loc.helpInquiry},
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.emailError)));
    }
  }

  Future<void> _launchWebsite() async {
    final Uri uri = Uri.parse('https://www.dsmobiles.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(String text, String label) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.copiedToClipboard(label)),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppThemeMode mode = ref.watch(currentThemeModeProvider);

    late Color startColor;
    late Color endColor;
    switch (mode) {
      case AppThemeMode.bangladesh:
        startColor = const Color(0xFF00796B);
        endColor = const Color(0xFF004D40);
        break;
      case AppThemeMode.dark:
        startColor = const Color(0xFF2A2D30);
        endColor = const Color(0xFF1E2124);
        break;
      case AppThemeMode.light:
      default:
        startColor = const Color(0xFF42A5F5);
        endColor = const Color(0xFF1565C0);
        break;
    }

    final AppLocalizations loc = AppLocalizations.of(context)!;
    final String langCode = ref.watch(languageCodeProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(loc.aboutUs),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: const SizedBox.expand(),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  startColor.withOpacity(0.85),
                  endColor.withOpacity(0.85),
                ],
              ),
            ),
          ),
          ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + kToolbarHeight + 24,
              20,
              20,
            ),
            children: <Widget>[
              Column(
                children: <Widget>[
                  Container(
                    height: 100,
                    width: 100,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.primary, width: 2),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.2),
                          blurRadius: 10,
                        ),
                      ],
                      image: const DecorationImage(
                        image: AssetImage('assets/logo.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Text(
                    'BD News Reader',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    loc.appSlogan,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              _buildThemeCard(
                icon: Icons.auto_stories,
                title: loc.ourStory,
                content: loc.ourStoryDesc,
              ),
              _buildThemeCard(
                icon: Icons.track_changes,
                title: loc.ourVision,
                content: loc.ourVisionDesc,
              ),
              _buildThemeCard(
                icon: Icons.mail,
                title: loc.contactUs,
                contentWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildContactTile(
                      label: 'customerservice@dsmobiles.com',
                      icon: Icons.email,
                      onTap: _launchEmail,
                      onLongPress:
                          () => _copyToClipboard(
                            'customerservice@dsmobiles.com',
                            'Email',
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildContactTile(
                      label: 'www.dsmobiles.com',
                      icon: Icons.language,
                      onTap: _launchWebsite,
                      onLongPress:
                          () => _copyToClipboard(
                            'https://www.dsmobiles.com',
                            'Website',
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: <Widget>[
                    Text(
                      '${loc.versionPrefix} ${localizeNumber(_appVersion, langCode)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '© ${localizeNumber(DateTime.now().year.toString(), langCode)} DreamSD Group',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard({
    required IconData icon,
    required String title,
    String? content,
    Widget? contentWidget,
  }) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.cardColor,
        boxShadow: <BoxShadow>[
          BoxShadow(color: theme.shadowColor.withOpacity(0.05), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: theme.colorScheme.primary, size: 32),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (content != null)
            Text(
              content,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              textAlign: TextAlign.justify,
            ),
          if (contentWidget != null) contentWidget,
        ],
      ),
    );
  }

  Widget _buildContactTile({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.copy, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
