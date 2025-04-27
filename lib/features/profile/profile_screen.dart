// lib/features/profile/profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../localization/l10n/app_localizations.dart';
import 'auth_service.dart';
import 'edit_profile_screen.dart';
import 'animated_background.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, String>? _profile;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    _profile = await AuthService().getProfile();
    if (mounted) {
      _fadeController.forward();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    if (FirebaseAuth.instance.currentUser == null) {
      Future.microtask(() => context.go('/login'));
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(loc.profile),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: loc.editProfile,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AnimatedBackground(),
          SafeArea(
            child: _profile == null
                ? const Center(child: CircularProgressIndicator())
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.white.withOpacity(0.15),
                            child: CircleAvatar(
                              radius: 52,
                              backgroundImage: _buildProfileImage(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            _profile!['name'] ?? loc.name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black45,
                                      offset: Offset(1, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildGlassCard(
                          context,
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            title: Text(
                              loc.details,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            iconColor: Colors.white,
                            collapsedIconColor: Colors.white70,
                            childrenPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            children: _buildProfileDetails(context),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (context.mounted) context.go('/login');
        },
        label: Text(loc.logout),
        icon: const Icon(Icons.logout),
        backgroundColor: isDark ? Colors.white10 : Colors.black12,
      ),
    );
  }

  List<Widget> _buildProfileDetails(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return [
      if ((_profile!['email'] ?? '').isNotEmpty)
        _buildDetailRow(loc.email, _profile!['email']!),
      if ((_profile!['phone'] ?? '').isNotEmpty)
        _buildDetailRow(loc.phone, _profile!['phone']!),
      if ((_profile!['role'] ?? '').isNotEmpty)
        _buildDetailRow(loc.role, _profile!['role']!),
      if ((_profile!['department'] ?? '').isNotEmpty)
        _buildDetailRow(loc.department, _profile!['department']!),
    ];
  }

  ImageProvider _buildProfileImage() {
    final path = _profile!['image'] ?? '';
    if (path.isNotEmpty && File(path).existsSync()) {
      return FileImage(File(path));
    } else {
      return const AssetImage('assets/default_avatar.png');
    }
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.white54),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(BuildContext context, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white30, width: 1),
      ),
      child: child,
    );
  }
}
