import 'package:bdnewsreader/presentation/providers/app_settings_providers.dart'
    show AppSettingsNotifier;
import 'package:bdnewsreader/presentation/providers/language_providers.dart'
    show LanguageNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdnewsreader/presentation/providers/theme_providers.dart';
import 'package:bdnewsreader/core/enums/theme_mode.dart';
import 'package:bdnewsreader/infrastructure/repositories/settings_repository_impl.dart';
import 'package:bdnewsreader/application/sync/sync_orchestrator.dart';
import 'package:bdnewsreader/domain/repositories/premium_repository.dart';
import 'package:bdnewsreader/domain/entities/subscription.dart'
    show SubscriptionTier;
import 'package:bdnewsreader/core/architecture/either.dart';
import 'package:bdnewsreader/core/architecture/failure.dart';
import 'package:bdnewsreader/presentation/providers/language_providers.dart';
import 'package:bdnewsreader/presentation/providers/app_settings_providers.dart';
import 'package:mockito/annotations.dart';

import 'theme_provider_test.mocks.dart';

@GenerateMocks([SharedPreferences])
void main() {
  provideDummy<Either<AppFailure, AppThemeMode>>(
    const Right(AppThemeMode.system),
  );
  provideDummy<Either<AppFailure, double>>(const Right(1.0));
  provideDummy<Either<AppFailure, void>>(const Right(null));

  late MockSharedPreferences mockPrefs;
  late ThemeNotifier themeNotifier;
  late SettingsRepositoryImpl repository;
  late _MockSyncOrchestrator mockSync;
  late _MockPremiumRepository mockPremiumRepository;

  setUp(() {
    mockPrefs = MockSharedPreferences();
    mockPremiumRepository = _MockPremiumRepository();
    // No need to stub mockPremiumRepository.premiumStatusStream here
    // because it's already overridden in the _MockPremiumRepository class.

    repository = SettingsRepositoryImpl(mockPrefs);
    mockSync = _MockSyncOrchestrator();
    // Default mock behavior
    when(mockPrefs.getString('theme')).thenReturn(null);
    when(mockPrefs.getDouble('reader_line_height')).thenReturn(null);
    when(mockPrefs.getDouble('reader_contrast')).thenReturn(null);
    when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);
    when(mockPrefs.setDouble(any, any)).thenAnswer((_) async => true);
  });

  test('Initializes with system default when no prefs', () async {
    themeNotifier = ThemeNotifier(repository, mockSync, mockPremiumRepository);
    await themeNotifier.initialize();
    expect(themeNotifier.current.mode, AppThemeMode.system);
  });

  test('Initializes with stored legacy dark theme as system', () async {
    when(mockPrefs.getString('theme')).thenReturn(AppThemeMode.dark.name);
    themeNotifier = ThemeNotifier(repository, mockSync, mockPremiumRepository);
    await themeNotifier.initialize();
    expect(themeNotifier.current.mode, AppThemeMode.system);
  });

  test('setTheme normalizes legacy dark selection to system', () async {
    themeNotifier = ThemeNotifier(repository, mockSync, mockPremiumRepository);
    await themeNotifier.initialize();

    await themeNotifier.setTheme(AppThemeMode.dark);

    expect(themeNotifier.current.mode, AppThemeMode.system);
    verifyNever(mockPrefs.setString('theme', any));
  });

  test('setTheme keeps amoled selection and persists it', () async {
    themeNotifier = ThemeNotifier(repository, mockSync, mockPremiumRepository);
    await themeNotifier.initialize();

    await themeNotifier.setTheme(AppThemeMode.amoled);

    expect(themeNotifier.current.mode, AppThemeMode.amoled);
    verify(mockPrefs.setString('theme', AppThemeMode.amoled.name)).called(1);
  });

  test('Reader preferences update correctly', () async {
    when(mockPrefs.getDouble('reader_contrast')).thenReturn(1.5);
    themeNotifier = ThemeNotifier(repository, mockSync, mockPremiumRepository);
    themeNotifier.initializeSync();
    expect(themeNotifier.current.readerContrast, 1.5);
  });
}

class _MockSyncOrchestrator extends Mock implements SyncOrchestrator {
  @override
  void registerThemeNotifier(ThemeNotifier? notifier) {}

  @override
  void connectProviders({
    required ThemeNotifier themeNotifier,
    required LanguageNotifier languageNotifier,
    required AppSettingsNotifier appSettingsNotifier,
  }) {}

  @override
  Future<void> pushSettings({bool immediate = false}) async {}
}

class _MockPremiumRepository extends Mock implements PremiumRepository {
  @override
  Stream<bool> get premiumStatusStream => Stream.value(false);

  @override
  bool get isPremium => false;

  @override
  SubscriptionTier get tier => SubscriptionTier.free;

  @override
  bool get isStatusResolved => true;

  @override
  bool get shouldShowAds => true;

  @override
  Future<void> refreshStatus() async {}

  @override
  Future<void> setPremium(bool value) async {}
}
