import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderables/reorderables.dart';
import '../publisher_layout_provider.dart';
import 'publisher_tile.dart';

class DraggablePublisherGrid extends ConsumerStatefulWidget {
  const DraggablePublisherGrid({
    required this.publishers,
    required this.layoutKey,
    required this.onPublisherTap,
    required this.isFavorite,
    required this.onFavoriteToggle,
    this.itemBuilder,
    this.itemExtent,
    this.disableMotion = false,
    this.lightweightMode = false,
    this.asSliver = false,
    super.key,
  });
  final List<dynamic> publishers;
  final String layoutKey;
  final ValueChanged<dynamic> onPublisherTap;
  final bool Function(dynamic) isFavorite;
  final VoidCallback Function(dynamic) onFavoriteToggle;
  final Widget Function(BuildContext context, Map<String, dynamic> publisher)?
  itemBuilder;
  final double? itemExtent;
  final bool disableMotion;
  final bool lightweightMode;
  final bool asSliver;

  @override
  ConsumerState<DraggablePublisherGrid> createState() =>
      _DraggablePublisherGridState();
}

class _DraggablePublisherGridState
    extends ConsumerState<DraggablePublisherGrid> {
  static const double _lightweightItemExtent = 104;

  late List<String> _lastPublisherIds;
  Object? _lastPublishersRef;
  List<Map<String, dynamic>> _cachedSourcePublishers =
      const <Map<String, dynamic>>[];
  Map<String, Map<String, dynamic>> _cachedPublisherMap =
      const <String, Map<String, dynamic>>{};

  @override
  void initState() {
    super.initState();
    _lastPublisherIds = _extractIds(widget.publishers);
    _refreshPublisherCache(force: true);
    _syncLayout(_lastPublisherIds);
  }

  @override
  void didUpdateWidget(covariant DraggablePublisherGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshPublisherCache();

    final newIds = _extractIds(widget.publishers);

    if (oldWidget.layoutKey != widget.layoutKey) {
      _lastPublisherIds = newIds;
      _syncLayout(newIds);
      return;
    }

    if (!_listEquals(_lastPublisherIds, newIds)) {
      _lastPublisherIds = newIds;
      _syncLayout(newIds);
    }
  }

  List<String> _extractIds(List<dynamic> publishers) {
    final seen = <String>{};
    final ids = <String>[];

    for (final raw in publishers) {
      if (raw is! Map) continue;
      final id = raw['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      if (seen.add(id)) ids.add(id);
    }

    return ids;
  }

  void _refreshPublisherCache({bool force = false}) {
    if (!force && identical(_lastPublishersRef, widget.publishers)) {
      return;
    }

    _lastPublishersRef = widget.publishers;
    _cachedSourcePublishers = _dedupePublishers(widget.publishers);
    _cachedPublisherMap = <String, Map<String, dynamic>>{
      for (final publisher in _cachedSourcePublishers)
        publisher['id'].toString(): publisher,
    };
  }

  List<Map<String, dynamic>> _dedupePublishers(List<dynamic> publishers) {
    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];

    for (final raw in publishers) {
      if (raw is! Map) continue;
      final map = raw is Map<String, dynamic>
          ? raw
          : raw.cast<String, dynamic>();
      final id = map['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      if (seen.add(id)) deduped.add(map);
    }

    return deduped;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _syncLayout(List<String> ids) {
    if (ids.isEmpty || !mounted) return;
    ref.read(publisherLayoutProvider(widget.layoutKey).notifier).loadOnce(ids);
  }

  List<String> _mergeIdsForCurrentSource(
    List<String> preferredIds,
    List<String> sourceIds,
  ) {
    if (sourceIds.isEmpty) return const <String>[];
    final preferredSet = preferredIds.toSet();
    final hasCompleteCoverage = sourceIds.every(preferredSet.contains);
    if (!hasCompleteCoverage) {
      return List<String>.from(sourceIds, growable: false);
    }

    final sourceSet = sourceIds.toSet();
    final seen = <String>{};
    final merged = <String>[];

    for (final id in preferredIds) {
      if (!sourceSet.contains(id)) continue;
      if (seen.add(id)) merged.add(id);
    }
    for (final id in sourceIds) {
      if (seen.add(id)) merged.add(id);
    }

    return merged;
  }

  Widget _buildTileItem(
    Map<String, dynamic> publisher,
    double tileWidth, {
    required bool lightweightMode,
  }) {
    return SizedBox(
      key: ValueKey(publisher['id']),
        width: tileWidth,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: PublisherTile(
            layoutKey: widget.layoutKey,
            publisher: publisher,
            onTap: () => widget.onPublisherTap(publisher),
            isFavorite: widget.isFavorite(publisher),
            onFavoriteToggle: widget.onFavoriteToggle(publisher),
            disableMotion: widget.disableMotion,
            lightweightMode: lightweightMode,
          ),
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderedIds = ref.watch(publisherIdsProvider(widget.layoutKey));
    final controller = ref.read(
      publisherLayoutProvider(widget.layoutKey).notifier,
    );
    final isEditMode = ref.watch(editModeProvider(widget.layoutKey));
    _refreshPublisherCache();

    final sourceIds = _lastPublisherIds;
    final preferredIds = orderedIds.isEmpty ? sourceIds : orderedIds;
    final mergedIds = _mergeIdsForCurrentSource(preferredIds, sourceIds);
    if (mergedIds.isEmpty) {
      return widget.asSliver
          ? const SliverToBoxAdapter(child: SizedBox.shrink())
          : const SizedBox.shrink();
    }

    final publisherMap = _cachedPublisherMap;

    final displayPublishers = mergedIds
        .map((id) => publisherMap[id])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final effectiveLightweightMode = true;

    if (displayPublishers.isEmpty) {
      return widget.asSliver
          ? const SliverToBoxAdapter(child: SizedBox.shrink())
          : const SizedBox.shrink();
    }

    // Calculate width for single column
    final tileWidth = MediaQuery.of(context).size.width - 24;

    if (!isEditMode) {
      if (widget.itemBuilder != null) {
        if (widget.asSliver) {
          if (widget.itemExtent != null) {
            return SliverFixedExtentList(
              itemExtent: widget.itemExtent!,
              delegate: SliverChildBuilderDelegate(
                (context, index) => KeyedSubtree(
                  key: ValueKey(displayPublishers[index]['id']),
                  child: widget.itemBuilder!(
                    context,
                    displayPublishers[index],
                  ),
                ),
                childCount: displayPublishers.length,
              ),
            );
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => KeyedSubtree(
                key: ValueKey(displayPublishers[index]['id']),
                child: widget.itemBuilder!(context, displayPublishers[index]),
              ),
              childCount: displayPublishers.length,
            ),
          );
        }

        return Column(
          children: List.generate(
            displayPublishers.length,
            (index) => KeyedSubtree(
              key: ValueKey(displayPublishers[index]['id']),
              child: widget.itemBuilder!(context, displayPublishers[index]),
            ),
          ),
        );
      }

      if (widget.asSliver) {
        return SliverFixedExtentList(
          itemExtent: _lightweightItemExtent,
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return _buildTileItem(
                displayPublishers[index],
                tileWidth,
                lightweightMode: effectiveLightweightMode,
              );
            },
            childCount: displayPublishers.length,
          ),
        );
      }

      return Column(
        children: List.generate(
          displayPublishers.length,
          (index) => _buildTileItem(
            displayPublishers[index],
            tileWidth,
            lightweightMode: effectiveLightweightMode,
          ),
        ),
      );
    }

    final reorderableContent = ReorderableWrap(
      spacing: 2,
      runSpacing: 2,
      alignment: WrapAlignment.center,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex == newIndex) return;
        if (newIndex < 0 || newIndex > displayPublishers.length) return;

        final ids = displayPublishers
            .map((p) => p['id'].toString())
            .toList(growable: false);

        controller.reorder(oldIndex, newIndex, ids);
      },
      children: List.generate(displayPublishers.length, (index) {
        return _buildTileItem(
          displayPublishers[index],
          tileWidth,
          lightweightMode: effectiveLightweightMode,
        );
      }),
    );

    if (widget.asSliver) {
      return SliverToBoxAdapter(child: reorderableContent);
    }
    return reorderableContent;
  }
}
