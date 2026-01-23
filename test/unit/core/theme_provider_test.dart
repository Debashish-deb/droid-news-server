import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdnewsreader/core/theme_provider.dart';

@GenerateMocks([SharedPreferences])
import 'theme_provider_test.mocks.dart';

void main() {
  late MockSharedPreferences mockPrefs;
  late ThemeProvider themeProvider;

  setUp(() {
    mockPrefs = MockSharedPreferences();
    
    // Default mocks
    when(mockPrefs.getString(any)).thenReturn(null);
    when(mockPrefs.setDouble(any, any)).thenAnswer((_) async => true);
    when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
    when(mockPrefs.getInt(any)).thenReturn(null);
    when(mockPrefs.setInt(any, any)).thenAnswer((_) async => true);
    when(mockPrefs.getDouble(any)).thenReturn(null);

    themeProvider = ThemeProvider(mockPrefs);
  });

  group('ThemeProvider Tests', () {
    test('Initializes with default light theme when no prefs', () {
      expect(themeProvider.appThemeMode, AppThemeMode.light);
    });

    test('Initializes with stored theme', () {
      // Theme stored as int index
      when(mockPrefs.getInt('theme_mode')).thenReturn(AppThemeMode.dark.index);
      final provider = ThemeProvider(mockPrefs);
      expect(provider.appThemeMode, AppThemeMode.dark);
    });

    test('toggleTheme sets theme and notifies listeners', () async {
      bool notified = false;
      themeProvider.addListener(() {
        notified = true;
      });

      await themeProvider.toggleTheme(AppThemeMode.dark);

      expect(themeProvider.appThemeMode, AppThemeMode.dark);
      expect(notified, true);
      verify(mockPrefs.setInt('theme_mode', AppThemeMode.dark.index)).called(1);
    });
    
    test('updateReaderPrefs persists values', () async {
      await themeProvider.updateReaderPrefs(lineHeight: 2.0, contrast: 1.5);
      
      verify(mockPrefs.setDouble('reader_line_height', 2.0)).called(1);
      verify(mockPrefs.setDouble('reader_contrast', 1.5)).called(1);
      expect(themeProvider.readerLineHeight, 2.0);
      expect(themeProvider.readerContrast, 1.5);
    });
  });
}
