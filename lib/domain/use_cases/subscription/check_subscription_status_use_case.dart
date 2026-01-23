import '../../../core/architecture/either.dart';
import '../../../core/architecture/failure.dart';
import '../../../core/architecture/use_case.dart';
import '../../entities/subscription.dart';
import '../../repositories/subscription_repository.dart';

/// Use case for checking the current subscription status.
///
/// This encapsulates subscription status retrieval and validation logic.
class CheckSubscriptionStatusUseCase
    implements UseCase<Subscription, NoParams> {
  const CheckSubscriptionStatusUseCase(this._repository);
  final SubscriptionRepository _repository;

  @override
  Future<Either<AppFailure, Subscription>> execute(NoParams params) async {
    // Get and validate current subscription
    final result = await _repository.validateAndRefreshSubscription();

    return result.fold((failure) => Left(failure), (subscription) {
      // Additional business logic: warn if subscription is expiring soon
      if (subscription.daysUntilExpiration != null &&
          subscription.daysUntilExpiration! <= 7 &&
          subscription.daysUntilExpiration! > 0) {
        // Log or trigger warning (in a real implementation)
        // This is where you might trigger a notification or analytics event
      }

      return Right(subscription);
    });
  }
}
