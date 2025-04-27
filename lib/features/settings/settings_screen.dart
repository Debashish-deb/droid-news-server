// path: features/settings/settings_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme_provider.dart';
import '../../core/language_provider.dart';
import '../../localization/l10n/app_localizations.dart';
import '../news/widgets/animated_background.dart';
import '../../widgets/app_drawer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _version = info.version);
  }

  Future<void> _rateApp() async {
    final uri = Uri.parse('https://play.google.com/store/apps/details?id=com.example.droid');
    if (!await launchUrl(uri)) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.storeOpenError)),
      );
    }
  }

  Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);
    await DefaultCacheManager().emptyCache();
    setState(() => _isClearingCache = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final loc = AppLocalizations.of(context)!;
    final selectedTheme = themeProvider.appThemeMode;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        centerTitle: true,
        title: Text(loc.settings, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: AnimatedBackground(
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.cardColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ListView(
                  children: [
                    _buildSectionTitle(context, loc.theme),
                    _buildThemeSelector(themeProvider, selectedTheme),
                    const SizedBox(height: 24),
                    _buildSectionTitle(context, loc.language),
                    _buildLanguageSelector(),
                    const SizedBox(height: 24),
                    _buildSettingsOption(
                      icon: Icons.cleaning_services,
                      title: 'Clear Cache',
                      onTap: _isClearingCache ? null : _clearCache,
                      trailing: _isClearingCache ? const CircularProgressIndicator() : const Icon(Icons.chevron_right),
                    ),
                    _buildSettingsOption(
                      icon: Icons.star_rate,
                      title: loc.rateApp,
                      onTap: _rateApp,
                    ),
                    _buildSettingsOption(
                      icon: Icons.support_agent,
                      title: loc.contactSupport,
                      subtitle: loc.contactEmail,
                      onTap: _contactSupport,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        '${loc.versionPrefix} $_version',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildThemeSelector(ThemeProvider provider, AppThemeMode selected) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          RadioListTile<AppThemeMode>(
            title: const Text('Light'),
            value: AppThemeMode.light,
            groupValue: selected,
            onChanged: (v) => provider.toggleTheme(v!),
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('Dark'),
            value: AppThemeMode.dark,
            groupValue: selected,
            onChanged: (v) => provider.toggleTheme(v!),
          ),
          RadioListTile<AppThemeMode>(
            title: const Text('Desh 🇧🇩'),
            value: AppThemeMode.bangladesh,
            groupValue: selected,
            onChanged: (v) => provider.toggleTheme(v!),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        height: 56,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Consumer<LanguageProvider>(
          builder: (context, languageProvider, _) {
            return DropdownButton<String>(
              value: languageProvider.locale.languageCode,
              underline: const SizedBox(),
              onChanged: (lang) => languageProvider.setLocale(lang!),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      onTap: onTap,
      trailing: trailing ?? const Icon(Icons.chevron_right),
    );
  }

  Future<void> _contactSupport() async {
    final loc = AppLocalizations.of(context)!;
    final uri = Uri.parse('mailto:${loc.contactEmail}');
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.mailClientError)),
      );
    }
  }
}
