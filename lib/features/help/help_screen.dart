import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '/l10n/app_localizations.dart';

class HelpScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.helpSupport), // Localized Title
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.question_answer),
            title: Text(loc.faqHowToUse),
            subtitle: Text(loc.faqHowToUseDesc),
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text(loc.faqDataSecure),
            subtitle: Text(loc.faqDataSecureDesc),
          ),
          ListTile(
            leading: const Icon(Icons.update),
            title: Text(loc.faqUpdates),
            subtitle: Text(loc.faqUpdatesDesc),
          ),
          const Divider(height: 32),
          ElevatedButton.icon(
            onPressed:
                () => _launchEmail(loc.helpInquiry), // Pass localized subject
            icon: const Icon(Icons.email_outlined),
            label: Text(loc.contactSupport),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _launchWebsite,
            icon: const Icon(Icons.language),
            label: Text(loc.visitWebsite),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _launchRateUs,
            icon: const Icon(Icons.star_rate_outlined),
            label: Text(loc.rateApp),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }
}
