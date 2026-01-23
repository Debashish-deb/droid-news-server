import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/error_handler.dart';
import '../../l10n/app_localizations.dart';

/// Privacy & Data Management Screen
class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({super.key});

  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  bool _isDeleting = false;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacy & Data',
        ), // Title can remain hardcoded or be localized if needed
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Privacy Policy
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: Text(loc.privacyPolicy),
              subtitle: Text(loc.privacyPolicyDesc),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openPrivacyPolicy(),
            ),
          ),
          const SizedBox(height: 8),

          // Terms of Service
          Card(
            child: ListTile(
              leading: const Icon(Icons.description),
              title: Text(loc.termsOfService),
              subtitle: Text(loc.termsOfServiceDesc),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openTermsOfService(),
            ),
          ),
          const SizedBox(height: 24),

          // Data Management Header
          Text(loc.dataManagement, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),

          // Export Data
          Card(
            child: ListTile(
              leading: const Icon(Icons.download),
              title: Text(loc.exportData),
              subtitle: Text(loc.exportDataDesc),
              trailing:
                  _isExporting
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.chevron_right),
              onTap: _isExporting ? null : () => _exportData(),
            ),
          ),
          const SizedBox(height: 8),

          // Delete Account
          Card(
            color: Colors.red[50],
            child: ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red[700]),
              title: Text(
                loc.deleteAccount,
                style: TextStyle(color: Colors.red[700]),
              ),
              subtitle: Text(loc.deleteAccountDesc),
              trailing:
                  _isDeleting
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.chevron_right),
              onTap:
                  _isDeleting || user == null
                      ? null
                      : () => _confirmDeleteAccount(),
            ),
          ),
          const SizedBox(height: 24),

          // Data Collection Info
          Text(loc.whatWeCollect, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            loc.whatWeCollectDetails,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          // Your Rights
          Text(loc.yourRights, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            loc.yourRightsDetails,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    // Hosted on Firebase Hosting
    const url = 'https://droid-e9db9.web.app/privacy.html';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open privacy policy')),
      );
    }
  }

  Future<void> _openTermsOfService() async {
    // Hosted on Firebase Hosting
    const url = 'https://droid-e9db9.web.app/terms.html';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.openUrlError)),
      );
    }
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    final loc = AppLocalizations.of(context)!;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Not signed in');
      }

      // Collect all user data
      final Map<String, dynamic> exportData = {
        'user_profile': {
          'email': user.email,
          'display_name': user.displayName,
          'uid': user.uid,
        },
        'export_date': DateTime.now().toIso8601String(),
      };

      // Get favorites from Firestore
      try {
        final favoritesSnap =
            await FirebaseFirestore.instance
                .collection('favorites')
                .doc(user.uid)
                .collection('articles')
                .get();

        exportData['favorites'] =
            favoritesSnap.docs.map((doc) => doc.data()).toList();
      } catch (e) {
        ErrorHandler.logError(
          e,
          StackTrace.current,
          reason: 'Export favorites failed',
        );
      }

      // Get preferences
      final prefs = await SharedPreferences.getInstance();
      exportData['preferences'] = {
        'theme': prefs.getString('theme_mode'),
        'language': prefs.getString('language'),
        'notifications_enabled': prefs.getBool('notifications_enabled'),
      };

      // Convert to JSON string
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      if (!mounted) return;

      // Show export data in dialog with save option
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(loc.dataExportTitle),
              content: SingleChildScrollView(child: SelectableText(jsonString)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(loc.close),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      // Save to temporary directory
                      final directory = await getTemporaryDirectory();
                      final timestamp = DateTime.now().millisecondsSinceEpoch;
                      final file = File(
                        '${directory.path}/bd_news_data_export_$timestamp.json',
                      );
                      await file.writeAsString(jsonString);

                      Navigator.pop(context);

                      // Share the file
                      await Share.shareXFiles(
                        [XFile(file.path)],
                        subject: 'BD News Reader Data Export',
                        text: 'My exported data from BD News Reader',
                      );

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(loc.dataExportComplete)),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Export failed: ${e.toString()}'),
                        ),
                      );
                    }
                  },
                  child: const Text('Save & Share'),
                ),
              ],
            ),
      );
    } catch (e) {
      ErrorHandler.logError(
        e,
        StackTrace.current,
        reason: 'Data export failed',
      );
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.exportError(e.toString()))));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(loc.deleteAccountConfirmation),
            content: Text(loc.deleteAccountWarning),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(loc.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(loc.deleteEverything),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    setState(() => _isDeleting = true);
    final loc = AppLocalizations.of(context)!;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      // Delete Firestore data
      try {
        // Delete favorites
        final favoritesSnap =
            await FirebaseFirestore.instance
                .collection('favorites')
                .doc(user.uid)
                .collection('articles')
                .get();

        for (final doc in favoritesSnap.docs) {
          await doc.reference.delete();
        }

        // Delete user document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();
      } catch (e) {
        ErrorHandler.logError(
          e,
          StackTrace.current,
          reason: 'Delete Firestore data failed',
        );
      }

      // Clear local data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Delete Firebase Auth account
      await user.delete();

      if (!mounted) return;

      // Navigate to home and show message
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.accountDeleted)));
    } catch (e) {
      ErrorHandler.logError(
        e,
        StackTrace.current,
        reason: 'Account deletion failed',
      );
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.deleteError(e.toString()))));
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }
}
