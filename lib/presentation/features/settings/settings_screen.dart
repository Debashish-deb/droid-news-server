import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/app_icons.dart';
import '../../../core/design_tokens.dart';
import '../../../core/app_paths.dart';
import '../../../core/enums/theme_mode.dart';
import '../../../core/theme.dart';
import '../../../core/utils/number_localization.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/app_settings_providers.dart';
import '../../providers/language_providers.dart' show currentLocaleProvider, languageCodeProvider, languageProvider;
import '../../providers/premium_providers.dart' show isPremiumProvider, premiumNotifierProvider;
import '../../providers/tab_providers.dart' show currentTabIndexProvider;
import '../../providers/theme_providers.dart' show borderColorProvider, currentThemeModeProvider, isDarkModeProvider, navIconColorProvider, themeProvider;
import '../../widgets/animated_theme_container.dart' show AnimatedThemeContainer;
import '../../widgets/app_drawer.dart' show AppDrawer;
import '../../widgets/banner_ad_widget.dart' show BannerAdWidget;
import '../common/app_bar.dart' show AppBarTitle;
import 'privacy_data_screen.dart';
import 'widgets/settings_3d_widgets.dart';
import '../../widgets/glass_pill_button.dart';
import '../../widgets/glass_icon_button.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  ProductDetails? _removeAdsProduct;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _storeAvailable = false;

  String _version = '';
  bool _isClearingCache = false;

  final ScrollController _scrollController = ScrollController();
  bool _firstBuild = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _setupStore();
    _listenToPurchases();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
      }
    });
  }

  void _onTabChanged() {
    if (!mounted) return;
    final int currentTab = ref.watch(currentTabIndexProvider);
    if (currentTab == 3 && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    try {
    } catch (e) {
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_firstBuild && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
    _firstBuild = false;
  }

 Future<void> _loadVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  Future<void> _setupStore() async {
    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) return;

    const Set<String> ids = <String>{'remove_ads'};
    final ProductDetailsResponse response = await _iap.queryProductDetails(ids);

    if (!mounted) return;

    if (response.productDetails.isNotEmpty) {
      setState(() => _removeAdsProduct = response.productDetails.first);
    }
  }

  void _listenToPurchases() {
    _subscription = _iap.purchaseStream.listen(
      (List<PurchaseDetails> purchases) {
        _handlePurchases(purchases);
      },
      onDone: () {
        _subscription?.cancel();
      },
      onError: (Object error) {
        debugPrint('Purchase stream error: $error');
      },
    );
  }

  void _handlePurchases(List<PurchaseDetails> purchases) {
    for (final PurchaseDetails purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        ref.read(premiumNotifierProvider).setPremium(true);
        _snack('Thank you for your purchase! Ads have been removed.');
      }

      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  void _buyRemoveAds() {
    context.push(AppPaths.subscriptionManagement);
  }

 Future<void> _launchPaypal() async {
    final String id = dotenv.env['PAYPAL_BUTTON_ID'] ?? '';
    if (id.isEmpty) return;

    final Uri url = Uri.parse(
      'https://www.paypal.com/donate?hosted_button_id=$id',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _rateApp() async {
    const String iosAppId =
        '0000000000'; 
    const String androidPkg = 'com.bd.bdnewsreader';

    final Uri url;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      url = Uri.parse(
        'https://apps.apple.com/app/id$iosAppId?action=write-review',
      );
    } else {
      url = Uri.parse(
        'https://play.google.com/store/apps/details?id=$androidPkg',
      );
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

 Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);

    int clearedCount = 0;

    try {
      await DefaultCacheManager().emptyCache();
      clearedCount++;

      final List<String> hiveBoxNames = <String>['latest', 'latest_meta'];
      for (final String boxName in hiveBoxNames) {
        try {
          if (Hive.isBoxOpen(boxName)) {
            final box = Hive.box(boxName);
            await box.clear();
            clearedCount++;
          }
        } catch (e) {
          debugPrint('⚠️  Could not clear box $boxName: $e');
        }
      }

      if (!mounted) return;

      setState(() => _isClearingCache = false);
      _snack('${loc.clearCacheSuccess} ($clearedCount caches cleared)');
    } catch (e) {
      debugPrint('❌ Cache clear error: $e');
      if (!mounted) return;

      setState(() => _isClearingCache = false);
      _snack('Error clearing cache: $e');
    }
  }

 Future<void> _contactSupport() async {
    final String email = loc.contactEmail;
    final Uri mail = Uri.parse('mailto:$email');

    if (await canLaunchUrl(mail)) {
      await launchUrl(mail, mode: LaunchMode.externalApplication);
    }
  }

 void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  AppLocalizations get loc => AppLocalizations.of(context);

  Widget _glass(Widget child) {
    final themeMode = ref.watch(currentThemeModeProvider);
    final bool isLight = themeMode == AppThemeMode.light;
    final bool isBangladesh = themeMode == AppThemeMode.bangladesh;
    final bool isDark = themeMode == AppThemeMode.dark;

    final Color faceColor = isBangladesh 
        ? const Color(0xFF00392C).withOpacity(0.35) 
        : (isLight ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.06));

    final Color highlightColor = isBangladesh 
        ? const Color(0xFF006A4E).withOpacity(0.2) 
        : (isLight ? Colors.grey.withOpacity(0.15) : Colors.white.withOpacity(0.1));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5), // Increased from 2 for better separation
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24), // Sharper, more premium
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), // Even more blur
          child: Container(
            decoration: BoxDecoration(
              color: faceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: highlightColor.withOpacity(0.15), 
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark || isBangladesh
                    ? [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.01),
                      ]
                    : [
                        Colors.white.withOpacity(0.95),
                        Colors.white.withOpacity(0.7),
                        Colors.white.withOpacity(0.5),
                      ],
              ),
              boxShadow: [
                // Outer shadow
                BoxShadow(
                  color: Colors.black.withOpacity(isDark || isBangladesh ? 0.4 : 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
                // Inner glow
                BoxShadow(
                  color: Colors.white.withOpacity(isDark || isBangladesh ? 0.03 : 0.15),
                  blurRadius: 8,
                  spreadRadius: -4,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Premium top highlight (3D effect)
                Positioned(
                  top: 0,
                  left: 20,
                  right: 20,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(isDark || isBangladesh ? 0.5 : 0.9),
                          Colors.white.withOpacity(isDark || isBangladesh ? 0.5 : 0.9),
                          Colors.white.withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.2, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),
                // Subtle side highlights for 3D depth
                Positioned(
                  left: 0,
                  top: 20,
                  bottom: 20,
                  child: Container(
                    width: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(isDark || isBangladesh ? 0.2 : 0.4),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10), // Increased from 8
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      child,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(String title, Color color) {
    final themeMode = ref.watch(currentThemeModeProvider);
    final Color accentColor;
    if (themeMode == AppThemeMode.bangladesh) {
      accentColor = Colors.redAccent;
    } else if (themeMode == AppThemeMode.light) {
      accentColor = Colors.blueAccent;
    } else {
      accentColor = const Color(0xFFFFC107);
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glowing Separator Line
          Container(
            height: 1.5,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.0),
                  accentColor.withOpacity(0.5),
                  accentColor.withOpacity(0.5),
                  Colors.white.withOpacity(0.0),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
          // Header Text with Background Shield
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.transparent, // Let the panel color show through
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              color: Colors.black.withOpacity(0.6), // Dark background for the text
              child: Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                  letterSpacing: 2.0,
                  fontFamily: AppTypography.fontFamily,
                  shadows: [
                    Shadow(
                      color: accentColor.withOpacity(0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color txt = theme.textTheme.bodyLarge?.color ?? Colors.white;

    final bool isPremium = ref.watch(isPremiumProvider);
    final appSettings = ref.watch(appSettingsProvider);
    final AppThemeMode mode = ref.watch(currentThemeModeProvider);
    final List<Color> colors = AppGradients.getBackgroundGradient(mode);
    final Color start = colors[0], end = colors[1];

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),

      appBar: AppBar(
        title: AppBarTitle(loc.settings),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        leading: Builder(
          builder: (context) => Center(
            child: GlassIconButton(
              icon: Icons.menu_rounded,
              onPressed: () => Scaffold.of(context).openDrawer(),
              isDark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), // More blur
            child: Container(color: Colors.transparent),
          ),
        ),
      ),

      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: AnimatedThemeContainer(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    colors[0].withOpacity(0.85),
                    colors[1].withOpacity(0.85),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                vertical: 8, // Increased from 4
              ),
              child: Column(
                children: <Widget>[
                  if (!isPremium) _glass(const BannerAdWidget()),

                  // Theme Section
                  _glass(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _header(loc.theme, txt),
                        _ThemeSelector(
                          current: ref.watch(currentThemeModeProvider),
                          onChanged: (AppThemeMode mode) => 
                              ref.read(themeProvider.notifier).setTheme(mode),
                          loc: loc,
                          onGoPremium: _buyRemoveAds,
                        ),
                      ],
                    ),
                  ),

                  // Language Section
                  _glass(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _header(loc.language, txt),
                        Row(
                          children: [
                            Expanded(child: _lang('en', 'English')),
                            const SizedBox(width: 10),
                            Expanded(child: _lang('bn', 'বাংলা')),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Ad-Free Experience Section
                  _glass(
                    Column(
                      children: <Widget>[
                        _header(loc.adFree, txt),
                        if (isPremium)
                          Settings3DButton(
                            onTap: () {},
                            label: 'ADS REMOVED', // Matching reference image
                            icon: Icons.verified_user_rounded,
                            isSelected: true,
                            width: double.infinity,
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_removeAdsProduct != null)
                                Expanded(
                                  child: GlassPillButton(
                                    onPressed: _buyRemoveAds,
                                    icon: Icons.credit_card_rounded,
                                    label: _removeAdsProduct!.price,
                                    isPrimary: true,
                                    isDark: theme.brightness == Brightness.dark,
                                    fontSize: 14,
                                  ),
                                ),
                              if (_removeAdsProduct != null) const SizedBox(width: 10),
                              Expanded(
                                child: GlassPillButton(
                                  onPressed: _launchPaypal,
                                  icon: Icons.favorite_rounded,
                                  label: loc.btnDonate,
                                  isDestructive: true,
                                  isDark: theme.brightness == Brightness.dark,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  _glass(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _header(loc.misc, txt),
                        const SizedBox(height: 8),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 4, // Reduced from 6
                          crossAxisSpacing: 8,
                          childAspectRatio: 3.6, // Increased from 3.2
                          children: [
                            Settings3DButton(
                              onTap: () => ref.read(appSettingsProvider.notifier).setDataSaver(!appSettings.dataSaver),
                              icon: AppIcons.download,
                              label: loc.dataSaver,
                              isSelected: appSettings.dataSaver,
                              fontSize: 12,
                            ),
                            Settings3DButton(
                              onTap: () => ref.read(appSettingsProvider.notifier).setPushNotif(!appSettings.pushNotif),
                              icon: AppIcons.notification,
                              label: loc.btnNotifications,
                              isSelected: appSettings.pushNotif,
                              fontSize: 12,
                            ),
                            Settings3DButton(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const PrivacyDataScreen()),
                              ),
                              icon: Icons.security_rounded,
                              label: loc.btnPrivacy,
                              fontSize: 12,
                            ),
                            Settings3DButton(
                              onTap: _isClearingCache ? () {} : _clearCache,
                              icon: _isClearingCache ? Icons.refresh_rounded : AppIcons.delete,
                              label: _isClearingCache ? loc.clearingCache : loc.btnCache,
                              fontSize: 12,
                              isSelected: _isClearingCache,
                            ),
                            Settings3DButton(
                              onTap: _rateApp,
                              icon: AppIcons.star_filled,
                              label: loc.btnRate,
                              fontSize: 12,
                            ),
                            Settings3DButton(
                              onTap: _contactSupport,
                              icon: AppIcons.help,
                              label: loc.btnSupport,
                              fontSize: 12,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8), // Increased from 4

                  _glass(
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${loc.versionPrefix} ${localizeNumber(_version, ref.watch(languageCodeProvider))}',
                          style: TextStyle(
                            color: (mode == AppThemeMode.dark || mode == AppThemeMode.bangladesh) ? Colors.white : txt.withOpacity(0.8),
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lang(String code, String label, {double? width}) {
    final currentLocale = ref.watch(currentLocaleProvider);
    final selected = currentLocale.languageCode.toLowerCase() == code;

    return Settings3DButton(
      onTap: () => ref.read(languageProvider.notifier).setLanguage(code),
      label: label,
      isSelected: selected,
      icon: code == 'en' ? Icons.language_rounded : AppIcons.flag,
      width: width ?? 172,
      fontSize: 15, // Larger font for language buttons
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({
    required this.current,
    required this.onChanged,
    required this.loc,
    this.onGoPremium,
  });

  final AppThemeMode current;
  final ValueChanged<AppThemeMode> onChanged;
  final AppLocalizations loc;
  final VoidCallback? onGoPremium;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: _item(context, AppThemeMode.light, 'Light', AppIcons.lightMode)),
        const SizedBox(width: 8),
        Expanded(child: _item(context, AppThemeMode.dark, 'Dark', AppIcons.darkMode)),
        const SizedBox(width: 8),
        Expanded(
          child: _item(
            context,
            AppThemeMode.bangladesh,
            'Desh', // Corrected from Dusk
            AppIcons.flag,
            isPremium: true,
          ),
        ),
      ],
    );
  }

  Widget _item(
    BuildContext context,
    AppThemeMode mode,
    String label,
    IconData icon, {
    bool isPremium = false,
  }) {
    final bool selected = current == mode;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Settings3DButton(
          onTap: () {
            if (isPremium) {
                final container = ProviderScope.containerOf(context);
                final bool userIsPremium = container.read(isPremiumProvider);
                if (!userIsPremium) {
                  _showPremiumLockDialog(context, label);
                  return;
                }
            }
            onChanged(mode);
          },
          label: label,
          icon: icon,
          isSelected: selected,
          width: double.infinity, 
          fontSize: 11,
        ),
        if (isPremium)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFD740), // Brighter amber
                    Color(0xFFFF9100), // Deeper orange
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFC107).withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_rounded, 
                size: 10, 
                color: Colors.white
              ),
            ),
          ),
      ],
    );
  }

  void _showPremiumLockDialog(BuildContext context, String themeName) {
    showDialog(
      context: context,
      builder:
          (BuildContext context) => Dialog(
            backgroundColor: Theme.of(context).cardTheme.color?.withOpacity(0.95),
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
                    Colors.amber.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.3),
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
                        color: Colors.amber.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: const Icon(
                        Icons.stars_rounded, 
                        size: 32, 
                        color: Colors.amber
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      loc.premiumFeature,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      loc.premiumFeatureDesc(themeName),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            loc.close,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onGoPremium?.call();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 8,
                            shadowColor: Colors.amber.withOpacity(0.5),
                          ),
                          child: Text(
                            loc.goPremium,
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
}