import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'feature_providers.dart';

enum MagazineCategory {
  fashion,
  science,
  economics,
  worldAffairs,
  technology,
  arts,
  lifestyle,
  sports,
}

const magazineCategoryTags = <MagazineCategory, List<String>>{
  MagazineCategory.fashion: ['fashion', 'style', 'aesthetics'],
  MagazineCategory.science: ['science', 'discovery', 'research'],
  MagazineCategory.economics: ['finance', 'economics', 'business'],
  MagazineCategory.worldAffairs: ['global', 'politics', 'world'],
  MagazineCategory.technology: ['technology', 'tech'],
  MagazineCategory.arts: ['arts', 'culture'],
  MagazineCategory.lifestyle: ['lifestyle', 'luxury', 'travel'],
  MagazineCategory.sports: ['sports', 'performance'],
};

final magazineCategoryTagSets = <MagazineCategory, Set<String>>{
  for (final entry in magazineCategoryTags.entries)
    entry.key: entry.value.map((tag) => tag.toLowerCase().trim()).toSet(),
};

final magazineTabIndexProvider = StateProvider<int>((ref) => 0);

final filteredMagazinesProvider = Provider<List<dynamic>>((ref) {
  final allMags = ref.watch(magazineDataProvider).value ?? const [];
  final tabIndex = ref.watch(magazineTabIndexProvider);

  if (allMags.isEmpty) return const [];
  if (tabIndex < 0 || tabIndex >= MagazineCategory.values.length) {
    return const [];
  }

  final cat = MagazineCategory.values[tabIndex];
  final keywords = magazineCategoryTagSets[cat]!;
  final filtered = <dynamic>[];

  for (final item in allMags) {
    if (item is! Map) continue;
    final rawTags = item['tags'];
    if (rawTags is! List || rawTags.isEmpty) continue;

    var hasCategory = false;
    for (final rawTag in rawTags) {
      final tag = rawTag?.toString().toLowerCase().trim();
      if (tag == null || tag.isEmpty) continue;
      if (keywords.any(tag.contains)) {
        hasCategory = true;
        break;
      }
    }

    if (hasCategory) {
      filtered.add(item);
    }
  }

  return List<dynamic>.unmodifiable(filtered);
});
