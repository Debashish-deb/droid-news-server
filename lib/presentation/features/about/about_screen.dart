
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/theme_mode.dart';
import '../../providers/theme_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/utils/number_localization.dart' show localizeNumber;
import '../../../core/design_tokens.dart';
import '../../../core/theme.dart';

import '../../providers/language_providers.dart' show languageCodeProvider;
import '../../widgets/glass_icon_button.dart';
import '../../widgets/app_drawer.dart';
import '../common/app_bar.dart';

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
    final AppLocalizations loc = AppLocalizations.of(context);
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
    final AppLocalizations loc = AppLocalizations.of(context);
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

    final AppLocalizations loc = AppLocalizations.of(context);
    final String langCode = ref.watch(languageCodeProvider);

    final List<Color> bgColors = AppGradients.getBackgroundGradient(mode);
    final Color start = bgColors[0];
    final Color end = bgColors[1];

    final bool isActuallyDark = mode == AppThemeMode.dark || 
                               mode == AppThemeMode.amoled || 
                               mode == AppThemeMode.bangladesh || 
                               (mode == AppThemeMode.system && theme.brightness == Brightness.dark);
    
    final Color textColor = isActuallyDark ? Colors.white : Colors.black87;
    final Color secondaryTextColor = isActuallyDark ? Colors.white70 : Colors.black54;
    final Color tertiaryTextColor = isActuallyDark ? Colors.white38 : Colors.black38;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
        appBar: AppBar(
          centerTitle: true,
          toolbarHeight: 64,
          title: AppBarTitle(loc.aboutUs),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Builder(
            builder: (context) => Center(
              child: GlassIconButton(
                icon: Icons.menu_rounded,
                onPressed: () => Scaffold.of(context).openDrawer(),
                isDark: isActuallyDark,
              ),
            ),
          ),
          leadingWidth: 64,
        ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
           // 1. Gradient Background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      start.withOpacity(0.85),
                      end.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // 2. Dark Overlay

           // 3. Content 
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Column(
                  children: <Widget>[
                    Container(
                      height: 120,
                      width: 120,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ref.watch(navIconColorProvider), width: 4),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: ref.watch(navIconColorProvider).withOpacity(0.3),
                            blurRadius: 20,
                          ),
                        ],
                        image: const DecorationImage(
                          image: AssetImage('assets/app_logo.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Text(
                      'BD News Reader'.toUpperCase(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        letterSpacing: 1,
                        fontFamily: AppTypography.fontFamily,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.appSlogan,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: secondaryTextColor,
                        fontFamily: AppTypography.fontFamily,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                _buildThemeCard(
                  icon: Icons.auto_stories,
                  title: loc.ourStory,
                  content: loc.ourStoryDesc,
                  isDark: isActuallyDark,
                ),
                _buildThemeCard(
                  icon: Icons.track_changes,
                  title: loc.ourVision,
                  content: loc.ourVisionDesc,
                   isDark: isActuallyDark,
                ),
                _buildThemeCard(
                  icon: Icons.mail,
                  title: loc.contactUs,
                  isDark: isActuallyDark,
                  contentWidget: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildContactTile(
                        label: 'customerservice@dsmobiles.com',
                        icon: Icons.email,
                        onTap: _launchEmail,
                        isDark: isActuallyDark,
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
                        isDark: isActuallyDark,
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
                        style: theme.textTheme.bodySmall?.copyWith(
                           color: secondaryTextColor,
                           fontFamily: AppTypography.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '© ${localizeNumber(DateTime.now().year.toString(), langCode)} DreamSD Group',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tertiaryTextColor,
                          fontFamily: AppTypography.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard({
    required IconData icon,
    required String title,
    required bool isDark, String? content,
    Widget? contentWidget,
  }) {
    final glassColor = ref.watch(glassColorProvider);
    final borderColor = ref.watch(borderColorProvider);
    final navIconColor = ref.watch(navIconColorProvider);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: glassColor,
              border: Border.all(color: borderColor),
              boxShadow: <BoxShadow>[
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, color: navIconColor, size: 36),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    fontFamily: AppTypography.fontFamily,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                if (content != null)
                  Text(
                    content,
                    style: TextStyle(
                      height: 1.5,
                      fontFamily: '.SF Pro Text',
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                if (contentWidget != null) contentWidget,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactTile({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required bool isDark,
  }) {
    final navIconColor = ref.watch(navIconColorProvider);
    final borderColor = ref.watch(borderColorProvider);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: navIconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: '.SF Pro Text',
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.copy_all_rounded, size: 20, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
