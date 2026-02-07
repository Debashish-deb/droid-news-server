import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderables/reorderables.dart';
import '../publisher_layout_provider.dart';
import 'publisher_tile.dart';

class DraggablePublisherGrid extends ConsumerStatefulWidget {

  const DraggablePublisherGrid({
    required this.publishers, required this.layoutKey, required this.onPublisherTap, required this.isFavorite, required this.onFavoriteToggle, super.key,
  });
  final List<dynamic> publishers;
  final String layoutKey;
  final ValueChanged<dynamic> onPublisherTap;
  final bool Function(dynamic) isFavorite;
  final VoidCallback Function(dynamic) onFavoriteToggle;

  @override
  ConsumerState<DraggablePublisherGrid> createState() =>
      _DraggablePublisherGridState();
}

class _DraggablePublisherGridState
    extends ConsumerState<DraggablePublisherGrid> {
  late List<String> _lastPublisherIds;

  @override
  void initState() {
    super.initState();
    _lastPublisherIds = _extractIds(widget.publishers);
    _syncLayout(_lastPublisherIds);
  }

  @override
  void didUpdateWidget(covariant DraggablePublisherGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newIds = _extractIds(widget.publishers);

    if (!_listEquals(_lastPublisherIds, newIds)) {
      _lastPublisherIds = newIds;
      _syncLayout(newIds);
    }
  }

  List<String> _extractIds(List<dynamic> publishers) =>
      publishers.map((p) => p['id'].toString()).toList(growable: false);

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _syncLayout(List<String> ids) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(publisherLayoutProvider(widget.layoutKey).notifier)
          .load(ids);
    });
  }

  @override
  Widget build(BuildContext context) {
    final layoutProvider =
        publisherLayoutProvider(widget.layoutKey);

    final orderedIds = ref.watch(layoutProvider);
    final controller = ref.read(layoutProvider.notifier);

    final workingIds = orderedIds.isEmpty
        ? _lastPublisherIds
        : orderedIds;

    if (workingIds.isEmpty) return const SizedBox.shrink();

    final publisherMap = {
      for (final p in widget.publishers)
        p['id'].toString(): p
    };

    final publishers = workingIds
        .map((id) => publisherMap[id])
        .where((p) => p != null && p is Map)
        .cast<Map<String, dynamic>>() // Safe cast
        .toList(growable: false);

    // END-OF-LIST SYNC FALLBACK
    // If layout provider has old IDs (from previous category) that don't match current category's papers,
    // we get an empty list. Fallback to natural order to avoid "blank screen" flicker.
    final displayPublishers = (publishers.isEmpty && widget.publishers.isNotEmpty)
        ? widget.publishers.cast<Map<String, dynamic>>()
        : publishers;

    // Calculate width for single column
    // Calculate width for single column
    final tileWidth = MediaQuery.of(context).size.width - 24;

    return ReorderableWrap(
      spacing: 2,
      runSpacing: 2,
      alignment: WrapAlignment.center,
      onReorder: (oldIndex, newIndex) {
        // Adjust index for removal if dragging downwards
        // Standard reorder behavior: if moving down, newIndex includes the item itself
        /* 
           Note: reorderables package might handle this differently than ReorderableListView.
           If using reorderables 0.6.0+, it usually behaves like the standard list.
           We'll add the safety check.
        */
        
        final ids = publishers
            .map((p) => p['id'].toString())
            .toList(growable: false);

        controller.reorder(oldIndex, newIndex, ids);
      },
      children: List.generate(displayPublishers.length, (index) {
        final p = displayPublishers[index];

        return SizedBox(
          key: ValueKey(p['id']),
          width: tileWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: PublisherTile(
              publisher: p,
              onTap: () => widget.onPublisherTap(p),
              isFavorite: widget.isFavorite(p),
              onFavoriteToggle:
                  widget.onFavoriteToggle(p),
            ),
          ),
        );
      }),
    );
  }
}
