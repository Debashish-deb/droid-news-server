import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../observability/analytics_service.dart';
import '../../l10n/generated/app_localizations.dart';

/// Social media sharing service
class ShareService {
  static Future<void> shareArticle({
    required String title,
    required String url,
    String? description,
    String? imageUrl,
    BuildContext? context,
  }) async {
    final shareText = _buildShareText(title, description, url);

    try {
      await Share.share(shareText, subject: title);

      await AnalyticsService.logEvent(
        name: 'article_shared',
        parameters: {'url': url, 'method': 'generic_share'},
      );
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  /// Share to specific platform
  static Future<void> shareToWhatsApp({
    required String title,
    required String url,
    String? description,
  }) async {
    final text = _buildShareText(title, description, url);
    final whatsappUrl = 'whatsapp://send?text=${Uri.encodeComponent(text)}';

    await _launchUrl(whatsappUrl, 'WhatsApp');
  }

  static Future<void> shareToTwitter({
    required String title,
    required String url,
  }) async {
    final text = Uri.encodeComponent(title);
    final twitterUrl =
        'https://twitter.com/intent/tweet?text=$text&url=${Uri.encodeComponent(url)}';

    await _launchUrl(twitterUrl, 'Twitter');
  }

  static Future<void> shareToFacebook({required String url}) async {
    final facebookUrl =
        'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}';

    await _launchUrl(facebookUrl, 'Facebook');
  }

  static Future<void> shareToTelegram({
    required String title,
    required String url,
  }) async {
    final text = Uri.encodeComponent(title);
    final telegramUrl =
        'https://t.me/share/url?url=${Uri.encodeComponent(url)}&text=$text';

    await _launchUrl(telegramUrl, 'Telegram');
  }

  /// Copy link to clipboard
  static Future<void> copyLink({
    required String url,
    BuildContext? context,
  }) async {
    await Clipboard.setData(ClipboardData(text: url));


    await AnalyticsService.logEvent(
      name: 'link_copied',
      parameters: {'url': url},
    );

    if (context != null && context.mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.linkCopied),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Show share sheet with all options
  static Future<void> showShareSheet({
    required BuildContext context,
    required String title,
    required String url,
    String? description,
    String? imageUrl,
  }) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => _ShareSheet(
            title: title,
            url: url,
            description: description,
            imageUrl: imageUrl,
          ),
    );
  }



  static String _buildShareText(String title, String? description, String url) {
    final buffer = StringBuffer();
    buffer.write(title);

    if (description != null && description.isNotEmpty) {
      buffer.write('\n\n');
      buffer.write(description);
    }

    buffer.write('\n\n');
    buffer.write(url);
    buffer.write('\n\n📱 Shared via BD News Reader');

    return buffer.toString();
  }

  static Future<void> _launchUrl(String url, String platform) async {
    try {

      await Share.share(url);

      await AnalyticsService.logEvent(
        name: 'shared_to_platform',
        parameters: {'platform': platform},
      );
    } catch (e) {
      debugPrint('Error launching $platform: $e');
    }
  }

}

/// Share sheet bottom modal
class _ShareSheet extends StatelessWidget {
  const _ShareSheet({
    required this.title,
    required this.url,
    this.description,
    this.imageUrl,
  });
  final String title;
  final String url;
  final String? description;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

   
          Text(
            AppLocalizations.of(context).share,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

    
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _ShareOption(
                icon: Icons.share,
                label: AppLocalizations.of(context).more,
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  ShareService.shareArticle(
                    title: title,
                    url: url,
                    description: description,
                    context: context,
                  );
                },
              ),
              _ShareOption(
                icon: Icons.link,
                label: AppLocalizations.of(context).copy,
                color: Colors.grey,
                onTap: () {
                  Navigator.pop(context);
                  ShareService.copyLink(url: url, context: context);
                },
              ),
              _ShareOption(
                icon: Icons.chat,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () {
                  Navigator.pop(context);
                  ShareService.shareToWhatsApp(
                    title: title,
                    url: url,
                    description: description,
                  );
                },
              ),
              _ShareOption(
                icon: Icons.message,
                label: 'Telegram',
                color: const Color(0xFF0088cc),
                onTap: () {
                  Navigator.pop(context);
                  ShareService.shareToTelegram(title: title, url: url);
                },
              ),
              _ShareOption(
                icon: Icons.facebook,
                label: 'Facebook',
                color: const Color(0xFF1877F2),
                onTap: () {
                  Navigator.pop(context);
                  ShareService.shareToFacebook(url: url);
                },
              ),
              _ShareOption(
                icon: Icons.sports_basketball,
                label: 'Twitter',
                color: Colors.black,
                onTap: () {
                  Navigator.pop(context);
                  ShareService.shareToTwitter(title: title, url: url);
                },
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Individual share option button
class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
