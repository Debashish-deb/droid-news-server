/// Available app theme modes.
enum AppThemeMode { system, light, dark, bangladesh, amoled }

/// New policy: keep only Auto(System) and Bangladesh as user-facing modes.
/// Legacy persisted values are normalized at runtime to avoid enum reindexing.
AppThemeMode normalizeThemeMode(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
    case AppThemeMode.dark:
      return AppThemeMode.system;
    case AppThemeMode.amoled:
      return AppThemeMode.amoled;
    case AppThemeMode.system:
    case AppThemeMode.bangladesh:
      return mode;
  }
}

bool isUserSelectableThemeMode(AppThemeMode mode) {
  return mode == AppThemeMode.system ||
      mode == AppThemeMode.amoled ||
      mode == AppThemeMode.bangladesh;
}

AppThemeMode themeModeFromName(String? rawName) {
  final name = (rawName ?? '').trim();
  final matched = AppThemeMode.values.where((m) => m.name == name);
  if (matched.isEmpty) return AppThemeMode.system;
  return normalizeThemeMode(matched.first);
}

AppThemeMode themeModeFromIndex(int? rawIndex) {
  if (rawIndex == null ||
      rawIndex < 0 ||
      rawIndex >= AppThemeMode.values.length) {
    return AppThemeMode.system;
  }
  return normalizeThemeMode(AppThemeMode.values[rawIndex]);
}
