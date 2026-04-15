import 'dart:async';

import 'package:bdnewsreader/application/identity/entitlement_policy.dart';
import 'package:bdnewsreader/domain/entities/subscription.dart';
import 'package:bdnewsreader/domain/facades/auth_facade.dart';
import 'package:bdnewsreader/domain/repositories/premium_repository.dart';
import 'package:bdnewsreader/infrastructure/repositories/subscription_repository_impl.dart';
import 'package:bdnewsreader/infrastructure/services/payment/payment_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPaymentService extends Mock implements PaymentService {}

class _MockUser extends Mock implements User {}

class _FakeAuthFacade implements AuthFacade {
  _FakeAuthFacade({User? currentUser, bool hasUsedTrial = false})
    : _currentUser = currentUser,
      _hasUsedTrial = hasUsedTrial;

  User? _currentUser;
  bool _hasUsedTrial;
  DateTime? recordedTrialStart;
  DateTime? recordedTrialEnd;

  @override
  User? get currentUser => _currentUser;

  @override
  bool get isLoggedIn => _currentUser != null;

  @override
  Future<Map<String, String>> getProfile() async => <String, String>{};

  @override
  Future<bool> hasUsedTrial() async => _hasUsedTrial;

  @override
  Future<void> init() async {}

  @override
  Future<String?> login(String email, String password) async => null;

  @override
  Future<String?> resendEmailVerification(
    String email,
    String password,
  ) async => null;

  @override
  Future<void> logout() async {
    _currentUser = null;
  }

  @override
  Future<void> markTrialUsed({
    required DateTime startedAt,
    required DateTime endsAt,
  }) async {
    if (_currentUser == null) {
      throw StateError('Please sign in to start your free trial.');
    }
    if (_hasUsedTrial) {
      throw StateError('Trial already used.');
    }
    _hasUsedTrial = true;
    recordedTrialStart = startedAt;
    recordedTrialEnd = endsAt;
  }

  @override
  Future<String?> resetPassword(String email) async => null;

  @override
  Future<String?> signInWithGoogle() async => null;

  @override
  Future<String?> signUp(String name, String email, String password) async =>
      null;

  @override
  Future<void> updateProfile({
    required String name,
    required String email,
    String phone = '',
    String role = '',
    String department = '',
    String imagePath = '',
  }) async {}
}

class _FakePremiumRepository implements PremiumRepository {
  _FakePremiumRepository() {
    _snapshotController.add(entitlementSnapshot);
  }
  bool _isPremium = false;
  SubscriptionTier _tier = SubscriptionTier.free;
  final bool _isResolved = true;
  final _premiumController = StreamController<bool>.broadcast();
  final _snapshotController = StreamController<EntitlementSnapshot>.broadcast();

  @override
  EntitlementSnapshot get entitlementSnapshot => EntitlementSnapshot(
    isPremium: _isPremium,
    tier: _tier,
    resolved: _isResolved,
    source: 'test',
    updatedAt: DateTime.utc(2026),
  );

  @override
  Stream<EntitlementSnapshot> get entitlementSnapshotStream =>
      _snapshotController.stream;

  @override
  bool get isPremium => _isPremium;

  @override
  bool get isStatusResolved => _isResolved;

  @override
  Stream<bool> get premiumStatusStream => _premiumController.stream;

  @override
  bool get shouldShowAds => !_isPremium;

  @override
  SubscriptionTier get tier => _tier;

  @override
  Future<void> refreshStatus() async {}

  @override
  Future<void> setPremium(bool value) async {
    _isPremium = value;
    _tier = value ? SubscriptionTier.pro : SubscriptionTier.free;
    _premiumController.add(value);
    _snapshotController.add(entitlementSnapshot);
  }

  Future<void> dispose() async {
    await _premiumController.close();
    await _snapshotController.close();
  }
}

String _dayKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _monthKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubscriptionRepositoryImpl', () {
    late SharedPreferences prefs;
    late _MockPaymentService paymentService;
    late _FakePremiumRepository premiumRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      paymentService = _MockPaymentService();
      premiumRepository = _FakePremiumRepository();
    });

    tearDown(() async {
      await premiumRepository.dispose();
    });

    test('requires login before starting a trial', () async {
      final auth = _FakeAuthFacade();
      final repository = SubscriptionRepositoryImpl(
        prefs,
        paymentService,
        auth,
        premiumRepository,
      );

      final result = await repository.startTrial();

      expect(result.isLeft(), isTrue);
      final message = result.fold((failure) => failure.userMessage, (_) => '');
      expect(message, 'Please sign in to start your free trial.');
    });

    test('records trial usage before granting entitlement', () async {
      final user = _MockUser();
      when(() => user.uid).thenReturn('user-1');

      final auth = _FakeAuthFacade(currentUser: user);
      final repository = SubscriptionRepositoryImpl(
        prefs,
        paymentService,
        auth,
        premiumRepository,
      );

      final result = await repository.startTrial();

      expect(result.isRight(), isTrue);
      expect(auth.recordedTrialStart, isNotNull);
      expect(auth.recordedTrialEnd, isNotNull);
      expect(
        auth.recordedTrialEnd!.difference(auth.recordedTrialStart!).inDays,
        3,
      );
      expect(prefs.getString('subscription_id'), 'trial_sub');
      expect(prefs.getBool('is_premium'), isTrue);
      expect(premiumRepository.isPremium, isTrue);
    });

    test('allows five unique free TTS articles per day', () async {
      final repository = SubscriptionRepositoryImpl(
        prefs,
        paymentService,
        _FakeAuthFacade(),
        premiumRepository,
      );

      for (var i = 0; i < EntitlementPolicy.freeTtsDailyArticleLimit; i++) {
        final result = await repository.recordTtsArticleUsage(
          'https://example.com/article-$i',
        );
        expect(result.isRight(), isTrue);
      }

      final blockedStatus = await repository.getTtsQuotaStatus(
        articleUrl: 'https://example.com/article-over-limit',
      );
      final status = blockedStatus.fold((failure) => throw failure, (s) => s);

      expect(status.usedDailyUniqueArticles, 5);
      expect(status.remainingDailyArticles, 0);
      expect(status.canStartTts, isFalse);
    });

    test('does not count the same free TTS article twice', () async {
      final repository = SubscriptionRepositoryImpl(
        prefs,
        paymentService,
        _FakeAuthFacade(),
        premiumRepository,
      );

      await repository.recordTtsArticleUsage('https://example.com/replay');
      await repository.recordTtsArticleUsage('https://example.com/replay');

      final sameArticleStatus = await repository.getTtsQuotaStatus(
        articleUrl: 'https://example.com/replay',
      );
      final nextArticleStatus = await repository.getTtsQuotaStatus(
        articleUrl: 'https://example.com/next',
      );

      final same = sameArticleStatus.fold((failure) => throw failure, (s) => s);
      final next = nextArticleStatus.fold((failure) => throw failure, (s) => s);

      expect(same.articleAlreadyCounted, isTrue);
      expect(same.canStartTts, isTrue);
      expect(next.usedDailyUniqueArticles, 1);
      expect(next.usedMonthlyUniqueArticles, 1);
    });

    test('blocks free TTS when monthly quota is exhausted', () async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues(<String, Object>{
        'tts_usage_day': _dayKey(now),
        'tts_usage_month': _monthKey(now),
        'tts_usage_daily_articles': <String>[],
        'tts_usage_monthly_articles': List<String>.generate(
          EntitlementPolicy.freeTtsMonthlyArticleLimit,
          (index) => 'article-$index',
        ),
      });
      prefs = await SharedPreferences.getInstance();
      final repository = SubscriptionRepositoryImpl(
        prefs,
        paymentService,
        _FakeAuthFacade(),
        premiumRepository,
      );

      final quota = await repository.getTtsQuotaStatus(
        articleUrl: 'https://example.com/month-over-limit',
      );
      final status = quota.fold((failure) => throw failure, (s) => s);

      expect(status.usedMonthlyUniqueArticles, 150);
      expect(status.remainingMonthlyArticles, 0);
      expect(status.canStartTts, isFalse);
    });

    test('premium TTS remains unlimited', () async {
      await premiumRepository.setPremium(true);
      final repository = SubscriptionRepositoryImpl(
        prefs,
        paymentService,
        _FakeAuthFacade(),
        premiumRepository,
      );

      final quota = await repository.getTtsQuotaStatus(
        articleUrl: 'https://example.com/premium',
      );
      final status = quota.fold((failure) => throw failure, (s) => s);

      expect(status.isPremium, isTrue);
      expect(status.canStartTts, isTrue);
    });
  });
}
