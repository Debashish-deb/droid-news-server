import 'dart:async';
import 'dart:io';

import '../../../core/di/providers.dart';
import '../../../core/config/premium_plans.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import '../../../infrastructure/services/notifications/push_notification_service.dart';

import '../../../core/theme/app_icons.dart' show AppIcons;
import '../../../core/navigation/app_paths.dart';
import '../../../core/enums/theme_mode.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/number_localization.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/app_settings_providers.dart';
import '../../providers/language_providers.dart';
import '../../providers/premium_providers.dart'
    show isPremiumStateProvider, shouldShowAdsProvider;
import '../../providers/saved_articles_provider.dart'
    show savedArticlesProvider;
import '../../providers/theme_providers.dart'
    show currentThemeModeProvider, themeProvider;
import '../../widgets/app_drawer.dart' show AppDrawer;
import '../../widgets/banner_ad_widget.dart' show BannerAdWidget;
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  ProductDetails? _proLifetimeProduct;
  ProductDetails? _proYearlyProduct;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _storeAvailable = false;

  String _version = '';
  bool _clearingCache = false;

  static const List<String> _newsCategoryCacheKeys = <String>[
    'latest', 'trending', 'national', 'international', 
    'sports', 'entertainment', 'technology', 'economy', 'magazine',
  ];

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _setupStore();
    _listenToPurchases();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  Future<void> _setupStore() async {
    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable || !mounted) return;
    final response = await _iap.queryProductDetails(
      PremiumPlanConfig.primaryProductIds,
    );
    if (!mounted) return;
    final products = response.productDetails;
    ProductDetails? findById(String id) {
      for (final product in products) {
        if (product.id == id) return product;
      }
      return null;
    }

    setState(() {
      _proLifetimeProduct = findById(PremiumPlanConfig.proLifetimeProductId);
      _proYearlyProduct = findById(PremiumPlanConfig.proYearlyProductId);
    });
  }

  void _listenToPurchases() {
    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchases,
      onError: (e) => debugPrint('Purchase stream error: $e'),
    );
  }

  void _handlePurchases(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        unawaited(() async {
          final result = await ref
              .read(subscriptionRepositoryProvider)
              .processStorePurchase(p);
          result.fold(
            (failure) => _snack(failure.userMessage),
            (_) => _snack(loc.thankYouPurchase),
          );
        }());
      }
    }
  }

  void _buyRemoveAds() => context.push(AppPaths.subscriptionManagement);

  Future<void> _launchPaypal() async {
    final id = dotenv.env['PAYPAL_BUTTON_ID'] ?? '';
    if (id.isEmpty) return;
    final url = Uri.parse('https://www.paypal.com/donate?hosted_button_id=$id');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _clearCache() async {
    if (_clearingCache) return;
    setState(() => _clearingCache = true);
    var cleared = 0;
    final beforeBytes = await _estimateCacheFootprintBytes();

    Future<void> runStep(Future<void> Function() step) async {
      try {
        await step();
        cleared++;
      } catch (e) {
        debugPrint('Cache clear error: $e');
      }
    }

    await runStep(() async {
      await DefaultCacheManager().emptyCache();
      imageCache.clear();
      imageCache.clearLiveImages();
      await InAppWebViewController.clearAllCache();
      await CookieManager.instance().deleteAllCookies();
      await WebStorageManager.instance().deleteAllData();
    });

    await runStep(_clearNewsHiveCacheBoxes);
    await runStep(() async => await ref.read(savedArticlesProvider.notifier).clearAll());
    await runStep(() async => await ref.read(ttsDatabaseProvider).clearCache());
    await runStep(() async => await ref.read(audioCacheProvider).clearCache());
    await runStep(() async {
      final db = ref.read(appDatabaseProvider);
      await db.delete(db.articles).go();
      await db.delete(db.syncJournal).go();
    });

    final afterBytes = await _estimateCacheFootprintBytes();
    final freed = (beforeBytes - afterBytes).clamp(0, 1 << 50);

    if (mounted) {
      _snack('${loc.clearCacheSuccess} ${_formatBytes(freed)} freed');
      setState(() => _clearingCache = false);
    }
  }

  Future<void> _clearNewsHiveCacheBoxes() async {
    final names = <String>{
      ..._newsCategoryCacheKeys,
      ..._newsCategoryCacheKeys.map((key) => '${key}_meta'),
    };
    for (final name in names) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box<dynamic>(name).clear();
      } else if (await Hive.boxExists(name)) {
        final box = await Hive.openBox<dynamic>(name);
        try {
          await box.clear();
        } finally {
          await box.close();
        }
      }
    }
  }

  Future<int> _estimateCacheFootprintBytes() async {
    final dirs = <Directory?>[
      await getTemporaryDirectory(),
      if (!kIsWeb) await getApplicationCacheDirectory(),
    ];
    var total = 0;
    for (final dir in dirs) {
      if (dir == null) continue;
      try {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            try {
              total += await entity.length();
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
    return total;
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        width: 300,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  AppLocalizations get loc => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumStateProvider);
    final shouldShowAds = ref.watch(shouldShowAdsProvider);
    final settings = ref.watch(appSettingsProvider);
    final themeMode = normalizeThemeMode(ref.watch(currentThemeModeProvider));
    final langCode = ref.watch(languageCodeProvider);
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return Scaffold(
      backgroundColor: colors.bg,
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(loc.settings, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.bg, colors.bg.withOpacity(0.95)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  
                  // Banner Ad or Spacer
                  if (shouldShowAds) ...[
                    const SizedBox(height: 60, child: BannerAdWidget()),
                    const SizedBox(height: 24),
                  ] else
                    const SizedBox(height: 16),

                  // Premium Status (Full Width)
                  if (isPremium)
                    _buildPremiumBanner(colors)
                  else
                    _buildUpgradeBanner(colors),
                  
                  const SizedBox(height: 32),

                  // Section Title
                  _buildSectionTitle('Appearance'),
                  const SizedBox(height: 12),
                  
                  // Theme Row (Full Width)
                  _buildSettingsTile(
                    icon: Icons.palette_rounded,
                    iconColor: colors.proBlue,
                    title: loc.theme,
                    subtitle: _getThemeLabel(themeMode),
                    onTap: () => _showThemePicker(themeMode, colors),
                    colors: colors,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Language Row (Full Width)
                  _buildSettingsTile(
                    icon: Icons.language_rounded,
                    iconColor: colors.proBlue,
                    title: loc.language,
                    subtitle: langCode.toLowerCase() == 'en' ? 'English' : 'বাংলা',
                    onTap: () => _showLanguagePicker(langCode, colors),
                    colors: colors,
                  ),

                  const SizedBox(height: 32),
                  _buildSectionTitle('Preferences'),
                  const SizedBox(height: 12),

                  // Data Saver Row (Full Width)
                  _buildToggleTile(
                    icon: AppIcons.download,
                    iconColor: Colors.orange,
                    title: loc.dataSaver,
                    subtitle: 'Reduce data usage',
                    value: settings.dataSaver,
                    onChanged: (v) => ref.read(appSettingsProvider.notifier).setDataSaver(v),
                    colors: colors,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Notifications Row (Full Width)
                  _buildToggleTile(
                    icon: AppIcons.notification,
                    iconColor: Colors.green,
                    title: loc.btnNotifications,
                    subtitle: 'Push notification settings',
                    value: settings.pushNotif,
                    onChanged: (v) {
                      ref.read(appSettingsProvider.notifier).setPushNotif(v);
                      if (v) PushNotificationService.openNotificationSettings();
                    },
                    colors: colors,
                  ),

                  const SizedBox(height: 32),
                  _buildSectionTitle('System'),
                  const SizedBox(height: 12),

                  // Privacy Row (Full Width)
                  _buildSettingsTile(
                    icon: Icons.security_rounded,
                    iconColor: Colors.purple,
                    title: loc.btnPrivacy,
                    subtitle: 'Privacy policy & terms',
                    onTap: () => context.push(AppPaths.privacy),
                    colors: colors,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Clear Cache Row (Full Width)
                  _buildActionTile(
                    icon: AppIcons.delete,
                    iconColor: Colors.red,
                    title: loc.clearCache,
                    subtitle: 'Free up storage space',
                    isLoading: _clearingCache,
                    onTap: _clearingCache ? null : _clearCache,
                    colors: colors,
                  ),

                  const SizedBox(height: 40),
                  
                  // Version Footer
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'v${localizeNumber(_version, langCode)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.textHint,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '© ${localizeNumber(DateTime.now().year.toString(), langCode)} DreamSD Group',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textHint.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: Theme.of(context).extension<AppColorsExtension>()!.textHint,
      ),
    );
  }

  Widget _buildPremiumBanner(AppColorsExtension colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.goldStart.withOpacity(0.15),
            colors.goldMid.withOpacity(0.08),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.goldStart.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.goldStart,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colors.goldStart.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.diamond_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium Active',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All features unlocked • No ads',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.goldStart.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'PRO',
              style: TextStyle(
                color: colors.goldStart,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeBanner(AppColorsExtension colors) {
    final lifetime = _proLifetimeProduct?.price ?? PremiumPlanConfig.proLifetimeDisplayPrice;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.proBlue.withOpacity(0.15),
            colors.proBlue.withOpacity(0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.proBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.proBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to Premium',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Remove ads & unlock all themes',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _buyRemoveAds,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.proBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Upgrade $lifetime',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _launchPaypal,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  side: BorderSide(color: colors.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Donate'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required AppColorsExtension colors,
  }) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: colors.cardBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: colors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required AppColorsExtension colors,
  }) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: value ? iconColor.withOpacity(0.5) : colors.cardBorder,
              width: value ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(value ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: iconColor,
                activeTrackColor: iconColor.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required AppColorsExtension colors,
    bool isLoading = false,
  }) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: colors.cardBorder),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: iconColor,
                          ),
                        ),
                      )
                    : Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLoading)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: colors.textHint,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemePicker(AppThemeMode current, AppColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textHint.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                loc.theme,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _ThemeOption(
                icon: Icons.settings_system_daydream_rounded,
                label: 'System Default',
                description: 'Follows device settings',
                selected: current == AppThemeMode.system,
                onTap: () {
                  ref.read(themeProvider.notifier).setTheme(AppThemeMode.system);
                  Navigator.pop(context);
                },
                colors: colors,
              ),
              const SizedBox(height: 12),
              _ThemeOption(
                icon: Icons.dark_mode_rounded,
                label: 'AMOLED Dark',
                description: 'Pure black for OLED screens',
                selected: current == AppThemeMode.amoled,
                onTap: () {
                  ref.read(themeProvider.notifier).setTheme(AppThemeMode.amoled);
                  Navigator.pop(context);
                },
                colors: colors,
              ),
              const SizedBox(height: 12),
              _ThemeOption(
                icon: AppIcons.flag,
                label: 'Bangladesh Theme',
                description: 'Green & red patriotic theme',
                selected: current == AppThemeMode.bangladesh,
                isPremium: true,
                onTap: () {
                  final isPremium = ref.read(isPremiumStateProvider);
                  if (!isPremium) {
                    Navigator.pop(context);
                    _buyRemoveAds();
                  } else {
                    ref.read(themeProvider.notifier).setTheme(AppThemeMode.bangladesh);
                    Navigator.pop(context);
                  }
                },
                colors: colors,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguagePicker(String currentLang, AppColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textHint.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                loc.language,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _LanguageOption(
                flag: '🇺🇸',
                label: 'English',
                selected: currentLang.toLowerCase() == 'en',
                onTap: () {
                  ref.read(languageProvider.notifier).setLanguage('en');
                  Navigator.pop(context);
                },
                colors: colors,
              ),
              const SizedBox(height: 12),
              _LanguageOption(
                flag: '🇧🇩',
                label: 'বাংলা',
                selected: currentLang.toLowerCase() == 'bn',
                onTap: () {
                  ref.read(languageProvider.notifier).setLanguage('bn');
                  Navigator.pop(context);
                },
                colors: colors,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getThemeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'System Default';
      case AppThemeMode.amoled:
        return 'AMOLED Dark';
      case AppThemeMode.bangladesh:
        return 'Bangladesh Theme';
      default:
        return 'System Default';
    }
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final bool isPremium;
  final VoidCallback onTap;
  final AppColorsExtension colors;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    this.isPremium = false,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colors.proBlue.withOpacity(0.1) : colors.bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? colors.proBlue.withOpacity(0.5) : colors.cardBorder,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? colors.proBlue : colors.textSecondary, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        if (isPremium) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.goldStart.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'PRO',
                              style: TextStyle(
                                color: colors.goldStart,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: colors.proBlue, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String flag;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppColorsExtension colors;

  const _LanguageOption({
    required this.flag,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colors.proBlue.withOpacity(0.1) : colors.bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? colors.proBlue.withOpacity(0.5) : colors.cardBorder,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: colors.proBlue, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

extension _ColorsExt on BuildContext {
  AppColorsExtension get colors => Theme.of(this).extension<AppColorsExtension>()!;
}