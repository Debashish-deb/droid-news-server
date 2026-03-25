import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../core/enums/theme_mode.dart';

/// Repository interface for app settings (Theme, Reader Preferences, etc.)
abstract class SettingsRepository {
  /// Get current theme mode.
  Future<Either<AppFailure, AppThemeMode>> getThemeMode();

  /// Get current theme mode synchronously.
  AppThemeMode getThemeModeSync();

  /// Set theme mode.
  Future<Either<AppFailure, void>> setThemeMode(AppThemeMode mode);

  /// Get reader line height.
  Future<Either<AppFailure, double>> getReaderLineHeight();

  /// Get reader line height synchronously.
  double getReaderLineHeightSync();

  /// Set reader line height.
  Future<Either<AppFailure, void>> setReaderLineHeight(double height);

  /// Get reader contrast.
  Future<Either<AppFailure, double>> getReaderContrast();

  /// Get reader contrast synchronously.
  double getReaderContrastSync();

  /// Set reader contrast.
  Future<Either<AppFailure, void>> setReaderContrast(double contrast);

  /// Get current language code (en, bn).
  Future<Either<AppFailure, String>> getLanguageCode();

  /// Get current language code synchronously.
  String getLanguageCodeSync();

  /// Set current language code.
  Future<Either<AppFailure, void>> setLanguageCode(String code);

  /// Get recent searches.
  Future<Either<AppFailure, List<String>>> getRecentSearches();

  /// Save search query.
  Future<Either<AppFailure, void>> saveRecentSearch(String query);

  /// Clear all recent search queries.
  Future<Either<AppFailure, void>> clearRecentSearches();

  /// Get quiz streak.
  Future<Either<AppFailure, int>> getQuizStreak();

  /// Save quiz streak.
  Future<Either<AppFailure, void>> saveQuizStreak(int streak);

  /// Get quiz high score.
  Future<Either<AppFailure, int>> getQuizHighScore();

  /// Save quiz high score.
  Future<Either<AppFailure, void>> saveQuizHighScore(int score);

  /// Get reader font size.
  Future<Either<AppFailure, double>> getReaderFontSize();

  /// Set reader font size.
  Future<Either<AppFailure, void>> setReaderFontSize(double size);

  /// Get reader font family index.
  Future<Either<AppFailure, int>> getReaderFontFamily();

  /// Set reader font family index.
  Future<Either<AppFailure, void>> setReaderFontFamily(int index);

  /// Get reader theme index.
  Future<Either<AppFailure, int>> getReaderTheme();

  /// Set reader theme index.
  Future<Either<AppFailure, void>> setReaderTheme(int index);
}
