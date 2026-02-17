import 'dart:async';
import 'dart:ui' show ImageFilter;

import '../../../core/di/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/app_icons.dart' show AppIcons;
import '../../../core/design_tokens.dart';
import '../../../core/app_paths.dart';
import '../../../core/enums/theme_mode.dart';
import '../../../core/theme.dart';
import '../../../core/utils/number_localization.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/app_settings_providers.dart';
import '../../providers/language_providers.dart' show currentLocaleProvider, languageCodeProvider, languageProvider;
import '../../providers/premium_providers.dart' show isPremiumProvider, isPremiumStateProvider;
import '../../providers/theme_providers.dart' show currentThemeModeProvider, themeProvider;
import '../../widgets/animated_theme_container.dart' show AnimatedThemeContainer;
import '../../widgets/app_drawer.dart' show AppDrawer;
import '../../widgets/banner_ad_widget.dart' show BannerAdWidget;
import '../common/app_bar.dart' show AppBarTitle;
import 'widgets/settings_3d_widgets.dart';
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
        ref.read(premiumRepositoryProvider).setPremium(true);
        _snack(loc.thankYouPurchase);
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
      _snack('${loc.clearCacheSuccess} ${loc.cacheClearedCount(clearedCount)}');
    } catch (e) {
      debugPrint('❌ Cache clear error: $e');
      if (!mounted) return;

      setState(() => _isClearingCache = false);
      _snack(loc.errorClearingCache(e.toString()));
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
      margin: const EdgeInsets.symmetric(vertical: 3),
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
                  padding: const EdgeInsets.all(6),
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

    final theme = Theme.of(context);
    final headerBgColor = theme.scaffoldBackgroundColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
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
          // Header Text with Theme-Matched Background
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              color: headerBgColor.withOpacity(0.9), // Match theme background color
              child: Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
    final theme = Theme.of(context);
    final isPremium = ref.watch(isPremiumProvider).valueOrNull ?? false;
    final settings = ref.watch(appSettingsProvider);
    final currentThemeMode = ref.watch(currentThemeModeProvider);

    final colors = AppGradients.getBackgroundGradient(currentThemeMode);
    final scheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: AppBarTitle(loc.settings),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: scheme.surface.withOpacity(0.7),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedThemeContainer(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors[0].withOpacity(0.9),
                    colors[1].withOpacity(0.9),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
               if (!isPremium) _glass(const BannerAdWidget()),

              _glass(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(loc.theme, theme.colorScheme.primary),
                    _ThemeSelector(
                      current: currentThemeMode,
                      onChanged: (m) => ref.read(themeProvider.notifier).setTheme(m),
                      loc: loc,
                      onGoPremium: _buyRemoveAds,
                    ),
                  ],
                ),
              ),

              _glass(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(loc.language, theme.colorScheme.primary),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _lang('en', 'English'),
                        _lang('bn', 'বাংলা'),
                      ],
                    ),
                  ],
                ),
              ),

              _glass(
                Column(
                  children: [
                    _header(loc.adFree, theme.colorScheme.primary),
                    if (isPremium)
                      Settings3DButton(
                        onTap: () {},
                        label: loc.adsRemoved,
                        icon: Icons.verified_user_rounded,
                        isSelected: true,
                        width: double.infinity,
                      )
                    else
                      Row(
                        children: [
                          if (_removeAdsProduct != null)
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: _buyRemoveAds,
                                child: Text(_removeAdsProduct!.price),
                              ),
                            ),
                          if (_removeAdsProduct != null) const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _launchPaypal,
                              child: Text(loc.btnDonate),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              _glass(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(loc.misc, theme.colorScheme.primary),
                    Row(
                      children: [
                        Expanded(
                          child: Settings3DButton(
                            onTap: () => ref.read(appSettingsProvider.notifier).setDataSaver(!settings.dataSaver),
                            label: loc.dataSaver,
                            icon: AppIcons.download,
                            isSelected: settings.dataSaver,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Settings3DButton(
                            onTap: () => ref.read(appSettingsProvider.notifier).setPushNotif(!settings.pushNotif),
                            label: loc.btnNotifications,
                            icon: AppIcons.notification,
                            isSelected: settings.pushNotif,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              _glass(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(loc.btnPrivacy, theme.colorScheme.primary),
                    Row(
                      children: [
                        Expanded(
                          child: Settings3DButton(
                            onTap: () => context.push('/privacy'),
                            label: loc.btnPrivacy,
                            icon: Icons.security_rounded,
                            isSelected: false,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Settings3DButton(
                            onTap: _isClearingCache ? () {} : () => _clearCache(),
                            label: loc.btnCache,
                            icon: AppIcons.delete,
                            isSelected: false,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: Opacity(
                  opacity: 0.5,
                  child: Text(
                    '${loc.versionPrefix} ${localizeNumber(_version, ref.watch(languageCodeProvider))}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
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
      width: width ?? 140, // More compact for horizontal row
      fontSize: 13,
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
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: _item(
            context,
            AppThemeMode.light,
            loc.themeLightLabel,
            AppIcons.lightMode,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _item(
            context,
            AppThemeMode.dark,
            loc.themeDarkLabel,
            AppIcons.darkMode,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _item(
            context,
            AppThemeMode.bangladesh,
            loc.themeDeshLabel,
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
                final bool userIsPremium = container.read(isPremiumStateProvider);
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
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.stars_rounded, color: theme.colorScheme.primary, size: 48),
        title: Text(loc.premiumFeature),
        content: Text(
          loc.premiumFeatureDesc(themeName),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.close),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onGoPremium?.call();
            },
            child: Text(loc.goPremium),
          ),
        ],
      ),
    );
  }
}