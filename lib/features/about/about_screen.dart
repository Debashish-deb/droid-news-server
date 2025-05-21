import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme_provider.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
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
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'customerservice@dsmobiles.com',
      queryParameters: {'subject': 'BD News Reader App Inquiry'},
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app.')),
      );
    }
  }

  Future<void> _launchWebsite() async {
    final Uri uri = Uri.parse('https://www.dsmobiles.com');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mode = context.watch<ThemeProvider>().appThemeMode;

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

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('About Us'),
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
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  startColor.withOpacity(0.85),
                  endColor.withOpacity(0.85),
                ],
              ),
            ),
          ),
          ListView(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + kToolbarHeight + 24, 20, 20),
            children: [
              Column(
                children: [
                  Container(
                    height: 100,
                    width: 100,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.primary, width: 2),
                      boxShadow: [
                        BoxShadow(color: colorScheme.primary.withOpacity(0.2), blurRadius: 10)
                      ],
                      image: const DecorationImage(
                        image: AssetImage('assets/logo.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Text('BDNewsHub',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    'Real-time News at Your Fingertips',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              _buildThemeCard(
                icon: Icons.auto_stories,
                title: 'Our Story',
                content:
                    'BD News Reader is the first mobile app by DSMobiles Group, delivering fast and reliable news updates. Our mission is to create free, high-quality apps that inform and empower.',
              ),
              _buildThemeCard(
                icon: Icons.track_changes,
                title: 'Our Vision',
                content:
                    'We envision a world where information is free and universal. Through user-first design and innovative tools, we aim to create digital experiences that inspire.',
              ),
              _buildThemeCard(
                icon: Icons.mail,
                title: 'Contact Us',
                contentWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContactTile(
                      label: 'customerservice@dsmobiles.com',
                      icon: Icons.email,
                      onTap: _launchEmail,
                      onLongPress: () => _copyToClipboard('customerservice@dsmobiles.com', 'Email'),
                    ),
                    const SizedBox(height: 12),
                    _buildContactTile(
                      label: 'www.dsmobiles.com',
                      icon: Icons.language,
                      onTap: _launchWebsite,
                      onLongPress: () => _copyToClipboard('https://www.dsmobiles.com', 'Website'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Text('Version $_appVersion', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      '© ${DateTime.now().year} DreamSD Group',
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
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.cardColor,
        boxShadow: [BoxShadow(color: theme.shadowColor.withOpacity(0.05), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 32),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
    final theme = Theme.of(context);
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
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.copy, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
