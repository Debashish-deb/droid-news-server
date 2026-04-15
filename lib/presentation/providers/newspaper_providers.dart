import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'feature_providers.dart';

enum NewspaperCategory {
  national,
  international,
  regional,
  politics,
  economics,
  sports,
  education,
  technology,
}

const newspaperCategoryTags = <NewspaperCategory, List<String>>{
  NewspaperCategory.national: ['national'],
  NewspaperCategory.international: ['international'],
  NewspaperCategory.regional: ['regional'],
  NewspaperCategory.politics: ['politics'],
  NewspaperCategory.economics: ['economics', 'business'],
  NewspaperCategory.sports: ['sports'],
  NewspaperCategory.education: ['education'],
  NewspaperCategory.technology: ['technology'],
};

final newspaperCategoryTagSets = <NewspaperCategory, Set<String>>{
  for (final entry in newspaperCategoryTags.entries)
    entry.key: entry.value.map((tag) => tag.toLowerCase().trim()).toSet(),
};

final newspaperTabIndexProvider = StateProvider<int>((ref) => 0);
final newspaperLangFilterProvider = StateProvider<String?>((ref) => null);

final filteredNewspapersProvider = Provider<List<dynamic>>((ref) {
  final allPapers = ref.watch(newspaperDataProvider).value ?? const [];
  final tabIndex = ref.watch(newspaperTabIndexProvider);
  final langFilter = ref.watch(newspaperLangFilterProvider);

  if (allPapers.isEmpty) return const [];
  if (tabIndex < 0 || tabIndex >= NewspaperCategory.values.length) {
    return const [];
  }

  final cat = NewspaperCategory.values[tabIndex];
  final keywords = newspaperCategoryTagSets[cat]!;
  final filtered = <dynamic>[];

  for (final paper in allPapers) {
    if (paper is! Map) continue;
    final rawTags = paper['tags'];
    if (rawTags is! List || rawTags.isEmpty) continue;

    var hasCategory = false;
    for (final rawTag in rawTags) {
      final tag = rawTag?.toString().toLowerCase().trim();
      if (tag == null || tag.isEmpty) continue;
      if (keywords.contains(tag)) {
        hasCategory = true;
        break;
      }
    }

    if (!hasCategory) continue;
    if (langFilter != null && paper['language'] != langFilter) {
      continue;
    }
    filtered.add(paper);
  }

  return List<dynamic>.unmodifiable(filtered);
});
