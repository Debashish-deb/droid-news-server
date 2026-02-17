import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';



class AudioCacheManager {
  AudioCacheManager();

  Future<String> get _cacheDir async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(join(dir.path, 'tts_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  Future<String> saveAudio(String fileName, List<int> bytes) async {
    final dir = await _cacheDir;
    final file = File(join(dir, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<File?> getFile(String fileName) async {
    final dir = await _cacheDir;
    final file = File(join(dir, fileName));
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<void> clearCache() async {
    final dir = await _cacheDir;
    final cacheDir = Directory(dir);
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }

  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
