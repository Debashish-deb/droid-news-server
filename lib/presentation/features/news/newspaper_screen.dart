import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';

import '../../../core/enums/theme_mode.dart';
import '../../../l10n/generated/app_localizations.dart';
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

import '../publisher_layout/publisher_layout_provider.dart' show editModeProvider;

// Providers
import '../../providers/favorites_providers.dart';
import '../../providers/theme_providers.dart';
import '../../providers/feature_providers.dart';

class NewspaperScreen extends ConsumerStatefulWidget {
  const NewspaperScreen({super.key});

  @override
  ConsumerState<NewspaperScreen> createState() => _NewspaperScreenState();
}

class _NewspaperScreenState extends ConsumerState<NewspaperScreen>
    with SingleTickerProviderStateMixin {
  
  late final TabController _tabController;
  late final ScrollController _scrollController;
  late final ScrollController _chipsController;
  late final List<GlobalKey> _chipKeys;

  DateTime? _lastBackPressed;
  String? _langFilter; // 'en' or 'bn' or null (all)

  static const int _categoriesCount = 8;
  
  // Cache categories to avoid rebuilding list
  List<String> _cachedCategories = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _chipsController = ScrollController();
    _tabController = TabController(length: _categoriesCount, vsync: this);
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _centerChip(_tabController.index);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      // Reset lang filter on category change
      setState(() => _langFilter = null);
    });
    
    _chipKeys = List.generate(_categoriesCount, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _chipsController.dispose();
    _tabController.dispose();
    super.dispose();
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

  List<String> _getCategories(BuildContext context) {
    if (_cachedCategories.isNotEmpty) return _cachedCategories;
    
    final AppLocalizations loc = AppLocalizations.of(context);
    _cachedCategories = [
      loc.national,
      loc.international,
      loc.regional,
      loc.politics,
      loc.economics,
      loc.sports,
      loc.education,
      loc.technology,
    ];
    return _cachedCategories;
  }

  void _centerChip(int index) {
      if (index < 0 || index >= _chipKeys.length) return;
      final GlobalKey key = _chipKeys[index];
      if (key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 200),
          alignment: 0.5,
        );
      }
  }

  // Filtering Logic
  List<dynamic> _filterPapers(BuildContext context, List<dynamic> allPapers) {
    final loc = AppLocalizations.of(context);
    final cats = _getCategories(context);
    final currentCat = cats[_tabController.index];
    
    // 1. Filter by Category
    List<dynamic> papers = allPapers.where((p) {
       final tags = List<String>.from(p['tags'] ?? []);
       
       // Map categories to tags
       if (currentCat == loc.national) return tags.contains('national');
       if (currentCat == loc.international) return tags.contains('international');
       if (currentCat == loc.regional) return tags.contains('regional');
       if (currentCat == loc.politics) return tags.contains('politics');
       if (currentCat == loc.economics) return tags.contains('economics') || tags.contains('business');
       if (currentCat == loc.sports) return tags.contains('sports');
       if (currentCat == loc.education) return tags.contains('education');
       if (currentCat == loc.technology) return tags.contains('technology');
       
       return false;
    }).toList();

    // 2. Filter by Language if set
    if (_langFilter != null) {
      papers = papers.where((p) => p['language'] == _langFilter).toList();
    }

    return papers;
  }

  Widget _buildLanguageFilter(BuildContext context) {
     final loc = AppLocalizations.of(context);
     final theme = Theme.of(context);
     final scheme = theme.colorScheme;
     
     return Container(
        padding: const EdgeInsets.all(4), // Reduced from 12
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.light ? Colors.black.withOpacity(0.02) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: theme.brightness == Brightness.light ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.1),
            width: 0.8,
          ),
        ),
        child: Wrap(
          spacing: 12,
          children: [
             Bouncy3DChip(
               label: loc.all,
               selected: _langFilter == null,
               onTap: () => setState(() => _langFilter = null),
             ),
             Bouncy3DChip(
               label: 'Bangla',
               selected: _langFilter == 'bn',
               onTap: () => setState(() => _langFilter = 'bn'),
             ),
             Bouncy3DChip(
               label: 'English',
               selected: _langFilter == 'en',
               onTap: () => setState(() => _langFilter = 'en'),
             ),
          ],
        ),
     );
  }

  @override
  Widget build(BuildContext context) {
    // Re-fetch categories on locale change
    _cachedCategories = []; 
    final categories = _getCategories(context);
    
    final AppThemeMode themeMode = ref.watch(currentThemeModeProvider);
    final AppLocalizations loc = AppLocalizations.of(context);
    final papersAsync = ref.watch(newspaperDataProvider);

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isEditMode = ref.watch(editModeProvider);
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
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    colors[0].withOpacity(0.85),
                    colors[1].withOpacity(0.85),
                  ],
                ),
              ),
            ),
            CustomScrollView(
              controller: _scrollController,
              key: const PageStorageKey('newspaper_scroll'),
              slivers: <Widget>[
                SliverAppBar(
                  pinned: true,
                  backgroundColor: theme.appBarTheme.backgroundColor,
                  elevation: theme.appBarTheme.elevation,
                  centerTitle: true,
                  toolbarHeight: 54, // Reduced from 58
                  titleTextStyle: theme.appBarTheme.titleTextStyle,
                  title: isEditMode 
                      ? Text(loc.editLayout, style: theme.appBarTheme.titleTextStyle?.copyWith(color: Colors.white, fontWeight: FontWeight.w900))
                      : AppBarTitle(loc.news),
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
                        icon: const Icon(Icons.edit_note_rounded, size: 28),
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

                // Language Filter for National/International tabs
                if (!isEditMode && (categories[_tabController.index] == loc.national || categories[_tabController.index] == loc.international))
                   SliverToBoxAdapter(
                      child: Padding(
                         padding: const EdgeInsets.symmetric(vertical: 8),
                         child: Center(child: _buildLanguageFilter(context)),
                      ),
                   ),

                papersAsync.when(
                  data: (allPapers) {
                    final filtered = _filterPapers(context, allPapers);
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
                                      loc.noNewspapers,
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  )
                                  : Builder(
                                      builder: (context) {
                                        final favNewspapers = ref.watch(favoriteNewspapersProvider);
                                        return DraggablePublisherGrid(
                                          layoutKey: 'newspapers',
                                          publishers: filtered,
                                          isFavorite: (paper) {
                                              return favNewspapers.any((p) => p['id'].toString() == paper['id'].toString());
                                          },
                                      onFavoriteToggle: (paper) {
                                          return () {
                                            ref.read(favoritesProvider.notifier).toggleNewspaper(paper);
                                          };
                                      },
                                      onPublisherTap: (paper) async {
                                          final tags = List<String>.from(paper['tags'] ?? []);
                                          final bool isPremium = tags.contains('premium');
                                          final url = paper['contact']?['website'] ?? paper['url'] ?? '';
                                          final title = paper['name'] ?? 'Newspaper';

                                          if (url.isEmpty) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('No URL available'))
                                              );
                                              return;
                                          }

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
                      child: Center(child: Text('Error: $err')),
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
          label: const Text('Save Layout'),
          icon: const Icon(CupertinoIcons.check_mark),
          backgroundColor: scheme.tertiary,
          foregroundColor: Colors.black,
        ) : null,
      ),
    );
  }
}
