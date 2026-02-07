import 'dart:async';
import '../../../domain/repositories/sync_repository.dart';

// Captures granular user interaction signals for the AI Engine.
// 
// Signals:
// - Dwell Time (Read duration)
// - Scroll Velocity (Skimming vs Reading)
// - Explicit Actions (Like, Share, Skip)
class AIEventCollector {

  AIEventCollector(this._syncRepo);
  final SyncRepository _syncRepo;
  final StreamController<Map<String, dynamic>> _stream = StreamController.broadcast();

  Stream<Map<String, dynamic>> get eventStream => _stream.stream;

  void logArticleOpen(String articleId) {
    _emit('article_open', {'articleId': articleId});
  }

  void logReadDuration(String articleId, int seconds) {
    _emit('read_duration', {'articleId': articleId, 'duration': seconds});
  }

  void logSkip(String articleId) {
    _emit('article_skip', {'articleId': articleId});
  }

  void _emit(String action, Map<String, dynamic> payload) {
    final event = {
      'entityType': 'ai_signal',
      'action': action,
      ...payload,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _stream.add(event);

    _syncRepo.queueEvent(event);
  }

  void dispose() {
    _stream.close();
  }
}
