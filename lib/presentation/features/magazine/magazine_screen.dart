import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/enums/theme_mode.dart';
import '../../../l10n/generated/app_localizations.dart' show AppLocalizations;
import '../../widgets/animated_theme_container.dart';
import '../../widgets/app_drawer.dart';
import '../common/app_bar.dart';
import '../publisher_layout/presentation/draggable_publisher_grid.dart';
import '../../widgets/sticky_header_delegate.dart';
import '../../../core/theme.dart';
import '../../widgets/category_chips_bar.dart';
import '../../widgets/glass_icon_button.dart';
import '../../../../infrastructure/services/interstitial_ad_service.dart';
import '../../widgets/unlock_article_dialog.dart';
import '../../providers/favorites_providers.dart';
import '../../providers/theme_providers.dart';
import '../../providers/feature_providers.dart';

import '../publisher_layout/publisher_layout_provider.dart' show editModeProvider;

class MagazineScreen extends ConsumerStatefulWidget {
  const MagazineScreen({super.key});

  @override
  ConsumerState<MagazineScreen> createState() => _MagazineScreenState();
}

class _MagazineScreenState extends ConsumerState<MagazineScreen>
    with SingleTickerProviderStateMixin {

  late final TabController _tabController;
  late final ScrollController _scrollController;
  late final ScrollController _chipsController;
  late final List<GlobalKey> _chipKeys;

  DateTime? _lastBackPressed;

  static const int _categoriesCount = 8;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _chipsController = ScrollController();
    _tabController = TabController(length: _categoriesCount, vsync: this)
      ..addListener(() {
        _centerChip(_tabController.index);
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
        setState(() {});
      });
    _chipKeys = List.generate(_categoriesCount, (_) => GlobalKey());
  }

  Future<bool> _onWillPop() async {
    final DateTime now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      Fluttertoast.showToast(msg: 'Press back again to exit');
      return false;
    }
    return true;
  }

  List<String> _categories(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context);

    return <String>[
      loc.catFashion,
      loc.catScience,
      loc.catFinance,
      loc.catAffairs,
      loc.catTech,
      loc.catArts,
      loc.catLifestyle,
      loc.catSports,
    ];
  }

  List<dynamic> _filteredMagazines(BuildContext context, List<dynamic> allMagazines) {
    final List<String> cats = _categories(context);
    final Map<String, List<String>> keys = <String, List<String>>{
      cats[0]: <String>['fashion', 'style', 'aesthetics'],
      cats[1]: <String>['science', 'discovery', 'research'],
      cats[2]: <String>['finance', 'economics', 'business'],
      cats[3]: <String>['global', 'politics', 'world'],
      cats[4]: <String>['technology', 'tech'],
      cats[5]: <String>['arts', 'culture'],
      cats[6]: <String>['lifestyle', 'luxury', 'travel'],
      cats[7]: <String>['sports', 'performance'],
    };
    final String sel = cats[_tabController.index];
    final List<String> kws = keys[sel] ?? <String>[];
    return allMagazines.where((m) {
      final List<String> tags = List<String>.from(m['tags'] ?? <dynamic>[]);
      return tags.any(
        (String t) => kws.any((String kw) => t.toLowerCase().contains(kw)),
      );
    }).toList();
  }

  void _centerChip(int index) {
    final GlobalKey<State<StatefulWidget>> key = _chipKeys[index];
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 200),
        alignment: 0.5,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _chipsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeMode themeMode = ref.watch(currentThemeModeProvider);
    final AppLocalizations loc = AppLocalizations.of(context);
    final magazinesAsync = ref.watch(magazineDataProvider);

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isEditMode = ref.watch(editModeProvider);
    final List<String> categories = _categories(context);
    final List<Color> colors = AppGradients.getBackgroundGradient(themeMode);

    return WillPopScope(
      onWillPop: () async {
        if (isEditMode) {
          ref.read(editModeProvider.notifier).state = false;
          return false;
        }
        return _onWillPop();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: scheme.surface,
        drawer: const AppDrawer(),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AnimatedThemeContainer(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    colors[0].withOpacity(0.85),
                    colors[1].withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            CustomScrollView(
              controller: _scrollController,
              key: const PageStorageKey('magazine_scroll'),
              slivers: <Widget>[
                SliverAppBar(
                  pinned: true,
                  backgroundColor: theme.appBarTheme.backgroundColor,
                  elevation: theme.appBarTheme.elevation,
                  centerTitle: true,
                  toolbarHeight: 54, // Reduced from 56
                  titleTextStyle: theme.appBarTheme.titleTextStyle,
                  title: isEditMode 
                      ? Text(loc.editLayout, style: theme.appBarTheme.titleTextStyle?.copyWith(color: Colors.white, fontWeight: FontWeight.w900))
                      : AppBarTitle(loc.magazines),
                  leading: Builder(
                    builder: (context) => Center(
                      child: GlassIconButton(
                        icon: Icons.menu_rounded,
                        onPressed: () => Scaffold.of(context).openDrawer(),
                        isDark: Theme.of(context).brightness == Brightness.dark,
                      ),
                    ),
                  ),
                  iconTheme: theme.appBarTheme.iconTheme,
                  actions: isEditMode ? [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: FilledButton(
                            onPressed: () {
                                ref.read(editModeProvider.notifier).state = false;
                            },
                            style: FilledButton.styleFrom(
                                backgroundColor: scheme.tertiary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: Text(loc.done, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )
                  ] : [
                      IconButton(
                        icon: const Icon(Icons.edit_note, size: 28),
                        onPressed: () => ref.read(editModeProvider.notifier).state = true,
                        tooltip: 'Edit Layout',
                      )
                  ],
                ),

                if (!isEditMode)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: StickyHeaderDelegate(
                      minHeight: 48, // Reduced from 56
                      maxHeight: 48, // Reduced from 56
                      child: Container(
                        height: 48, // Reduced from 56
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), // Reduced from 2
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.light ? Colors.black.withOpacity(0.02) : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: theme.brightness == Brightness.light ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.1),
                            width: 0.8,
                          ),
                        ),
                        child: ListView.separated(
                          controller: _chipsController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemCount: categories.length,
                          itemBuilder: (BuildContext ctx, int i) {
                            final bool sel = i == _tabController.index;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Bouncy3DChip(
                                label: categories[i],
                                selected: sel,
                                onTap: () {
                                  _tabController.animateTo(i);
                                  _centerChip(i);
                                  if (_scrollController.hasClients) {
                                    _scrollController.jumpTo(0);
                                  }
                                },
                                key: _chipKeys[i],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                magazinesAsync.when(
                  data: (allMagazines) {
                    final filtered = _filteredMagazines(context, allMagazines);
                    return SliverPadding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 2, // Reduced from 6
                        bottom: 80,
                      ),
                      sliver: SliverToBoxAdapter(
                          child: filtered.isEmpty
                                  ? Center(
                                    child: Text(
                                      loc.noMagazines,
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  )
                                  : Builder(
                                      builder: (context) {
                                        // Watch favorites ONCE at widget level, not in callback
                                        final favMagazines = ref.watch(favoriteMagazinesProvider);
                                        return DraggablePublisherGrid(
                                            layoutKey: 'magazines',
                                            publishers: filtered,
                                            isFavorite: (magazine) {
                                                return favMagazines.any((m) => m['id'].toString() == magazine['id'].toString());
                                            },
                                            onFavoriteToggle: (magazine) {
                                                return () {
                                                  ref.read(favoritesProvider.notifier).toggleMagazine(magazine);
                                                };
                                            },
                                            onPublisherTap: (magazine) async {
                                          final maybeWebsite = magazine['contact']?['website'];
                                          final maybeUrl = magazine['url'] ?? magazine['link'];
                                          final url = (maybeWebsite is String && maybeWebsite.isNotEmpty) 
                                              ? maybeWebsite 
                                              : (maybeUrl is String ? maybeUrl : '');
                                          final title = magazine['name'] ?? 'Magazine';

                                          if (url.isEmpty) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(loc.noUrlAvailable))
                                              );
                                              return;
                                          }

                                          final tags = List<String>.from(magazine['tags'] ?? <dynamic>[]);
                                          final bool isPremium = tags.contains('premium');

                                          if (isPremium) {
                                            final bool unlocked = await showUnlockDialog(context, url, title);
                                            if (!unlocked) return;
                                          }

                                          // Trigger ad logic (respects premium status internally)
                                          InterstitialAdService().onArticleViewed();

                                          if (!mounted) return;
                                          context.push('/webview', extra: {'url': url, 'title': title});
                                      },
                                    );
                                      },
                                    ),
                        ),
                    );
                  },
                  loading: () => SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ),
                  error: (err, stack) => SliverFillRemaining(
                      child: Center(child: Text('${loc.error}: $err')),
                  ),
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: isEditMode ? FloatingActionButton.extended(
          onPressed: () {
            ref.read(editModeProvider.notifier).state = false;
          },
          label: Text(loc.saveLayout),
          icon: const Icon(Icons.check),
          backgroundColor: scheme.tertiary,
          foregroundColor: Colors.black,
        ) : null,
      ),
    );
  }
}
