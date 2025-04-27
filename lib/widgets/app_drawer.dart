// lib/widgets/app_drawer.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';

import '../core/theme_provider.dart';
import '../features/profile/auth_service.dart';
import '../localization/l10n/app_localizations.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

// Use TickerProviderStateMixin for multiple controllers
class _AppDrawerState extends State<AppDrawer> with TickerProviderStateMixin {
  late final AnimationController _flagController;
  late final AnimationController _flagFadeController;
  late final Animation<double> _flagFadeAnimation;
  late final AnimationController _tigerController;
  late final Animation<Offset> _tigerAnimation;
  late final AnimationController _avatarGlowController;
  late final Animation<double> _avatarGlowAnimation;
  late final AudioPlayer _audioPlayer;

  Map<String, String>? _profile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();

    _flagController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _flagFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _flagFadeAnimation = CurvedAnimation(
      parent: _flagFadeController,
      curve: Curves.easeIn,
    );
    // start the fade animation
    _flagFadeController.forward();

    _tigerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _tigerAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.03),
    ).animate(
      CurvedAnimation(parent: _tigerController, curve: Curves.easeInOut),
    );

    _avatarGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _avatarGlowAnimation = Tween<double>(begin: 10, end: 25).animate(
      CurvedAnimation(parent: _avatarGlowController, curve: Curves.easeInOut),
    );

    _audioPlayer = AudioPlayer();
    Future.delayed(const Duration(seconds: 2), _playTigerRoar);
  }

  @override
  void dispose() {
    _flagController.dispose();
    _flagFadeController.dispose();
    _tigerController.dispose();
    _avatarGlowController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService().getProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _playTigerRoar() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/tiger_roar.mp3'));
    } catch (e) {
      debugPrint('Tiger roar sound error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final themeProvider = context.watch<ThemeProvider>();
    final appTheme = themeProvider.appThemeMode;
    final bool isDesh = appTheme == AppThemeMode.bangladesh;
    final size = MediaQuery.of(context).size;

    return Drawer(
      child: Column(
        children: [
          _buildHeader(context, loc),
          Expanded(
            child: isDesh
                ? _buildBodyWithGraphics(context, loc, size)
                : _buildBodyPlain(context, loc),
          ),
          _buildFooter(context, loc),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations loc) {
    return Stack(
      children: [
        ClipPath(
          clipper: WavyClipper(),
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _avatarGlowAnimation,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .primaryColor
                                .withOpacity(0.6),
                            blurRadius: _avatarGlowAnimation.value,
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white,
                    backgroundImage: _profileImageProvider(),
                    child: _profileImageProvider() == null
                        ? const Icon(Icons.person, size: 36, color: Colors.grey)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isLoadingProfile
                      ? loc.loadError
                      : (_profile?['name']?.isNotEmpty == true
                          ? _profile!['name']!
                          : loc.noUserConnected),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 6,
                            color: Colors.black45,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  loc.bdNewsHub,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBodyPlain(BuildContext context, AppLocalizations loc) {
    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: _buildMenuItems(context, loc),
    );
  }

  Widget _buildBodyWithGraphics(
      BuildContext context, AppLocalizations loc, Size size) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/icons/couple_only.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        Positioned(
          top: size.height * 0.05,
          left: size.width * 0.3,
          right: size.width * 0.3,
          child: FadeTransition(
            opacity: _flagFadeAnimation,
            child: Lottie.asset(
              'assets/animations/flag_wave.json',
              controller: _flagController,
              repeat: true,
              animate: true,
              height: 100,
            ),
          ),
        ),
        ListView(
          padding: const EdgeInsets.only(top: 8),
          children: _buildMenuItems(context, loc),
        ),
      ],
    );
  }

  List<Widget> _buildMenuItems(BuildContext context, AppLocalizations loc) {
    return [
      _buildTile(context, Icons.home, loc.home, '/home'),
      _buildTile(context, Icons.article, loc.newspapers, '/newspaper'),
      _buildTile(context, Icons.favorite, loc.favorites, '/favorites'),
      _buildTile(context, Icons.person, loc.profile, '/profile'),
      _buildTile(context, Icons.info, loc.about, '/about'),
      _buildTile(context, Icons.help, loc.supports, '/supports'),
      _buildTile(context, Icons.search, loc.search, '/search'),
    ];
  }

  Widget _buildTile(
      BuildContext context, IconData icon, String title, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.of(context).pop();
        context.go(route);
      },
    );
  }

  Widget _buildFooter(BuildContext context, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: Text(loc.logout),
          ),
          SlideTransition(
            position: _tigerAnimation,
            child: SvgPicture.asset(
              'assets/icons/tiger.svg',
              height: 40,
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _profileImageProvider() {
    final path = _profile?['image'] ?? '';
    if (path.isEmpty) return null;
    if (path.startsWith('http')) {
      return NetworkImage(path);
    } else {
      return FileImage(File(path));
    }
  }
}

class WavyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 30);
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2, size.height - 30);
    var secondControlPoint = Offset(size.width * 3 / 4, size.height - 90);
    var secondEndPoint = Offset(size.width, size.height - 30);

    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
