import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart' show Share;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/theme_mode.dart';
import '../../providers/theme_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/utils/number_localization.dart' show localizeNumber;
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/theme.dart';

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
      _appVersion = '${info.version} (${info.buildNumber})';
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.emailError)));
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
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 280,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppThemeMode mode = ref.watch(currentThemeModeProvider);
    final AppLocalizations loc = AppLocalizations.of(context);
    final String langCode = ref.watch(languageCodeProvider);

    final List<Color> bgColors = AppGradients.getBackgroundGradient(mode);
    final bool isActuallyDark = mode == AppThemeMode.dark ||
        mode == AppThemeMode.amoled ||
        mode == AppThemeMode.bangladesh ||
        (mode == AppThemeMode.system && theme.brightness == Brightness.dark);

    final Color textColor = isActuallyDark ? Colors.white : Colors.black87;
    final Color secondaryTextColor = isActuallyDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 56,
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
        leadingWidth: 56,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgColors[0].withOpacity(0.9), bgColors[1].withOpacity(0.9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Compact Header Section
                _buildCompactHeader(theme, textColor, secondaryTextColor, loc),
                
                const SizedBox(height: 12),
                
                // Main Content Card - Scrollable if needed but compact
                Expanded(
                  flex: 3,
                  child: _buildMainContentCard(isActuallyDark, loc, theme),
                ),
                
                const SizedBox(height: 12),
                
                // Bottom Action Bar - Thumb friendly
                _buildActionBar(isActuallyDark),
                
                // Compact Footer
                _buildFooter(theme, secondaryTextColor, langCode, loc),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader(ThemeData theme, Color textColor, Color secondaryTextColor, AppLocalizations loc) {
    return Row(
      children: [
        // Compact Icon
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ref.watch(navIconColorProvider), width: 2),
            boxShadow: [
              BoxShadow(
                color: ref.watch(navIconColorProvider).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            image: const DecorationImage(
              image: AssetImage('assets/play_store_512-app.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Title & Slogan Column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BD News Reader',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: textColor,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                loc.appSlogan,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainContentCard(bool isDark, AppLocalizations loc, ThemeData theme) {
    final glassColor = ref.watch(glassColorProvider);
    final borderColor = ref.watch(borderColorProvider);
    final navIconColor = ref.watch(navIconColorProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor.withOpacity(0.5)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Story & Vision in compact expandable tiles
                  _buildCompactTile(
                    icon: Icons.auto_stories_rounded,
                    title: loc.ourStory,
                    content: loc.ourStoryDesc,
                    iconColor: navIconColor,
                    textColor: isDark ? Colors.white : Colors.black87,
                  ),
                  const Divider(height: 1, indent: 40),
                  _buildCompactTile(
                    icon: Icons.track_changes_rounded,
                    title: loc.ourVision,
                    content: loc.ourVisionDesc,
                    iconColor: navIconColor,
                    textColor: isDark ? Colors.white : Colors.black87,
                  ),
                  const Divider(height: 1, indent: 40),
                  // Contact Section - Horizontal chips
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.contact_mail_rounded, size: 20, color: navIconColor),
                      const SizedBox(width: 12),
                      Text(
                        loc.contactUs,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildContactChip(
                          icon: Icons.email_rounded,
                          label: 'Email',
                          onTap: _launchEmail,
                          onLongPress: () => _copyToClipboard('customerservice@dsmobiles.com', 'Email'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildContactChip(
                          icon: Icons.language_rounded,
                          label: 'Website',
                          onTap: _launchWebsite,
                          onLongPress: () => _copyToClipboard('https://www.dsmobiles.com', 'Website'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTile({
    required IconData icon,
    required String title,
    required String content,
    required Color iconColor,
    required Color textColor,
  }) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12, left: 32),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      children: [
        Text(
          content,
          style: TextStyle(
            height: 1.4,
            fontSize: 13,
            color: textColor.withOpacity(0.8),
          ),
          textAlign: TextAlign.left,
        ),
      ],
    );
  }

  Widget _buildContactChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    final borderColor = ref.watch(borderColorProvider);
    
    return Material(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44, // Minimum touch target
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildIconButton(
          icon: Icons.share_rounded,
          label: 'Share',
          onTap: () {
            // Share app logic
            Share.share('Check out BD News Reader!');
          },
        ),
        const SizedBox(width: 16),
        _buildIconButton(
          icon: Icons.star_rounded,
          label: 'Rate',
          onTap: () {
            // Rate app logic
          },
        ),
        const SizedBox(width: 16),
        _buildIconButton(
          icon: Icons.privacy_tip_rounded,
          label: 'Privacy',
          onTap: () {
            // Privacy policy
          },
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final navIconColor = ref.watch(navIconColorProvider);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: navIconColor, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, Color textColor, String langCode, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'v${localizeNumber(_appVersion, langCode)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
          ),
          Text(
            '© ${localizeNumber(DateTime.now().year.toString(), langCode)} DreamSD',
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}