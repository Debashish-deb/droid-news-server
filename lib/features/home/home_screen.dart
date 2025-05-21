import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/pinned_http_client.dart';
import '../../core/theme_provider.dart';
import '../../core/theme.dart';
import '../../data/models/news_article.dart';
import '../../data/services/hive_service.dart';
import '../../data/services/rss_service.dart';
import '../../widgets/app_drawer.dart';
import '../../features/common/appBar.dart';
import '../home/widgets/news_card.dart';
import '../home/widgets/shimmer_loading.dart';
import '/l10n/app_localizations.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, RouteAware {
  late TabController _tabController;
  late List<String> _categoryKeys;
  late Map<String, String> _localizedLabels;
  final Map<String, List<NewsArticle>> _articles = {};
  final Map<String, bool> _loadingStatus = {};
  final Map<String, int> _articleLimit = {};
  final Map<String, ScrollController> _scrollControllers = {};

  Locale? _lastLocale;
  DateTime? _lastBackPressed;
  bool _isSlowConnection = false;

  bool _weatherLoading = true;
  String _weatherLocation = '';
  double? _weatherTemp;

  @override
  void initState() {
    super.initState();
    _checkNetworkSpeed();
    _loadWeather();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      routeObserver.subscribe(this, ModalRoute.of(context)!);
    });
  }

  Future<void> _checkNetworkSpeed() async {
    final result = await Connectivity().checkConnectivity();
    setState(() => _isSlowConnection = result != ConnectivityResult.wifi);
  }

  Future<void> _loadWeather() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      final Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      final apiKey = dotenv.env['WEATHER_API_KEY'] ?? '';
      if (apiKey.isEmpty) throw StateError('WEATHER_API_KEY not set');

      final uri = Uri.https('api.openweathermap.org', '/data/2.5/weather', {
        'lat': pos.latitude.toString(),
        'lon': pos.longitude.toString(),
        'units': 'metric',
        'appid': apiKey,
      });

      final client = await PinnedHttpClient.create('assets/certs/openweathermap.pem');
      try {
        final res = await client.get(uri).timeout(const Duration(seconds: 10));
        final jsonBody = jsonDecode(res.body);
        final name = jsonBody['name'];
        final main = jsonBody['main'];
        final tempRaw = main['temp'];
        final temp = tempRaw is num ? tempRaw.toDouble() : double.tryParse(tempRaw);

        if (!mounted) return;
        setState(() {
          _weatherLocation = name;
          _weatherTemp = temp;
          _weatherLoading = false;
        });
      } finally {
        client.close();
      }
    } on TimeoutException {
      _handleWeatherError();
    } catch (_) {
      _handleWeatherError();
    }
  }

  void _handleWeatherError() {
    if (!mounted) return;
    setState(() {
      _weatherLoading = false;
      _weatherTemp = null;
      _weatherLocation = '';
    });
    Fluttertoast.showToast(msg: 'Unable to load weather');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_lastLocale == locale && _articles.isNotEmpty) return;
    _lastLocale = locale;

    final loc = AppLocalizations.of(context)!;
    _categoryKeys = RssService.categories;
    _localizedLabels = {
      'latest': loc.latest,
      'national': loc.national,
      'international': loc.international,
      'lifestyle': loc.lifestyle,
    };
    _tabController = TabController(length: _categoryKeys.length, vsync: this)
      ..addListener(() => setState(() {}));

    for (final cat in _categoryKeys) {
      _scrollControllers[cat] = ScrollController()
        ..addListener(() => _onScroll(cat));
    }

    HiveService.init(_categoryKeys).then((_) => _loadOnlyExpiredFeeds());
  }

  void _onScroll(String cat) {
    final ctrl = _scrollControllers[cat]!;
    if (ctrl.position.pixels > ctrl.position.maxScrollExtent - 300 && !(_loadingStatus[cat] ?? false)) {
      _loadMore(cat);
    }
  }

  /// Updated: Loads feeds using NewsAPI or RSS as smart fallback
  Future<void> _loadOnlyExpiredFeeds() async {
    for (final key in _categoryKeys) {
      final expired = HiveService.isExpired(key);
      final hasData = HiveService.hasArticles(key);
      if (!expired && hasData) {
        _articles[key] = HiveService.getArticles(key);
        _articleLimit[key] = _isSlowConnection ? 5 : 15;
        _loadingStatus[key] = false;
      } else {
        _loadingStatus[key] = true;
        await _smartLoadFeedForKey(key);
      }
    }
    if (mounted) setState(() {});
  }

  /// Tries NewsAPI (via RssService) unless network is slow, then prefers RSS directly. Always falls back to RSS if NewsAPI fails.
  Future<void> _smartLoadFeedForKey(String key) async {
    final locale = Localizations.localeOf(context);
    List<NewsArticle> news = [];
    try {
      if (_isSlowConnection) {
        news = await RssService.fetchNews(
          category: key,
          locale: locale,
          context: context,
          preferRss: true,
        );
      } else {
        news = await RssService.fetchNews(
          category: key,
          locale: locale,
          context: context,
        );
      }
    } catch (_) {
      final rssList = RssService.rssFallbackForCategory(key);
      news = await RssService.fetchNews(
        category: key,
        locale: locale,
        context: context,
        preferRss: true,
      );
    }
    await HiveService.saveArticles(key, news);
    _articles[key] = news;
    _articleLimit[key] = _isSlowConnection ? 5 : 15;
    _loadingStatus[key] = false;
    if (mounted) setState(() {});
  }

  void _loadMore(String key) {
    final current = _articleLimit[key] ?? 10;
    final max = _articles[key]?.length ?? 0;
    if (current < max) {
      _articleLimit[key] = (current + 10).clamp(0, max);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _tabController.dispose();
    for (final ctrl in _scrollControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final prov = context.watch<ThemeProvider>();
    final colors = AppGradients.getGradientColors(prov.appThemeMode);
    final start = colors[0], end = colors[1];
    final key = _categoryKeys[_tabController.index];
    final isLoading = _loadingStatus[key] ?? true;
    final visible = _articles[key]?.take(_articleLimit[key] ?? 0).toList() ?? [];

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: AppBarTitle(loc.bdNewsreader),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [start.withOpacity(0.8), end.withOpacity(0.85)],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [start.withOpacity(0.6), end.withOpacity(0.7)],
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            const SizedBox(height: 12),
            _buildDateWeather(prov),
            const SizedBox(height: 12),
            _buildChips(prov),
            const SizedBox(height: 8),
            Expanded(
              child: isLoading
                  ? const ShimmerLoading()
                  : visible.isEmpty
                      ? Center(
                          child: Text(
                            loc.noArticlesFound,
                            style: prov.floatingTextStyle(fontSize: 16),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadOnlyExpiredFeeds,
                          color: end.withOpacity(0.8),
                          child: ListView.builder(
                            controller: _scrollControllers[key],
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: visible.length + 1,
                            itemBuilder: (_, i) {
                              if (i >= visible.length) {
                                return const SizedBox(height: 64);
                              }
                              final a = visible[i];
                              final src = a.source.toLowerCase();
                              final highlight = !(src.contains('prothom') || src.contains('daily star'));
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: NewsCard(
                                  article: a,
                                  onTap: () => context.push('/webview', extra: {'url': a.url, 'title': a.title}),
                                  highlight: highlight,
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildDateWeather(ThemeProvider prov) {
    final now = DateTime.now();
    final time = DateFormat('hh:mm a').format(now);
    final date = DateFormat('dd.MM.yyyy').format(now);
    final weather = _weatherLoading
        ? '...'
        : (_weatherLocation.isNotEmpty && _weatherTemp != null
            ? '$_weatherLocation, ${_weatherTemp!.round()}°C'
            : 'Unknown');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: prov.glassDecoration(borderRadius: BorderRadius.circular(32)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Column(children: [
          Row(children: [
            Icon(Icons.battery_full, color: prov.floatingTextStyle().color),
            const SizedBox(width: 8),
            Text('75%', style: prov.floatingTextStyle(fontSize: 14)),
            const Spacer(),
            Text(time, style: prov.floatingTextStyle(fontSize: 24)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Text(weather, style: prov.floatingTextStyle(fontSize: 18)),
            const Spacer(),
            Text(date, style: prov.floatingTextStyle(fontSize: 14)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildChips(ThemeProvider prov) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        height: 48,
        decoration: prov.glassDecoration(borderRadius: BorderRadius.circular(16)),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: _categoryKeys.length,
          itemBuilder: (_, i) {
            final label = _localizedLabels[_categoryKeys[i]] ?? _categoryKeys[i];
            final selected = _tabController.index == i;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ChoiceChip(
                label: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    color: isLight ? Colors.black87 : (selected ? Colors.white : Colors.white70),
                  ),
                ),
                selected: selected,
                backgroundColor: prov.glassColor,
                selectedColor: Colors.amber.withOpacity(0.8),
                elevation: selected ? 4 : 0,
                onSelected: (_) {
                  _tabController.animateTo(i);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void didPopNext() {
    _tabController.animateTo(0);
    _scrollControllers[_categoryKeys[0]]?.jumpTo(0);
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPressed == null || now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      Fluttertoast.showToast(
        msg: 'Press back again to exit',
        toastLength: Toast.LENGTH_SHORT,
      );
      return false;
    }
    return true;
  }
}
