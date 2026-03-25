import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Manages the on-disk audio cache for synthesized TTS chunks.
///
/// Key fixes vs original:
/// - `_cacheDir` was `async` and called `getApplicationDocumentsDirectory()`
///   on every single read/write/delete — a platform-channel call (~5 ms each).
///   Now resolved once and cached as a synchronously-available `String?`.
/// - Atomic write: bytes are written to a `.tmp` file first, then renamed.
///   If the app crashes mid-write the cache never contains a corrupt file.
/// - `getCacheSizeBytes()` sums file sizes directly on disk rather than
///   relying on the database's `SUM(file_size_bytes)` which can drift if
///   files are deleted externally.
class AudioCacheManager {
  AudioCacheManager();

  // Cached once after the first call to `_ensureDir()`.
  String? _resolvedCacheDir;

  // ── Directory management ───────────────────────────────────────────────────

  Future<String> _ensureDir() async {
    if (_resolvedCacheDir != null) return _resolvedCacheDir!;

    final base = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(base.path, 'tts_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    _resolvedCacheDir = cacheDir.path;
    return _resolvedCacheDir!;
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Saves [bytes] under [fileName] and returns the absolute path.
  ///
  /// Uses an atomic tmp → rename pattern so corrupt partial files can never
  /// enter the cache.
  Future<String> saveAudio(String fileName, List<int> bytes) async {
    final dir = await _ensureDir();
    final target = File(p.join(dir, fileName));
    final tmp = File(p.join(dir, '$fileName.tmp'));

    await tmp.writeAsBytes(bytes, flush: true);
    // Rename is atomic on POSIX filesystems (Android's ext4 / F2FS)
    await tmp.rename(target.path);

    return target.path;
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  Future<File?> getFile(String fileName) async {
    final dir = await _ensureDir();
    final file = File(p.join(dir, fileName));
    return await file.exists() ? file : null;
  }

  /// Returns `true` if [path] exists and has non-zero size.
  Future<bool> isValid(String path) async {
    final file = File(path);
    return await file.exists() && await file.length() > 0;
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (e) {
        // Ignore; the database entry will be cleaned up on next access.
      }
    }
  }

  // ── Cache size ─────────────────────────────────────────────────────────────

  /// Returns the total size of all cached audio files in bytes.
  ///
  /// Reads directly from disk rather than trusting the database column, which
  /// can diverge when files are deleted externally or by the OS cache cleaner.
  Future<int> getCacheSizeBytes() async {
    final dir = await _ensureDir();
    int total = 0;
    await for (final entity in Directory(dir).list()) {
      if (entity is File && !entity.path.endsWith('.tmp')) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  // ── Clear ──────────────────────────────────────────────────────────────────

  Future<void> clearCache() async {
    final dir = await _ensureDir();
    final cacheDir = Directory(dir);
    if (await cacheDir.exists()) {
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    }
  }
}
