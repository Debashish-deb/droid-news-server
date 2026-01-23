import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdnewsreader/core/language_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageProvider Tests', () {
    test('Initializes with default English locale when no prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = LanguageProvider();
      
      // Allow async load to complete
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(provider.locale.languageCode, 'en');
    });

    test('Initializes with stored locale', () async {
      SharedPreferences.setMockInitialValues({'languageCode': 'bn'});
      final provider = LanguageProvider();
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(provider.locale.languageCode, 'bn');
    });

    test('setLocale updates locale and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = LanguageProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      await provider.setLocale('bn');
      
      expect(provider.locale.languageCode, 'bn');
      
      // Verify persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('languageCode'), 'bn');
    });
    
    test('resetLocale clears persistence', () async {
      SharedPreferences.setMockInitialValues({'languageCode': 'bn'});
      final provider = LanguageProvider();
      await Future.delayed(const Duration(milliseconds: 50)); // Wait for load
      
      await provider.resetLocale();
      
      expect(provider.locale.languageCode, 'en');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('languageCode'), false);
    });
  });
}
