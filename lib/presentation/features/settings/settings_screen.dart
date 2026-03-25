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
    show
        entitlementSnapshotProvider,
        isPremiumStateProvider,
        shouldShowAdsProvider;
import '../../providers/saved_articles_provider.dart'
    show savedArticlesProvider;
import '../../providers/theme_providers.dart'
    show currentThemeModeProvider, themeProvider;
import '../../providers/tab_providers.dart';
import '../../widgets/app_drawer.dart' show AppDrawer;
import '../../widgets/banner_ad_widget.dart' show BannerAdWidget;
import 'package:go_router/go_router.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────

extension _CtxColors on BuildContext {
  AppColorsExtension get colors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}

// ─── Screen ─────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with TickerProviderStateMixin {
  final InAppPurchase _iap = InAppPurchase.instance;
  ProductDetails? _proLifetimeProduct;
  ProductDetails? _proYearlyProduct;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _storeAvailable = false;

  String _version = '';
  bool _clearingCache = false;

  static const List<String> _newsCategoryCacheKeys = <String>[
    'latest',
    'trending',
    'national',
    'international',
    'sports',
    'entertainment',
    'technology',
    'economy',
    'magazine',
  ];

  final ScrollController _scrollController = ScrollController();

  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _setupStore();
    _listenToPurchases();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = const AlwaysStoppedAnimation(Offset.zero);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entryCtrl.forward();
    });

    ref.listenManual<int>(currentTabIndexProvider, (prev, next) {
      if (next == 4 && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _scrollController.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    final failures = <String>[];
    final beforeBytes = await _estimateCacheFootprintBytes();

    Future<void> runStep(String name, Future<void> Function() step) async {
      try {
        await step();
        cleared++;
      } catch (e, s) {
        failures.add('$name: $e');
        debugPrint('⚠️ Cache clear step failed ($name): $e\n$s');
      }
    }

    try {
      await runStep('File cache', () async {
        await DefaultCacheManager().emptyCache();
      });

      await runStep('Image cache', () async {
        imageCache.clear();
        imageCache.clearLiveImages();
      });

      await runStep('WebView cache', () async {
        await InAppWebViewController.clearAllCache();
      });

      await runStep('WebView cookies', () async {
        await CookieManager.instance().deleteAllCookies();
      });

      await runStep('WebView storage', () async {
        await WebStorageManager.instance().deleteAllData();
      });

      await runStep('News Hive cache', _clearNewsHiveCacheBoxes);

      await runStep('Offline saved articles', () async {
        await ref.read(savedArticlesProvider.notifier).clearAll();
      });

      await runStep('TTS sqlite cache', () async {
        await ref.read(ttsDatabaseProvider).clearCache();
      });

      await runStep('TTS audio cache', () async {
        await ref.read(audioCacheProvider).clearCache();
      });

      await runStep('Local news database', () async {
        final db = ref.read(appDatabaseProvider);
        await db.delete(db.articles).go();
        await db.delete(db.syncJournal).go();
        await db.delete(db.syncSnapshots).go();
      });

      final afterBytes = await _estimateCacheFootprintBytes();
      final freedBytes = (beforeBytes - afterBytes).clamp(0, 1 << 50);

      if (!mounted) return;
      if (failures.isEmpty) {
        _snack(
          '${loc.clearCacheSuccess} ${loc.cacheClearedCount(cleared)} '
          '(${_formatBytes(freedBytes)} freed)',
        );
      } else {
        _snack(
          '${loc.clearCacheSuccess} ${loc.cacheClearedCount(cleared)} '
          '(${_formatBytes(freedBytes)} freed, ${failures.length} cleanup steps failed)',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _snack(loc.errorClearingCache(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _clearingCache = false);
      }
    }
  }

  Future<void> _clearNewsHiveCacheBoxes() async {
    final names = <String>{
      ..._newsCategoryCacheKeys,
      ..._newsCategoryCacheKeys.map((key) => '${key}_meta'),
      'latest_meta',
      'trending_meta',
    };

    for (final name in names) {
      await _clearHiveBoxIfExists(name);
    }
  }

  Future<void> _clearHiveBoxIfExists(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box<dynamic>(boxName);
      await box.clear();
      return;
    }

    final exists = await Hive.boxExists(boxName);
    if (!exists) return;

    final box = await Hive.openBox<dynamic>(boxName);
    try {
      await box.clear();
    } finally {
      await box.close();
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
      total += await _safeDirectorySize(dir);
    }
    return total;
  }

  Future<int> _safeDirectorySize(Directory directory) async {
    try {
      if (!await directory.exists()) return 0;
      var bytes = 0;
      await for (final entity in directory.list(recursive: true)) {
        if (entity is! File) continue;
        try {
          bytes += await entity.length();
        } catch (_) {
          // Ignore unreadable files while estimating.
        }
      }
      return bytes;
    } catch (_) {
      return 0;
    }
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final precision = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
    return '${value.toStringAsFixed(precision)} ${units[unit]}';
  }

  void _snack(String msg) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onInverseSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: scheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  AppLocalizations get loc => AppLocalizations.of(context);

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumStateProvider);
    final shouldShowAds = ref.watch(shouldShowAdsProvider);
    final settings = ref.watch(appSettingsProvider);
    final themeMode = normalizeThemeMode(ref.watch(currentThemeModeProvider));
    final langCode = ref.watch(languageCodeProvider);
    final topInset = MediaQuery.paddingOf(context).top;
    final topSpacer = topInset + 72;

    return Scaffold(
      backgroundColor: context.colors.bg,
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      appBar: _SettingsAppBar(title: loc.settings),
      body: FadeTransition(
        opacity: _entryFade,
        child: SlideTransition(
          position: _entrySlide,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: topSpacer)),

              // ── Premium Ad-free banner OR Ad ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: shouldShowAds
                      ? const _Card(child: BannerAdWidget())
                      : const SizedBox.shrink(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 4.0)),

              // ── Theme ──
              SliverToBoxAdapter(
                child: _Section(
                  label: loc.theme,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: _ThemeSelector(
                    current: themeMode,
                    onChanged: (m) =>
                        ref.read(themeProvider.notifier).setTheme(m),
                    loc: loc,
                    onGoPremium: _buyRemoveAds,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 4.0)),

              // ── Language ──
              SliverToBoxAdapter(
                child: _Section(
                  label: loc.language,
                  child: Row(
                    children: [
                      Expanded(child: _langBtn('en', 'English')),
                      const SizedBox(width: 8),
                      Expanded(child: _langBtn('bn', 'বাংলা')),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 4.0)),

              // ── Premium / Ad-free ──
              SliverToBoxAdapter(
                child: _Section(
                  label: loc.adFree,
                  child: isPremium
                      ? _PremiumConfirmedRow(loc: loc)
                      : _UpgradeRow(
                          lifetimePrice:
                              _proLifetimeProduct?.price ??
                              PremiumPlanConfig.proLifetimeDisplayPrice,
                          yearlyPrice:
                              _proYearlyProduct?.price ??
                              PremiumPlanConfig.proYearlyDisplayPrice,
                          onUpgrade: _buyRemoveAds,
                          onDonate: _launchPaypal,
                          loc: loc,
                        ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 4.0)),

              // ── Misc ──
              SliverToBoxAdapter(
                child: _Section(
                  label: loc.misc,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _ToggleTile(
                          icon: AppIcons.download,
                          label: loc.dataSaver,
                          value: settings.dataSaver,
                          onChanged: (v) => ref
                              .read(appSettingsProvider.notifier)
                              .setDataSaver(v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: _ToggleTile(
                          icon: AppIcons.notification,
                          label: loc.btnNotifications,
                          value: settings.pushNotif,
                          onChanged: (v) {
                            ref
                                .read(appSettingsProvider.notifier)
                                .setPushNotif(v);
                            if (v) {
                              unawaited(
                                PushNotificationService.openNotificationSettings(),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 4.0)),

              // ── Privacy & Cache ──
              SliverToBoxAdapter(
                child: _Section(
                  label: loc.btnPrivacy,
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.security_rounded,
                          label: loc.btnPrivacy,
                          onTap: () => context.push(AppPaths.privacy),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionTile(
                          icon: AppIcons.delete,
                          label: loc.clearCache,
                          isLoading: _clearingCache,
                          onTap: _clearingCache ? null : _clearCache,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Version ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
                  child: Column(
                    children: [
                      Text(
                        '${loc.versionPrefix} ${localizeNumber(_version, langCode)}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langBtn(String code, String label) {
    final locale = ref.watch(currentLocaleProvider);
    final selected = locale.languageCode.toLowerCase() == code;
    return _SelectTile(
      icon: code == 'en' ? Icons.language_rounded : AppIcons.flag,
      label: label,
      selected: selected,
      onTap: () => ref.read(languageProvider.notifier).setLanguage(code),
    );
  }
}

// ─── App Bar ─────────────────────────────────────────────────────────────────

class _SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SettingsAppBar({required this.title});
  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarBg = context.colors.bg;
    return ColoredBox(
      color: appBarBg,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: appBarBg,
            border: Border(
              bottom: BorderSide(color: context.colors.cardBorder),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 4,
                child: Builder(
                  builder: (ctx) => IconButton(
                    icon: Icon(
                      Icons.menu_rounded,
                      size: 22,
                      color: context.colors.textPrimary,
                    ),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Ad-Free Banner (premium users only) ─────────────────────────────────────

// ─── Section Wrapper ──────────────────────────────────────────────────────────

// ─── Section Wrapper ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child, this.padding});
  final String label;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: context.colors.textHint,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
              ),
            ),
          ),
          _Card(padding: padding, child: child),
        ],
      ),
    );
  }
}

// ─── Card Container ───────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: child,
    );
  }
}

// ─── Premium Confirmed Row ────────────────────────────────────────────────────

class _PremiumConfirmedRow extends StatelessWidget {
  const _PremiumConfirmedRow({required this.loc});
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [context.colors.goldStart, context.colors.goldMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: context.colors.goldGlow, blurRadius: 12),
            ],
          ),
          child: const Icon(
            Icons.diamond_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.adsRemoved,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Premium plan active',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: context.colors.goldStart.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.colors.goldStart.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            'PRO',
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.colors.goldStart,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Upgrade Row ──────────────────────────────────────────────────────────────

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({
    required this.lifetimePrice,
    required this.yearlyPrice,
    required this.onUpgrade,
    required this.onDonate,
    required this.loc,
  });
  final String lifetimePrice;
  final String yearlyPrice;
  final VoidCallback onUpgrade;
  final VoidCallback onDonate;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OutlineBtn(
            label: '$lifetimePrice | $yearlyPrice',
            icon: Icons.bolt_rounded,
            accent: context.colors.proBlue,
            onTap: onUpgrade,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _OutlineBtn(
            label: loc.btnDonate,
            icon: Icons.volunteer_activism_rounded,
            accent: context.colors.goldStart,
            onTap: onDonate,
          ),
        ),
      ],
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = scheme.onSurface;
    final borderColor = scheme.outline.withValues(alpha: 0.65);
    final surface = Color.alphaBlend(
      accent.withValues(alpha: 0.08),
      scheme.surface.withValues(alpha: 0.95),
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foreground, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                  fontSize: (theme.textTheme.labelLarge?.fontSize ?? 14) - 1,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Toggle Tile ──────────────────────────────────────────────────────────────

// ─── Compact Selection Tile (Boolean) ─────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = scheme.onSurface;

    final activeColor = foreground;
    final activeBg = foreground.withValues(alpha: 0.12);
    final activeBorder = scheme.outline.withValues(alpha: 0.9);

    final inactiveColor = foreground.withValues(alpha: 0.92);
    final inactiveBg = scheme.surface;
    final inactiveBorder = scheme.outline.withValues(alpha: 0.7);

    final color = value ? activeColor : inactiveColor;
    final bg = value ? activeBg : inactiveBg;
    final border = value ? activeBorder : inactiveBorder;
    final weight = value ? FontWeight.w700 : FontWeight.w500;

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: value ? 1.5 : 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: value ? foreground : inactiveColor,
                  fontWeight: weight,
                  fontSize: (theme.textTheme.labelLarge?.fontSize ?? 14) - 1.5,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action Tile ──────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.isLoading = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = scheme.onSurface;
    final borderColor = scheme.outline.withValues(alpha: 0.7);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48, // Compact height matching theme tile
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: foreground.withValues(alpha: 0.92),
                ),
              )
            else
              Icon(icon, size: 18, color: foreground.withValues(alpha: 0.92)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                  fontSize: (theme.textTheme.labelLarge?.fontSize ?? 14) - 1.5,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Select Tile (Language) ───────────────────────────────────────────────────

class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = scheme.onSurface;
    final borderColor = scheme.outline.withValues(alpha: 0.75);
    final selectedBg = foreground.withValues(alpha: 0.12);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? selectedBg : scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: foreground.withValues(alpha: selected ? 1.0 : 0.92),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground.withValues(alpha: selected ? 1.0 : 0.92),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: (theme.textTheme.labelLarge?.fontSize ?? 14) - 1.5,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Theme Selector ───────────────────────────────────────────────────────────

// ─── Theme Selector ───────────────────────────────────────────────────────────

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

  static const _modes = [
    (AppThemeMode.system, Icons.settings_system_daydream_rounded, false),
    (AppThemeMode.amoled, Icons.dark_mode_rounded, false),
    (AppThemeMode.bangladesh, AppIcons.flag, true),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < _modes.length; i++) ...[
          Expanded(
            child: _ThemeTile(
              mode: _modes[i].$1,
              icon: _modes[i].$2,
              label: _labelFor(_modes[i].$1),
              locked: _modes[i].$3,
              current: current,
              onTap: () {
                if (_modes[i].$3) {
                  final isPremium = ProviderScope.containerOf(
                    context,
                  ).read(isPremiumStateProvider);
                  if (!isPremium) {
                    _showLock(context, _labelFor(_modes[i].$1));
                    return;
                  }
                }
                onChanged(_modes[i].$1);
              },
            ),
          ),
          if (i < _modes.length - 1) const SizedBox(width: 2),
        ],
      ],
    );
  }

  String _labelFor(AppThemeMode m) {
    switch (m) {
      case AppThemeMode.bangladesh:
        return loc.themeDeshLabel;
      case AppThemeMode.amoled:
        return 'AMOLED';
      case AppThemeMode.system:
        return 'Auto';
      case AppThemeMode.light:
      case AppThemeMode.dark:
        return 'Auto';
    }
  }

  void _showLock(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(
          Icons.stars_rounded,
          color: context.colors.goldStart,
          size: 44,
        ),
        title: Text(
          loc.premiumFeature,
          style: TextStyle(color: context.colors.textPrimary),
          textAlign: TextAlign.center,
        ),
        content: Text(
          loc.premiumFeatureDesc(name),
          style: TextStyle(color: context.colors.textSecondary),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              loc.close,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onGoPremium?.call();
            },
            child: Text(
              loc.goPremium,
              style: TextStyle(
                color: context.colors.goldStart,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.mode,
    required this.icon,
    required this.label,
    required this.locked,
    required this.current,
    required this.onTap,
  });

  final AppThemeMode mode;
  final IconData icon;
  final String label;
  final bool locked;
  final AppThemeMode current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = current == mode;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = scheme.onSurface;
    final accent = foreground.withValues(alpha: selected ? 1.0 : 0.92);
    final cardColor = selected
        ? foreground.withValues(alpha: 0.12)
        : scheme.surface;
    final borderColor = scheme.outline.withValues(alpha: 0.75);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: accent),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground.withValues(alpha: selected ? 1.0 : 0.92),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (locked)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD740), Color(0xFFFF9100)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.colors.card.withValues(alpha: 0.9),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 9,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Dark Theme ───────────────────────────────────────────────────────────────
