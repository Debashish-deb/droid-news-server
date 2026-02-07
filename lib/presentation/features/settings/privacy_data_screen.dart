import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/error_handler.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/theme_providers.dart' show navIconColorProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Premium Privacy & Data Management Screen
import '../common/app_bar.dart';

class PrivacyDataScreen extends ConsumerStatefulWidget {
  const PrivacyDataScreen({super.key});

  @override
  ConsumerState<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends ConsumerState<PrivacyDataScreen> {
  bool _isDeleting = false;
  bool _isExporting = false;
  late Future<List<Map<String, dynamic>>> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _fetchUserData();
  }

  Future<List<Map<String, dynamic>>> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final futures = <Future<Map<String, dynamic>>>[
        _fetchFavoritesCount(user.uid),
        _fetchUserProfile(user),
        _fetchPreferences(),
      ];

      return Future.wait(futures);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _fetchFavoritesCount(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .doc(uid)
          .collection('articles')
          .count()
          .get();
      return {'type': 'favorites', 'count': snapshot.count};
    } catch (e) {
      return {'type': 'favorites', 'count': 0};
    }
  }

  Future<Map<String, dynamic>> _fetchUserProfile(User user) async {
    return {
      'type': 'profile',
      'email': user.email,
      'display_name': user.displayName,
      'uid': user.uid,
    };
  }

  Future<Map<String, dynamic>> _fetchPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'type': 'preferences',
      'theme': prefs.getString('theme_mode') ?? 'default',
      'language': prefs.getString('language') ?? 'en',
      'notifications_enabled': prefs.getBool('notifications_enabled') ?? true,
    };
  }

  Widget _buildDataStatsCard(List<Map<String, dynamic>> data) {
    final theme = Theme.of(context);
    final selectionColor = ref.watch(navIconColorProvider);
    final loc = AppLocalizations.of(context);

    int favoritesCount = 0;
    bool hasProfile = false;
    
    for (final item in data) {
      if (item['type'] == 'favorites') {
        favoritesCount = item['count'] ?? 0;
      }
      if (item['type'] == 'profile') {
        hasProfile = item['email'] != null;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                selectionColor.withOpacity(0.15),
                theme.colorScheme.surface.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selectionColor.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selectionColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectionColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.analytics_rounded,
                        size: 28,
                        color: selectionColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        loc.yourDataOverview,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onBackground,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: selectionColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectionColor.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.bookmark_rounded,
                              size: 28,
                              color: selectionColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$favoritesCount',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: selectionColor,
                            ),
                          ),
                          Text(
                            loc.favorites,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onBackground.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 80,
                      color: theme.colorScheme.outline.withOpacity(0.1),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: hasProfile 
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: hasProfile 
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              hasProfile 
                                  ? Icons.verified_rounded
                                  : Icons.person_off_rounded,
                              size: 28,
                              color: hasProfile ? Colors.green : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            hasProfile ? loc.active : loc.inactive,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: hasProfile ? Colors.green : Colors.grey,
                            ),
                          ),
                          Text(
                            loc.account,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onBackground.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool isLoading = false,
  }) {
    final theme = Theme.of(context);
    final selectionColor = ref.watch(navIconColorProvider);
    final iconColor = isDestructive ? Colors.red : selectionColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: theme.colorScheme.surface.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDestructive 
                      ? Colors.red.withOpacity(0.2)
                      : selectionColor.withOpacity(0.1),
                  width: 1.5,
                ),
                gradient: isDestructive
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.red.withOpacity(0.05),
                          theme.colorScheme.surface.withOpacity(0.7),
                        ],
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: iconColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            )
                          : Icon(
                              icon,
                              size: 24,
                              color: iconColor,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: isDestructive ? Colors.red : theme.colorScheme.onBackground,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onBackground.withOpacity(0.7),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDestructive ? Colors.red : selectionColor.withOpacity(0.8),
                      size: 24,
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

  Widget _buildInfoSection({
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);
    final selectionColor = ref.watch(navIconColorProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: selectionColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onBackground,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.onBackground.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onBackground.withOpacity(0.8),
                height: 1.6,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 64,
        title: AppBarTitle(loc.privacyData),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.background.withOpacity(0.9),
                  theme.colorScheme.background.withOpacity(0.7),
                ],
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.background,
              theme.colorScheme.surface.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _userDataFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        return _buildDataStatsCard(snapshot.data!);
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  Text(
                    'PRIVACY & LEGAL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onBackground.withOpacity(0.5),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildPrivacyCard(
                    title: loc.privacyPolicy,
                    description: loc.privacyPolicyDesc,
                    icon: Icons.privacy_tip_rounded,
                    onTap: _openPrivacyPolicy,
                  ),

                  _buildPrivacyCard(
                    title: loc.termsOfService,
                    description: loc.termsOfServiceDesc,
                    icon: Icons.description_rounded,
                    onTap: _openTermsOfService,
                  ),

                  const SizedBox(height: 32),
                  Text(
                    'DATA MANAGEMENT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onBackground.withOpacity(0.5),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildPrivacyCard(
                    title: loc.exportData,
                    description: loc.exportDataDesc,
                    icon: Icons.download_rounded,
                    onTap: _exportData,
                    isLoading: _isExporting,
                  ),

                  if (user != null)
                    _buildPrivacyCard(
                      title: loc.deleteAccount,
                      description: loc.deleteAccountDesc,
                      icon: Icons.delete_forever_rounded,
                      onTap: () => _isDeleting ? null : _confirmDeleteAccount(),
                      isDestructive: true,
                      isLoading: _isDeleting,
                    ),

                  const SizedBox(height: 32),
                  _buildInfoSection(
                    title: loc.whatWeCollect,
                    content: loc.whatWeCollectDetails,
                  ),

                  _buildInfoSection(
                    title: loc.yourRights,
                    content: loc.yourRightsDetails,
                  ),

                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onBackground.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: theme.colorScheme.onBackground.withOpacity(0.6),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            loc.privacyNote,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onBackground.withOpacity(0.7),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    const url = 'https://droid-e9db9.web.app/privacy.html';
    final uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        final loc = AppLocalizations.of(context);
        _showErrorDialog(loc.privacyPolicyError);
      }
    } catch (e) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      _showErrorDialog(loc.openUrlError);
    }
  }

  Future<void> _openTermsOfService() async {
    const url = 'https://droid-e9db9.web.app/terms.html';
    final uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        final loc = AppLocalizations.of(context);
        _showErrorDialog(loc.openUrlError);
      }
    } catch (e) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      _showErrorDialog(loc.openUrlError);
    }
  }

  void _showErrorDialog(String message) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 20,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Unable to Open',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onBackground.withOpacity(0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    final loc = AppLocalizations.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Not signed in');
      }

      final Map<String, dynamic> exportData = {
        'user_profile': {
          'email': user.email,
          'display_name': user.displayName,
          'uid': user.uid,
          'created_at': user.metadata.creationTime?.toIso8601String(),
        },
        'export_date': DateTime.now().toIso8601String(),
        'export_version': '1.0',
      };

      try {
        final favoritesSnap = await FirebaseFirestore.instance
            .collection('favorites')
            .doc(user.uid)
            .collection('articles')
            .get();

        exportData['favorites'] = {
          'count': favoritesSnap.docs.length,
          'articles': favoritesSnap.docs.map((doc) => doc.data()).toList(),
        };
      } catch (e) {
        ErrorHandler.logError(e, StackTrace.current, reason: 'Export favorites failed');
      }

      final prefs = await SharedPreferences.getInstance();
      exportData['preferences'] = {
        'theme': prefs.getString('theme_mode'),
        'language': prefs.getString('language'),
        'notifications_enabled': prefs.getBool('notifications_enabled'),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      if (!mounted) return;

      _showExportDialog(jsonString, loc);
    } catch (e) {
      ErrorHandler.logError(e, StackTrace.current, reason: 'Data export failed');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.exportError(e.toString())),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showExportDialog(String jsonString, AppLocalizations loc) {
    final theme = Theme.of(context);
    final selectionColor = ref.watch(navIconColorProvider);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 20,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                selectionColor.withOpacity(0.1),
                theme.colorScheme.surface,
              ],
            ),
            border: Border.all(
              color: selectionColor.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selectionColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: selectionColor, width: 2),
                  ),
                  child: Icon(
                    Icons.download_done_rounded,
                    size: 32,
                    color: selectionColor,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  loc.dataExportTitle,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onBackground,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  loc.dataExportPreview,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onBackground.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onBackground.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.1),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonString,
                      style: TextStyle(
                        fontFamily: 'Monospace',
                        fontSize: 12,
                        color: theme.colorScheme.onBackground.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
                        ),
                      ),
                      child: Text(
                        loc.close,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onBackground.withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _shareExportData(jsonString, loc);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectionColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                        shadowColor: selectionColor.withOpacity(0.4),
                      ),
                      child: Text(
                        loc.saveAndShare,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareExportData(String jsonString, AppLocalizations loc) async {
    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File(
        '${directory.path}/bd_news_data_export_$timestamp.json',
      );
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'BD News Reader Data Export',
        text: 'My exported data from BD News Reader',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.dataExportComplete),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selectionColor = ref.watch(navIconColorProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: theme.colorScheme.surface.withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 20,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.red.withOpacity(0.1),
                theme.colorScheme.surface.withOpacity(0.95),
              ],
            ),
            border: Border.all(
              color: Colors.red.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 32,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  loc.deleteAccountConfirmation,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.red,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Text(
                    loc.deleteAccountWarning,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.colorScheme.onBackground.withOpacity(0.8),
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
                        ),
                      ),
                      child: Text(
                        loc.cancel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onBackground.withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                        shadowColor: Colors.red.withOpacity(0.4),
                      ),
                      child: Text(
                        loc.deleteEverything,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    setState(() => _isDeleting = true);
    final loc = AppLocalizations.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      try {
        final favoritesSnap = await FirebaseFirestore.instance
            .collection('favorites')
            .doc(user.uid)
            .collection('articles')
            .get();

        for (final doc in favoritesSnap.docs) {
          await doc.reference.delete();
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();
      } catch (e) {
        ErrorHandler.logError(e, StackTrace.current, reason: 'Delete Firestore data failed');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await user.delete();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.accountDeleted),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      ErrorHandler.logError(e, StackTrace.current, reason: 'Account deletion failed');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.deleteError(e.toString())),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }
}