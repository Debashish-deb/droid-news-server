import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

/// Ensures the native SQLite library is correctly loaded on Android.
/// Must be called before any Drift database is opened.
/// This is async because on old Android versions, the workaround
/// needs to invoke a platform channel to load the library from Java.
Future<void> setupSqliteLibrary() async {
  await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
}
