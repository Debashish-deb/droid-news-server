import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/persistence/offline_service.dart';

/// Provider to check if article is downloaded
final offlineStatusProvider = FutureProvider.family<bool, String>((
  ref,
  url,
) async {
  return await OfflineService.isArticleDownloaded(url);
});

/// Provider for downloaded articles count
final downloadedCountProvider = FutureProvider<int>((ref) async {
  return await OfflineService.getDownloadedCount();
});
