List<String> extractPublisherIds(List<dynamic> publishers) {
  final seen = <String>{};
  final ids = <String>[];

  for (final raw in publishers) {
    if (raw is! Map) continue;
    final id = raw['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    if (seen.add(id)) ids.add(id);
  }

  return List<String>.unmodifiable(ids);
}

List<Map<String, dynamic>> dedupePublishers(List<dynamic> publishers) {
  final seen = <String>{};
  final deduped = <Map<String, dynamic>>[];

  for (final raw in publishers) {
    if (raw is! Map) continue;
    final map = raw is Map<String, dynamic> ? raw : raw.cast<String, dynamic>();
    final id = map['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    if (seen.add(id)) deduped.add(map);
  }

  return List<Map<String, dynamic>>.unmodifiable(deduped);
}

List<String> mergePublisherLayoutIds(
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

  return List<String>.unmodifiable(merged);
}

List<Map<String, dynamic>> orderPublishersByLayout(
  List<dynamic> publishers,
  List<String> orderedIds,
) {
  final deduped = dedupePublishers(publishers);
  if (deduped.isEmpty) {
    return const <Map<String, dynamic>>[];
  }

  final sourceIds = extractPublisherIds(deduped);
  final preferredIds = orderedIds.isEmpty ? sourceIds : orderedIds;
  final mergedIds = mergePublisherLayoutIds(preferredIds, sourceIds);
  final publisherMap = <String, Map<String, dynamic>>{
    for (final publisher in deduped) publisher['id'].toString(): publisher,
  };

  return List<Map<String, dynamic>>.unmodifiable(
    mergedIds.map((id) => publisherMap[id]).whereType<Map<String, dynamic>>(),
  );
}
