import 'package:shared_preferences/shared_preferences.dart';
import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../domain/entities/news_source.dart';
import '../../domain/repositories/source_repository.dart';
import '../services/news/rss_service.dart';

class SourceRepositoryImpl implements SourceRepository {
  SourceRepositoryImpl(this._prefs);
  
  final SharedPreferences? _prefs;
  
  static const String _disabledSourcesKey = 'disabled_news_sources';

  @override
  Future<Either<AppFailure, List<NewsSource>>> getAllSources() async {
    try {
      final disabledIds = getDisabledSourceIdsSync();
      final List<NewsSource> sources = [];

      RssService.feeds.forEach((category, langMap) {
        langMap.forEach((lang, urls) {
          for (final url in urls) {
            final uri = Uri.tryParse(url);
            String name = uri?.host.replaceAll('www.', '') ?? url;
            if (name.contains('bbc.co.uk')) {
              name = 'BBC News';
            } else if (name.contains('google.com')) {
              name = 'Google News ($lang)';
            } else if (name.contains('prothomalo.com')) {
              name = lang == 'bn' ? 'প্রথম আলো' : 'Prothom Alo';
            } else if (name.contains('jugantor.com')) {
              name = lang == 'bn' ? 'যুগান্তর' : 'Jugantor';
            } else if (name.contains('ittefaq.com.bd')) {
              name = lang == 'bn' ? 'ইত্তেফাক' : 'Ittefaq';
            } else if (name.contains('samakal.com')) {
              name = lang == 'bn' ? 'সমকাল' : 'Samakal';
            } else if (name.contains('dhakatribune.com')) {
              name = 'Dhaka Tribune';
            } else if (name.contains('thedailystar.net')) {
              name = 'The Daily Star';
            }
            
            sources.add(NewsSource(
              id: url,
              name: name,
              url: url,
              language: lang,
              category: category,
              isEnabled: !disabledIds.contains(url),
            ));
          }
        });
      });
      
      return Right(sources);
    } catch (e) {
      return Left(CacheFailure('Failed to load sources: $e'));
    }
  }

  @override
  Future<Either<AppFailure, List<NewsSource>>> getEnabledSources() async {
    final allResult = await getAllSources();
    return allResult.fold(
      (failure) => Left(failure),
      (sources) => Right(sources.where((s) => s.isEnabled).toList()),
    );
  }

  @override
  Set<String> getDisabledSourceIdsSync() {
    if (_prefs == null) return {};
    final list = _prefs.getStringList(_disabledSourcesKey) ?? [];
    return list.toSet();
  }

  @override
  Future<Either<AppFailure, void>> toggleSourceEnabled(String sourceId, bool isEnabled) async {
    try {
      final disabledIds = getDisabledSourceIdsSync();
      if (isEnabled) {
        disabledIds.remove(sourceId);
      } else {
        disabledIds.add(sourceId);
      }
      if (_prefs == null) return const Right(null);
      await _prefs.setStringList(_disabledSourcesKey, disabledIds.toList());
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to toggle source: $e'));
    }
  }

  @override
  Future<Either<AppFailure, void>> resetToDefault() async {
    try {
      if (_prefs == null) return const Right(null);
      await _prefs.remove(_disabledSourcesKey);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Failed to reset sources: $e'));
    }
  }
}
