import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/source_logos.dart';
import '../../providers/source_providers.dart';
import '../../providers/theme_providers.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/premium_screen_header.dart';

class SourceManagementScreen extends ConsumerWidget {
  const SourceManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedAsync = ref.watch(groupedSourcesProvider);
    final sourcesCount = ref.watch(sourcesProvider).valueOrNull?.length ?? 0;
    final themeMode = ref.watch(currentThemeModeProvider);
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColorsExtension>()!;
    final backgroundGradient = AppGradients.getBackgroundGradient(themeMode);

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      appBar: PremiumScreenHeader(
        title: 'News Sources',
        subtitle: 'Customize your feed',
        leading: PremiumHeaderLeading.menu,
        actions: [
          PremiumHeaderIconButton(
            icon: Icons.restart_alt_rounded,
            iconColor: appColors.proBlue,
            tooltip: 'Reset to defaults',
            onPressed: () {
              ref.read(sourcesProvider.notifier).resetToDefault();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Sources reset to defaults'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      // Optional: implement undo logic
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  backgroundGradient[0].withValues(alpha: 0.96),
                  backgroundGradient[1].withValues(alpha: 0.96),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.95),
                radius: 1.3,
                colors: [
                  theme.colorScheme.primary.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.08 : 0.05,
                  ),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          groupedAsync.when(
            loading: () => _buildShimmerLoading(context),
            error: (err, stack) => _buildErrorState(context, ref, err),
            data: (groupedInfo) {
              if (groupedInfo.isEmpty) {
                return _buildEmptyState(context);
              }

              final sortedCategories = groupedInfo.keys.toList()..sort();
              final activeCount = groupedInfo.values
                  .expand((l) => l)
                  .where((s) => s.isEnabled)
                  .length;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              appColors.proBlue.withValues(alpha: 0.15),
                              appColors.proBlue.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: appColors.cardBorder.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.tips_and_updates_rounded,
                              color: appColors.proBlue,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Active: $activeCount of $sourcesCount sources',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: appColors.proBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ...sortedCategories.expand((category) {
                    final categorySources = groupedInfo[category]!;

                    return [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: appColors.proBlue,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                category.toUpperCase(),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: appColors.proBlue,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Divider(
                                  color: appColors.cardBorder.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final source = categorySources[index];
                            return _SourceListTile(
                              source: source,
                              onToggle: (value) {
                                ref
                                    .read(sourcesProvider.notifier)
                                    .toggleSource(source.id, value);
                              },
                            );
                          }, childCount: categorySources.length),
                        ),
                      ),
                    ];
                  }),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 80,
          decoration: BoxDecoration(
            color: appColors.cardBorder.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 20,
                backgroundColor: appColors.cardBorder.withOpacity(0.5),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: 120,
                      decoration: BoxDecoration(
                        color: appColors.cardBorder.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: appColors.cardBorder.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 48,
                height: 32,
                decoration: BoxDecoration(
                  color: appColors.cardBorder.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object err) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: appColors.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: appColors.errorRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to Load Sources',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: appColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$err',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: appColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.invalidate(sourcesProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColorsExtension>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 64,
              color: appColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              'No Sources Available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: appColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new content sources',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: appColors.textHint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceListTile extends StatelessWidget {
  const _SourceListTile({required this.source, required this.onToggle});
  final dynamic source;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColorsExtension>()!;
    final hasLogo = SourceLogos.logos.containsKey(source.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: appColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => onToggle(!source.isEnabled),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Modern Logo Container
                Hero(
                  tag: 'source_${source.id}',
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: hasLogo
                          ? Colors.white
                          : appColors.proBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        if (hasLogo)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: hasLogo
                          ? Image.asset(
                              SourceLogos.logos[source.name]!,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.newspaper_rounded,
                                    color: appColors.proBlue,
                                  ),
                            )
                          : Center(
                              child: Text(
                                source.name.isNotEmpty
                                    ? source.name[0].toUpperCase()
                                    : '?',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: appColors.proBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: source.isEnabled
                              ? appColors.textPrimary
                              : appColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        source.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: appColors.textHint,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Modern Switch
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: source.isEnabled,
                    onChanged: onToggle,
                    activeColor: Colors.white,
                    activeTrackColor: appColors.proBlue,
                    inactiveThumbColor: appColors.textHint,
                    inactiveTrackColor: appColors.cardBorder,
                    trackOutlineColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? Colors.transparent
                          : appColors.cardBorder.withOpacity(0.5),
                    ),
                    trackOutlineWidth: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected) ? 0 : 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
