import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:bdnewsreader/core/architecture/either.dart';
import 'package:bdnewsreader/core/architecture/failure.dart';
import 'package:bdnewsreader/core/architecture/use_case.dart'; // for NoParams
import 'package:bdnewsreader/domain/entities/subscription.dart';
import 'package:bdnewsreader/domain/repositories/subscription_repository.dart';
import 'package:bdnewsreader/domain/use_cases/subscription/check_subscription_status_use_case.dart';

@GenerateMocks([SubscriptionRepository])
import 'check_subscription_status_use_case_test.mocks.dart';

void main() {
  provideDummy<Either<AppFailure, Subscription>>(
    Right(Subscription(
      id: 'test',
      userId: 'test',
      tier: SubscriptionTier.free,
      status: SubscriptionStatus.active,
      startDate: DateTime.now(),
    )),
  );

  late CheckSubscriptionStatusUseCase useCase;
  late MockSubscriptionRepository mockRepository;

  setUp(() {
    mockRepository = MockSubscriptionRepository();
    useCase = CheckSubscriptionStatusUseCase(mockRepository);
  });

  group('CheckSubscriptionStatusUseCase', () {
    test('should return active subscription status', () async {
      // Arrange
      final subscription = Subscription(
        id: 'sub-123',
        userId: 'user-123',
        tier: SubscriptionTier.pro,
        status: SubscriptionStatus.active,
        startDate: DateTime(2025),
        endDate: DateTime(2026),
      );

      // Stub all methods that might be called
      when(mockRepository.validateAndRefreshSubscription())
          .thenAnswer((_) async => Right(subscription));
      when(mockRepository.getCurrentSubscription())
          .thenAnswer((_) async => Right(subscription));

      // Act
      final result = await useCase.execute(const NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (sub) {
          expect(sub.tier, SubscriptionTier.pro);
          expect(sub.status, SubscriptionStatus.active);
          expect(sub.isActive, true);
        },
      );

      verify(mockRepository.validateAndRefreshSubscription()).called(1);
    });

    test('should return free tier for no subscription', () async {
      // Arrange
      final freeSubscription = Subscription(
        id: 'free',
        userId: 'user-123',
        tier: SubscriptionTier.free,
        status: SubscriptionStatus.active,
        startDate: DateTime.now(),
      );

      when(mockRepository.validateAndRefreshSubscription())
          .thenAnswer((_) async => Right(freeSubscription));
      when(mockRepository.getCurrentSubscription())
          .thenAnswer((_) async => Right(freeSubscription));

      // Act
      final result = await useCase.execute(const NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (sub) {
          expect(sub.tier, SubscriptionTier.free);
          expect(sub.isActive, true); // free tier is active
        },
      );
    });

    test('should detect expired subscription', () async {
      // Arrange
      final expiredSub = Subscription(
        id: 'sub-123',
        userId: 'user-123',
        tier: SubscriptionTier.pro,
        status: SubscriptionStatus.expired,
        startDate: DateTime(2024),
        endDate: DateTime(2024, 12, 31),
      );

      when(mockRepository.validateAndRefreshSubscription())
          .thenAnswer((_) async => Right(expiredSub));
      when(mockRepository.getCurrentSubscription())
          .thenAnswer((_) async => Right(expiredSub));

      // Act
      final result = await useCase.execute(const NoParams());

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Expected success'),
        (sub) {
          expect(sub.status, SubscriptionStatus.expired);
          expect(sub.isExpired, true);
          expect(sub.isActive, false); // expired means not active
        },
      );
    });

    test('should return SubscriptionFailure on repository error', () async {
      // Arrange
      const failure = SubscriptionFailure('Failed to fetch subscription');
      when(mockRepository.validateAndRefreshSubscription())
          .thenAnswer((_) async => const Left(failure));
      when(mockRepository.getCurrentSubscription())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase.execute(const NoParams());

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (f) {
          expect(f, isA<SubscriptionFailure>());
          expect(f.message, contains('Failed to fetch'));
        },
        (_) => fail('Expected failure'),
      );
    });

    test('should handle network failure', () async {
      // Arrange
      const failure = NetworkFailure('No internet connection');
      when(mockRepository.validateAndRefreshSubscription())
          .thenAnswer((_) async => const Left(failure));
      when(mockRepository.getCurrentSubscription())
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase.execute(const NoParams());

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('Expected failure'),
      );
    });
  });
}
