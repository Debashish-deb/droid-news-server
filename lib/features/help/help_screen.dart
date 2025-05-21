import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'customerservice@dsmobiles.com',
      queryParameters: {'subject': 'Help & Support Inquiry'},
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
    final Uri rateUri = Uri.parse('https://play.google.com/store/apps/details?id=com.example.app');
    if (await canLaunchUrl(rateUri)) {
      await launchUrl(rateUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: Icon(Icons.question_answer),
            title: Text('How to use BD News Reader?'),
            subtitle: Text('Navigate news categories from the homepage.'),
          ),
          const ListTile(
            leading: Icon(Icons.lock),
            title: Text('Is my data secure?'),
            subtitle: Text('Yes, we respect your privacy and do not store personal data.'),
          ),
          const ListTile(
            leading: Icon(Icons.update),
            title: Text('How to get latest updates?'),
            subtitle: Text('Updates are pushed automatically via Play Store.'),
          ),
          const Divider(height: 32),
          ElevatedButton.icon(
            onPressed: _launchEmail,
            icon: const Icon(Icons.email_outlined),
            label: const Text('Email Support'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _launchWebsite,
            icon: const Icon(Icons.language),
            label: const Text('Visit Website'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _launchRateUs,
            icon: const Icon(Icons.star_rate_outlined),
            label: const Text('Rate Us'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ],
      ),
    );
  }
}