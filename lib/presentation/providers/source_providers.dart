import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../domain/entities/news_source.dart';
import '../../domain/repositories/source_repository.dart';
import '../../infrastructure/repositories/source_repository_impl.dart';
import 'news_providers.dart';

/// Provides the SourceRepository instance
final sourceRepositoryProvider = Provider<SourceRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SourceRepositoryImpl(prefs);
});

/// Async notifier for loading and managing the list of sources
class SourcesNotifier extends AsyncNotifier<List<NewsSource>> {
  @override
  Future<List<NewsSource>> build() async {
    return _loadSources();
  }

  Future<List<NewsSource>> _loadSources() async {
    final repo = ref.read(sourceRepositoryProvider);
    final result = await repo.getAllSources();
    return result.fold(
      (failure) => throw failure,
      (sources) => sources,
    );
  }

  Future<void> toggleSource(String sourceId, bool isEnabled) async {
    final repo = ref.read(sourceRepositoryProvider);
    final result = await repo.toggleSourceEnabled(sourceId, isEnabled);
    
    result.fold(
      (failure) {
        // Just let it be, handled by UI possibly if we threw
      },
      (_) {
        // Reload sources
        state = const AsyncValue.loading();
        _loadSources().then((sources) {
          state = AsyncValue.data(sources);
          // Invalidate news provider so it re-fetches feeds taking new disabled sources into account
          ref.invalidate(newsProvider);
        });
      },
    );
  }

  Future<void> resetToDefault() async {
    final repo = ref.read(sourceRepositoryProvider);
    await repo.resetToDefault();
    state = const AsyncValue.loading();
    _loadSources().then((sources) {
      state = AsyncValue.data(sources);
      ref.invalidate(newsProvider);
    });
  }
}

final sourcesProvider = AsyncNotifierProvider<SourcesNotifier, List<NewsSource>>(() {
  return SourcesNotifier();
});

/// Sync provider for the core network/RSS services to know what's disabled without returning Futures
/// We can read it synchronously from SourceRepository.
final disabledSourcesProvider = Provider<Set<String>>((ref) {
  // We depend on sourcesProvider so string updates trigger rebuilds if needed,
  // but we can also just read synchronously from prefs via the repository if we 
  // want to avoid async loading.
  // By watching the async provider, we ensure this Provider rebuilds whenever the user toggles a source.
  ref.watch(sourcesProvider);
  
  final repo = ref.watch(sourceRepositoryProvider);
  return repo.getDisabledSourceIdsSync();
});
