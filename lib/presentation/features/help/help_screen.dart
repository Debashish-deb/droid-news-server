import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' show ImageFilter;
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/enums/theme_mode.dart';
import '../../providers/theme_providers.dart';
import '../../../core/design_tokens.dart';
import '../../../core/theme.dart';
import '../settings/widgets/settings_3d_widgets.dart';
import '../../widgets/glass_icon_button.dart';

import '../common/app_bar.dart';
import '../../widgets/app_drawer.dart';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  Future<void> _launchEmail(String subject) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'customerservice@dsmobiles.com',
      queryParameters: <String, dynamic>{'subject': subject},
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _launchWebsite() async {
    final Uri websiteUri = Uri.parse('https://www.dsmobiles.com');
    if (await canLaunchUrl(websiteUri)) {
      await launchUrl(websiteUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchRateUs() async {
    final Uri rateUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.example.app',
    );
    if (await canLaunchUrl(rateUri)) {
      await launchUrl(rateUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations loc = AppLocalizations.of(context);
    final AppThemeMode mode = ref.watch(currentThemeModeProvider);
    final bool isDark = mode == AppThemeMode.dark;
    
    // Gradient Logic
    final List<Color> bgColors = AppGradients.getBackgroundGradient(mode);
    final Color start = bgColors[0];
    final Color end = bgColors[1];

    final glassColor = ref.watch(glassColorProvider);
    final borderColor = ref.watch(borderColorProvider);
    final navIconColor = ref.watch(navIconColorProvider);

    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white60 : Colors.black54;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 64,
        title: AppBarTitle(loc.helpSupport),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => Center(
            child: GlassIconButton(
              icon: Icons.menu_rounded,
              onPressed: () => Scaffold.of(context).openDrawer(),
              isDark: isDark,
            ),
          ),
        ),
        leadingWidth: 64,
      ),
      body: Stack(
         fit: StackFit.expand,
         children: [
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
            // 2. Content
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  // FAQ Section in Glass Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: glassColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            _HelpTile(
                              icon: Icons.question_answer, 
                              title: loc.faqHowToUse, 
                              subtitle: loc.faqHowToUseDesc,
                              textColor: textColor,
                              subTextColor: subTextColor,
                              iconColor: navIconColor,
                            ),
                            Divider(height: 1, color: borderColor),
                             _HelpTile(
                              icon: Icons.lock_rounded, 
                              title: loc.faqDataSecure, 
                              subtitle: loc.faqDataSecureDesc,
                               textColor: textColor,
                              subTextColor: subTextColor,
                               iconColor: navIconColor,
                            ),
                            Divider(height: 1, color: borderColor),
                             _HelpTile(
                              icon: Icons.update_rounded, 
                              title: loc.faqUpdates, 
                              subtitle: loc.faqUpdatesDesc,
                               textColor: textColor,
                              subTextColor: subTextColor,
                               iconColor: navIconColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  Settings3DButton(
                    onTap: () => _launchEmail(loc.helpInquiry),
                    label: loc.contactSupport,
                    icon: Icons.email_outlined,
                    width: double.infinity,
                    fontSize: 14,
                  ),
                  const SizedBox(height: 16),
                  Settings3DButton(
                    onTap: _launchWebsite,
                    label: loc.visitWebsite,
                    icon: Icons.language,
                    width: double.infinity,
                    fontSize: 14,
                  ),
                  const SizedBox(height: 16),
                  Settings3DButton(
                    onTap: _launchRateUs,
                    label: loc.rateApp,
                    icon: Icons.star_rate_rounded,
                    width: double.infinity,
                    fontSize: 14,
                  ),
                ],
              ),
            ),
         ],
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {

  const _HelpTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.textColor,
    required this.subTextColor,
    required this.iconColor,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color textColor;
  final Color subTextColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    fontFamily: AppTypography.fontFamily,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: subTextColor,
                    height: 1.4,
                    fontFamily: AppTypography.fontFamily,
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

