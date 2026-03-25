import 'package:shared_preferences/shared_preferences.dart';
import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../core/enums/theme_mode.dart';
import '../../domain/repositories/settings_repository.dart';

/// Implementation of SettingsRepository using SharedPreferences

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._prefs);
  final SharedPreferences? _prefs;

  static const String _themeKey = 'theme';
  static const String _lineHeightKey = 'reader_line_height';
  static const String _contrastKey = 'reader_contrast';

  @override
  Future<Either<AppFailure, AppThemeMode>> getThemeMode() async {
    return Right(getThemeModeSync());
  }

  @override
  AppThemeMode getThemeModeSync() {
    if (_prefs == null) return AppThemeMode.system;
    final themeName = _prefs.getString(_themeKey);
    return themeModeFromName(themeName);
  }

  @override
  Future<Either<AppFailure, void>> setThemeMode(AppThemeMode mode) async {
    try {
      if (_prefs == null) return const Right(null);
      final normalized = normalizeThemeMode(mode);
      await _prefs.setString(_themeKey, normalized.name);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, double>> getReaderLineHeight() async {
    return Right(getReaderLineHeightSync());
  }

  @override
  double getReaderLineHeightSync() {
    return _prefs?.getDouble(_lineHeightKey) ?? 1.6;
  }

  @override
  Future<Either<AppFailure, void>> setReaderLineHeight(double height) async {
    try {
      if (_prefs == null) return const Right(null);
      await _prefs.setDouble(_lineHeightKey, height);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, double>> getReaderContrast() async {
    return Right(getReaderContrastSync());
  }

  @override
  double getReaderContrastSync() {
    return _prefs?.getDouble(_contrastKey) ?? 1.0;
  }

  @override
  Future<Either<AppFailure, void>> setReaderContrast(double contrast) async {
    try {
      if (_prefs == null) return const Right(null);
      await _prefs.setDouble(_contrastKey, contrast);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  static const String _languageKey = 'language_code';
  static const String _legacyLanguageKey = 'languageCode';

  @override
  Future<Either<AppFailure, String>> getLanguageCode() async {
    try {
      return Right(getLanguageCodeSync());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  String getLanguageCodeSync() {
    if (_prefs == null) return 'en';
    final raw =
        _prefs.getString(_languageKey) ?? _prefs.getString(_legacyLanguageKey);
    if (raw == null) return 'en';
    final normalized = raw.toLowerCase().trim();
    return normalized == 'bn' ? 'bn' : 'en';
  }

  @override
  Future<Either<AppFailure, void>> setLanguageCode(String code) async {
    try {
      if (_prefs == null) return const Right(null);
      final normalized = code.toLowerCase().trim() == 'bn' ? 'bn' : 'en';
      await _prefs.setString(_languageKey, normalized);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  static const String _recentSearchesKey = 'recent_searches';
  static const String _quizStreakKey = 'quiz_streak';
  static const String _quizHighScoreKey = 'quiz_high_score';

  @override
  Future<Either<AppFailure, List<String>>> getRecentSearches() async {
    try {
      final list = _prefs?.getStringList(_recentSearchesKey) ?? [];
      return Right(list);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, void>> saveRecentSearch(String query) async {
    try {
      if (_prefs == null) return const Right(null);
      final list = _prefs.getStringList(_recentSearchesKey) ?? [];
      final updated = [
        query,
        ...list.where((q) => q != query),
      ].take(10).toList();
      await _prefs.setStringList(_recentSearchesKey, updated);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, void>> clearRecentSearches() async {
    try {
      if (_prefs == null) return const Right(null);
      await _prefs.remove(_recentSearchesKey);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, int>> getQuizStreak() async {
    try {
      return Right(_prefs?.getInt(_quizStreakKey) ?? 0);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, void>> saveQuizStreak(int streak) async {
    try {
      if (_prefs == null) return const Right(null);
      await _prefs.setInt(_quizStreakKey, streak);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, int>> getQuizHighScore() async {
    try {
      return Right(_prefs?.getInt(_quizHighScoreKey) ?? 0);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, void>> saveQuizHighScore(int score) async {
    try {
      if (_prefs == null) return const Right(null);
      await _prefs.setInt(_quizHighScoreKey, score);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  static const String _readerFontSizeKey = 'reader_font_size';
  static const String _readerFontFamilyKey = 'reader_font_family';
  static const String _readerThemeKey = 'reader_theme';

  @override
  Future<Either<AppFailure, double>> getReaderFontSize() async {
    try {
      return Right(_prefs?.getDouble(_readerFontSizeKey) ?? 16.0);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, void>> setReaderFontSize(double size) async {
    try {
      if (_prefs == null) return const Right(null);
      await _prefs.setDouble(_readerFontSizeKey, size);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, int>> getReaderFontFamily() async {
    try {
      return Right(
        _prefs?.getInt(_readerFontFamilyKey) ?? 0,
      ); // Default to Serif (0)
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, void>> setReaderFontFamily(int index) async {
    try {
      if (_prefs == null) return const Right(null);
      await _prefs.setInt(_readerFontFamilyKey, index);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, int>> getReaderTheme() async {
    try {
      return Right(
        _prefs?.getInt(_readerThemeKey) ?? 0,
      ); // Default to System (0)
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<AppFailure, void>> setReaderTheme(int index) async {
    try {
      if (_prefs == null) return const Right(null);
      await _prefs.setInt(_readerThemeKey, index);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
