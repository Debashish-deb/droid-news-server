// File: lib/screens/settings_screen.dart

import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../core/language_provider.dart';
import '../../core/premium_service.dart';
import '/l10n/app_localizations.dart';
import '../../widgets/app_drawer.dart';
import '../../features/common/appBar.dart';
import '../../widgets/banner_ad_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  bool _isClearingCache = false;
  final InAppPurchase _iap = InAppPurchase.instance;
  ProductDetails? _removeAdsProduct;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _initializeIAP();
    _subscription = _iap.purchaseStream.listen(_onPurchase);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _version = info.version);
  }

  Future<void> _initializeIAP() async {
    if (!await _iap.isAvailable()) return;
    const ids = {'remove_ads'};
    final response = await _iap.queryProductDetails(ids);
    if (response.productDetails.isNotEmpty) {
      setState(() => _removeAdsProduct = response.productDetails.first);
    }
  }

  void _onPurchase(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased && purchase.productID == 'remove_ads') {
        context.read<PremiumService>().setPremium(true);
      }
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _buyRemoveAds() async {
    if (_removeAdsProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.productNotAvailable)),
      );
      return;
    }
    final param = PurchaseParam(productDetails: _removeAdsProduct!);
    _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> _launchPaypal() async {
    final id = dotenv.env['PAYPAL_BUTTON_ID'] ?? '';
    if (id.isEmpty) return;
    final url = Uri.parse('https://www.paypal.com/donate?hosted_button_id=$id');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _rateApp() async {
    const pkg = 'com.bd.bdnewsreader';
    final url = Uri.parse('https://play.google.com/store/apps/details?id=$pkg');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);
    await DefaultCacheManager().emptyCache();
    if (!mounted) return;
    setState(() => _isClearingCache = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.clearCacheSuccess)),
    );
  }

  Future<void> _contactSupport() async {
    final email = AppLocalizations.of(context)!.contactEmail;
    await launchUrl(Uri.parse('mailto:$email'), mode: LaunchMode.externalApplication);
  }

  Widget _glassWrap(Widget child) {
    final prov = context.watch<ThemeProvider>();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: prov.glassDecoration(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.all(20),
            color: prov.glassColor,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _settingHeader(String label, Color color) =>
      Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color));

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final isPremium = context.watch<PremiumService>().isPremium;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: theme.appBarTheme.elevation ?? 0,
        title: AppBarTitle(loc.settings),
        iconTheme: theme.appBarTheme.iconTheme,
        titleTextStyle: theme.appBarTheme.titleTextStyle,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isPremium) const BannerAdWidget(),

              _glassWrap(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _settingHeader(loc.theme, textColor),
                  const SizedBox(height: 12),
                  Row(children: [
                    _themeBtn(AppThemeMode.light, Icons.wb_sunny, loc.lightTheme, textColor),
                    const SizedBox(width: 8),
                    _themeBtn(AppThemeMode.dark, Icons.nights_stay, loc.darkTheme, textColor),
                    const SizedBox(width: 8),
                    _themeBtn(AppThemeMode.bangladesh, Icons.flag, loc.bangladeshTheme, textColor),
                  ]),
                ],
              )),

              _glassWrap(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _settingHeader(loc.language, textColor),
                  const SizedBox(height: 12),
                  Row(children: [
                    _langBtn('en', 'English', textColor),
                    const SizedBox(width: 8),
                    _langBtn('bn', 'বাংলা', textColor),
                  ]),
                ],
              )),

              _glassWrap(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _settingHeader(loc.adFree, textColor),
                  const SizedBox(height: 12),
                  if (isPremium)
                    Text(loc.adsRemoved, style: TextStyle(color: textColor))
                  else
                    Wrap(
                      spacing: 8,
                      children: [
                        if (_removeAdsProduct != null)
                          OutlinedButton.icon(
                            key: const ValueKey('remove-ads-btn'),
                            onPressed: _buyRemoveAds,
                            icon: const Icon(Icons.payment),
                            label: Text('${loc.removeAds} • ${_removeAdsProduct!.price}'),
                          ),
                        OutlinedButton.icon(
                          key: const ValueKey('paypal-donate-btn'),
                          onPressed: _launchPaypal,
                          icon: const Icon(Icons.attach_money),
                          label: Text(loc.paypalDonate),
                        ),
                      ],
                    ),
                ],
              )),

              _glassWrap(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _settingHeader(loc.misc, textColor),
                  ListTile(
                    leading: Icon(Icons.cleaning_services, color: textColor),
                    title: Text(loc.clearCache, style: TextStyle(color: textColor)),
                    trailing: _isClearingCache
                        ? CircularProgressIndicator(strokeWidth: 2)
                        : IconButton(icon: Icon(Icons.delete, color: textColor), onPressed: _clearCache),
                  ),
                  ListTile(
                    leading: Icon(Icons.star_rate, color: textColor),
                    title: Text(loc.rateApp, style: TextStyle(color: textColor)),
                    trailing: IconButton(icon: Icon(Icons.chevron_right, color: textColor), onPressed: _rateApp),
                  ),
                  ListTile(
                    leading: Icon(Icons.support_agent, color: textColor),
                    title: Text(loc.contactSupport, style: TextStyle(color: textColor)),
                    subtitle: Text(loc.contactEmail, style: TextStyle(color: textColor.withOpacity(0.7))),
                    trailing: IconButton(icon: Icon(Icons.chevron_right, color: textColor), onPressed: _contactSupport),
                  ),
                ],
              )),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  '${loc.versionPrefix} $_version',
                  style: TextStyle(color: textColor.withOpacity(0.7), fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeBtn(AppThemeMode mode, IconData icon, String label, Color textColor) {
    final prov = context.read<ThemeProvider>();
    final selected = prov.appThemeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => prov.toggleTheme(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: selected ? LinearGradient(colors: AppGradients.getGradientColors(mode)) : null,
            border: Border.all(color: prov.borderColor, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : textColor),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: selected ? Colors.white : textColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langBtn(String code, String label, Color textColor) {
    final langProv = context.read<LanguageProvider>();
    final selected = langProv.locale.languageCode == code;
    final prov = context.read<ThemeProvider>();
    return Expanded(
      child: GestureDetector(
        onTap: () => langProv.setLocale(code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: selected ? LinearGradient(colors: AppGradients.getGradientColors(prov.appThemeMode)) : null,
            border: Border.all(color: prov.borderColor, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(child: Text(label, style: TextStyle(color: selected ? Colors.white : textColor))),
        ),
      ),
    );
  }
}
