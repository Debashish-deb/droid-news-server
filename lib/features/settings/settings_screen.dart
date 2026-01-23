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

import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../presentation/providers/theme_providers.dart';
import '../../presentation/providers/language_providers.dart';
import '../../presentation/providers/premium_providers.dart';
import '../../presentation/providers/app_settings_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../features/common/app_bar.dart';
import '../../widgets/animated_theme_container.dart';
import '../../core/app_icons.dart';
import '../../presentation/providers/tab_providers.dart';
import '../../core/utils/number_localization.dart';
import 'privacy_data_screen.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_paths.dart';

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

    // Listen to tab changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Tab listener managed by Riverpod - removed;
      }
    });
  }

  void _onTabChanged() {
    if (!mounted) return;
    final int currentTab = ref.watch(currentTabIndexProvider);
    // This is tab 3 (Settings)
    if (currentTab == 3 && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    try {
      // Tab listener managed by Riverpod - removed;
    } catch (e) {
      // Context might be unavailable
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Reset scroll when returning to this main tab
    if (!_firstBuild && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
    _firstBuild = false;
  }

  // =====================================================
  // VERSION
  // =====================================================
  Future<void> _loadVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  // =====================================================
  // IAP STORE SETUP
  // =====================================================
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

  // =====================================================
  // PURCHASE LISTENER
  // =====================================================
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
        // Use Riverpod premium provider
        ref.read(premiumProvider.notifier).setPremium(true);
        _snack('Thank you for your purchase! Ads have been removed.');
      }

      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  // =====================================================
  // BUY REMOVE ADS
  // =====================================================
  void _buyRemoveAds() {
    // Navigate to enhanced RemoveAdsScreen with unified error handling
    context.push(AppPaths.removeAds);
  }

  // =====================================================
  // PAYPAL DONATION
  // =====================================================
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

  // =====================================================
  // RATE APP (CROSS-PLATFORM)
  // =====================================================
  Future<void> _rateApp() async {
    // iOS App Store ID - replace with your actual App Store ID
    const String iosAppId =
        '0000000000'; // TODO: CRITICAL - Replace with real App Store ID before iOS release!
    const String androidPkg = 'com.bd.bdnewsreader';

    final Uri url;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      // iOS: App Store link
      url = Uri.parse(
        'https://apps.apple.com/app/id$iosAppId?action=write-review',
      );
    } else {
      // Android: Play Store link
      url = Uri.parse(
        'https://play.google.com/store/apps/details?id=$androidPkg',
      );
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // =====================================================
  // CLEAR CACHE (COMPREHENSIVE)
  // =====================================================
  Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);

    int clearedCount = 0;

    try {
      // 1. Clear image cache (CachedNetworkImage, etc.)
      await DefaultCacheManager().emptyCache();
      clearedCount++;

      // 2. Clear Hive article cache boxes
      final List<String> hiveBoxNames = <String>['latest', 'latest_meta'];
      for (final String boxName in hiveBoxNames) {
        try {
          if (Hive.isBoxOpen(boxName)) {
            // Box is already open, just clear it
            final box = Hive.box(boxName);
            await box.clear();
            clearedCount++;
          }
        } catch (e) {
          debugPrint('⚠️  Could not clear box $boxName: $e');
          // Continue with other boxes even if one fails
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

  // =====================================================
  // SUPPORT EMAIL
  // =====================================================
  Future<void> _contactSupport() async {
    final String email = loc.contactEmail;
    final Uri mail = Uri.parse('mailto:$email');

    if (await canLaunchUrl(mail)) {
      await launchUrl(mail, mode: LaunchMode.externalApplication);
    }
  }

  // =====================================================
  // UTIL
  // =====================================================
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  AppLocalizations get loc => AppLocalizations.of(context)!;

  // =====================================================
  // GLASS
  // =====================================================
  Widget _glass(Widget child) {
    // Use Riverpod theme provider
    final themeMode = ref.watch(currentThemeModeProvider);
    final bool isLight = themeMode == AppThemeMode.light;

    // Very light, subtle container - no dark backgrounds
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:
            isLight
                ? Colors.white.withOpacity(0.4) // Very light for light theme
                : Colors.white.withOpacity(
                  0.05,
                ), // Barely visible for dark theme
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color:
              isLight
                  ? Colors.grey.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
        ),
      ),
      child: child,
    );
  }

  Widget _header(String title, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
    ),
  );

  // =====================================================
  // BUILD
  // =====================================================
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color txt = theme.textTheme.bodyLarge?.color ?? Colors.white;

    // Use Riverpod providers
    final bool isPremium = ref.watch(isPremiumProvider);
    // Use Riverpod app settings provider
    final appSettings = ref.watch(appSettingsProvider);
    final AppThemeMode mode = ref.watch(currentThemeModeProvider);
    final List<Color> colors = AppGradients.getBackgroundGradient(mode);
    final Color start = colors[0], end = colors[1];

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),

      appBar: AppBar(
        centerTitle: true,
        title: AppBarTitle(loc.settings),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),

      body: Stack(
        children: [
          // Global Gradient Background
          AnimatedThemeContainer(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  colors[0].withOpacity(0.8),
                  colors[1].withOpacity(0.9),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(22),
              child: Column(
                children: <Widget>[
                  if (!isPremium) const BannerAdWidget(),

                  // =====================
                  // THEME
                  // =====================
                  _glass(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _header(loc.theme, txt),

                        _ThemeSelector(
                          current: ref.watch(currentThemeModeProvider),
                          onChanged:
                              (AppThemeMode mode) => ref
                                  .read(themeProvider.notifier)
                                  .setTheme(mode),
                          loc: loc,
                          onGoPremium: _buyRemoveAds,
                        ),
                      ],
                    ),
                  ),

                  // =====================
                  // LANGUAGE
                  // =====================
                  _glass(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _header(loc.language, txt),
                        Row(
                          children: <Widget>[
                            _lang('en', 'English', txt),
                            const SizedBox(width: 12),
                            _lang('bn', 'বাংলা', txt),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // =====================
                  // REMOVE ADS
                  // =====================
                  _glass(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _header(loc.adFree, txt),

                        if (isPremium)
                          _info(loc.adsRemoved, txt)
                        else
                          Wrap(
                            spacing: 10,
                            children: <Widget>[
                              if (_removeAdsProduct != null)
                                OutlinedButton.icon(
                                  onPressed: _buyRemoveAds,
                                  icon: const Icon(Icons.payment),
                                  label: Text(
                                    '${loc.removeAds} •  ${_removeAdsProduct!.price}',
                                  ),
                                ),
                              OutlinedButton.icon(
                                onPressed: _launchPaypal,
                                icon: const Icon(Icons.volunteer_activism),
                                label: Text(loc.paypalDonate),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // =====================
                  // APP SETTINGS
                  // =====================
                  _glass(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _header(loc.misc, txt),

                        _toggle(
                          AppIcons.download,
                          loc.dataSaver,
                          loc.dataSaverDesc,
                          appSettings.dataSaver,
                          (val) => ref
                              .read(appSettingsProvider.notifier)
                              .setDataSaver(val),
                          txt,
                        ),

                        _toggle(
                          AppIcons.notification,
                          loc.pushNotifications,
                          loc.pushNotificationsDesc,
                          appSettings.pushNotif,
                          (val) => ref
                              .read(appSettingsProvider.notifier)
                              .setPushNotif(val),
                          txt,
                        ),

                        Divider(color: txt.withOpacity(0.15)),

                        // Privacy & Data
                        ListTile(
                          leading: const Icon(Icons.privacy_tip),
                          title: Text(loc.privacyData),
                          subtitle: Text(loc.privacyDataDesc),
                          trailing: const Icon(AppIcons.forward),
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const PrivacyDataScreen(),
                                ),
                              ),
                        ),

                        ListTile(
                          leading: const Icon(AppIcons.delete),
                          title: Text(loc.clearCache),
                          trailing:
                              _isClearingCache
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(AppIcons.forward),
                          onTap: _clearCache,
                        ),

                        ListTile(
                          leading: const Icon(AppIcons.star),
                          title: Text(loc.rateApp),
                          trailing: const Icon(AppIcons.forward),
                          onTap: _rateApp,
                        ),

                        ListTile(
                          leading: const Icon(AppIcons.help),
                          title: Text(loc.contactSupport),
                          subtitle: Text(loc.contactEmail),
                          trailing: const Icon(AppIcons.forward),
                          onTap: _contactSupport,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    '${loc.versionPrefix} ${localizeNumber(_version, ref.watch(languageCodeProvider))}',
                    style: TextStyle(
                      color: txt.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
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

  // =====================================================
  // HELPERS
  // =====================================================
  Widget _toggle(
    IconData icon,
    String title,
    String sub,
    bool value,
    Function(bool) onChange,
    Color color,
  ) {
    return SwitchListTile(
      value: value,
      onChanged: onChange,
      title: Text(title),
      subtitle: Text(sub),
      secondary: Icon(icon),
    );
  }

  Widget _info(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.green,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _lang(String code, String label, Color textColor) {
    // Use Riverpod providers
    final currentLocale = ref.watch(currentLocaleProvider);
    final isDark = ref.watch(isDarkModeProvider);

    final bool selected = currentLocale.languageCode.toLowerCase() == code;
    final bool isLightMode = Theme.of(context).brightness == Brightness.light;

    // Better contrast for light mode: use solid color accent instead of gradient
    final borderColor = ref.watch(borderColorProvider);
    final Color backgroundColor =
        selected
            ? (isLightMode
                ? borderColor.withOpacity(0.15)
                : borderColor.withOpacity(0.2))
            : Colors.transparent;

    // Ensure text is always readable in light mode
    final Color finalTextColor =
        selected ? (isLightMode ? Colors.black87 : Colors.white) : textColor;

    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(languageProvider.notifier).setLanguage(code),
        child: AnimatedThemeContainer(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: finalTextColor,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
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
        _item(context, AppThemeMode.light, loc.lightTheme, AppIcons.lightMode),
        const SizedBox(width: 8),
        _item(context, AppThemeMode.dark, loc.darkTheme, AppIcons.darkMode),
        const SizedBox(width: 8),
        _item(
          context,
          AppThemeMode.bangladesh,
          loc.bangladeshTheme,
          AppIcons.flag,
          isPremium: true,
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
    // Access via ProviderScope since this is a StatelessWidget
    final container = ProviderScope.containerOf(context);
    final Color borderColor = container.read(borderColorProvider);
    // Use Theme brightness for reliable check
    final bool isLightMode = Theme.of(context).brightness == Brightness.light;

    final Color backgroundColor =
        selected
            ? (isLightMode
                ? borderColor.withOpacity(0.15)
                : borderColor.withOpacity(0.2))
            : Colors.transparent;

    final Color textColor =
        selected
            ? (isLightMode ? Colors.black87 : Colors.white)
            : (isLightMode ? Colors.black87 : Colors.white);

    final Color iconColor =
        selected
            ? (isLightMode ? Colors.black87 : borderColor)
            : (isLightMode ? Colors.black54 : Colors.white70);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          // PREMIUM LOCK CHECK
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? borderColor : borderColor.withOpacity(0.3),
                  width: selected ? 2 : 1,
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: <Widget>[
                    Icon(icon, color: iconColor, size: 20),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isPremium)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.lock, size: 10, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPremiumLockDialog(BuildContext context, String themeName) {
    showDialog(
      context: context,
      builder:
          (BuildContext context) => AlertDialog(
            backgroundColor: Theme.of(context).cardTheme.color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  loc.premiumFeature,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Text(
              loc.premiumFeatureDesc(themeName),
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  loc.close,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onGoPremium?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                child: Text(loc.goPremium),
              ),
            ],
          ),
    );
  }
}
