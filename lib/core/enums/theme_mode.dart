/// Available app theme modes.
enum AppThemeMode { system, dark, bangladesh }

AppThemeMode normalizeThemeMode(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => AppThemeMode.system,
  AppThemeMode.dark => AppThemeMode.dark,
  AppThemeMode.bangladesh => AppThemeMode.bangladesh,
};

bool isUserSelectableThemeMode(AppThemeMode mode) {
  final normalized = normalizeThemeMode(mode);
  return normalized == AppThemeMode.system ||
      normalized == AppThemeMode.dark ||
      normalized == AppThemeMode.bangladesh;
}

AppThemeMode themeModeFromName(String? rawName) {
  final name = (rawName ?? '').trim().toLowerCase();
  return switch (name) {
    'light' => AppThemeMode.system,
    'dark' => AppThemeMode.dark,
    'amoled' => AppThemeMode.dark,
    'bangladesh' => AppThemeMode.bangladesh,
    'desh' => AppThemeMode.bangladesh,
    'emerald' => AppThemeMode.bangladesh,
    'system' => AppThemeMode.system,
    _ => AppThemeMode.system,
  };
}

AppThemeMode themeModeFromIndex(int? rawIndex) {
  return switch (rawIndex) {
    1 => AppThemeMode.system,
    2 => AppThemeMode.dark,
    3 => AppThemeMode.bangladesh,
    4 => AppThemeMode.dark,
    0 => AppThemeMode.system,
    _ => AppThemeMode.system,
  };
}

int themeModeToStorageIndex(AppThemeMode mode) {
  return switch (normalizeThemeMode(mode)) {
    AppThemeMode.system => 0,
    AppThemeMode.dark => 2,
    AppThemeMode.bangladesh => 3,
  };
}
