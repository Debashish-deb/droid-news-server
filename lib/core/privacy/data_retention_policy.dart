import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../../platform/persistence/app_database.dart';

// Enforces data retention policies (e.g. clear cache older than 30 days)
class DataRetentionPolicy {
  DataRetentionPolicy(this._db);
  final AppDatabase _db;

  Future<void> enforce() async {
    debugPrint('🛡️ Enforcing Data Retention Policy...');
    
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final ninetyDaysAgo = now.subtract(const Duration(days: 90));

    try {
      // 1. Delete articles older than 30 days if NOT bookmarked
      final bookmarkedIds = _db.selectOnly(_db.bookmarks)..addColumns([_db.bookmarks.articleId]);
      
      final deletedArticlesCount = await (_db.delete(_db.articles)
        ..where((t) => t.publishedAt.isSmallerThanValue(thirtyDaysAgo))
        ..where((t) => t.id.isNotInQuery(bookmarkedIds))
      ).go();
      
      if (deletedArticlesCount > 0) {
        debugPrint('🗑️ Cleaned $deletedArticlesCount expired articles.');
      }

      // 2. Clear synced journal entries older than 7 days
      final deletedJournalCount = await (_db.delete(_db.syncJournal)
        ..where((t) => t.syncStatus.equals(1) & t.createdAt.isSmallerThanValue(sevenDaysAgo))
      ).go();

      if (deletedJournalCount > 0) {
        debugPrint('🗑️ Cleaned $deletedJournalCount synced journal entries.');
      }

      // 3. Clear reading history older than 90 days
      final deletedHistoryCount = await (_db.delete(_db.readingHistory)
        ..where((t) => t.readAt.isSmallerThanValue(ninetyDaysAgo))
      ).go();

      if (deletedHistoryCount > 0) {
        debugPrint('🗑️ Cleaned $deletedHistoryCount old reading history records.');
      }

    } catch (e) {
      debugPrint('⚠️ Data Retention Enforcement failed: $e');
    }
    
    debugPrint('✅ Data Retention Policy enforced.');
  }
}
