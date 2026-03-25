import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          loc.privacyPolicy,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact Intro Card
              _CompactIntro(text: loc.privacyPolicyIntro, scheme: scheme),
              const SizedBox(height: 20),
              
              // Section Title
              Text(
                'Key Points',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              
              // Compact Policy Sections using ExpansionTiles
              _CompactPolicyTile(
                title: loc.privacyCollectionTitle,
                content: loc.privacyCollectionDesc,
                icon: Icons.analytics_outlined,
                scheme: scheme,
              ),
              _CompactPolicyTile(
                title: loc.privacyUsageTitle,
                content: loc.privacyUsageDesc,
                icon: Icons.touch_app_outlined,
                scheme: scheme,
              ),
              _CompactPolicyTile(
                title: loc.privacyThirdPartyTitle,
                content: loc.privacyThirdPartyDesc,
                icon: Icons.share_outlined,
                scheme: scheme,
              ),
              _CompactPolicyTile(
                title: loc.privacySecurityTitle,
                content: loc.privacySecurityDesc,
                icon: Icons.security_outlined,
                scheme: scheme,
              ),
              _CompactPolicyTile(
                title: loc.privacyRightsTitle,
                content: loc.privacyRightsDesc,
                icon: Icons.verified_user_outlined,
                scheme: scheme,
              ),
              _CompactPolicyTile(
                title: loc.privacyContactTitle,
                content: loc.privacyContactDesc,
                icon: Icons.mail_outline_rounded,
                scheme: scheme,
                isLast: true,
              ),
              
              const SizedBox(height: 24),
              
              // Contact Action Button (Thumb friendly)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    // Launch email or contact
                  },
                  icon: const Icon(Icons.email_rounded, size: 18),
                  label: const Text('Contact Us'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Footer
              Center(
                child: Text(
                  loc.privacyLastUpdated,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactIntro extends StatelessWidget {
  final String text;
  final ColorScheme scheme;

  const _CompactIntro({required this.text, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withOpacity(0.4),
            scheme.primaryContainer.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.primary.withOpacity(0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: scheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: scheme.onPrimaryContainer.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactPolicyTile extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final ColorScheme scheme;
  final bool isLast;

  const _CompactPolicyTile({
    required this.title,
    required this.content,
    required this.icon,
    required this.scheme,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12, left: 32),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: scheme.secondary),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        trailing: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: scheme.onSurfaceVariant,
        ),
        children: [
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}