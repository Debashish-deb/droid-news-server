import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../entities/news_source.dart';

abstract class SourceRepository {
  /// Gets a list of all available sources, with their current enabled states.
  Future<Either<AppFailure, List<NewsSource>>> getAllSources();

  /// Gets a list of only the currently enabled sources.
  Future<Either<AppFailure, List<NewsSource>>> getEnabledSources();

  /// Gets a set of IDs (URLs) of sources that have been disabled.
  Set<String> getDisabledSourceIdsSync();

  /// Toggles the enabled state of a specific source.
  Future<Either<AppFailure, void>> toggleSourceEnabled(String sourceId, bool isEnabled);

  /// Resets all sources to enabled.
  Future<Either<AppFailure, void>> resetToDefault();
}
