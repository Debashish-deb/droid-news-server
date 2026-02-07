import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../core/architecture/use_case.dart';
import '../../domain/entities/subscription.dart' show Subscription;
import '../../domain/interfaces/subscription_repository.dart' show SubscriptionRepository;


/// Use case for checking the current subscription status.
///
/// This encapsulates subscription status retrieval and validation logic.
class CheckSubscriptionStatusUseCase
    implements UseCase<Subscription, NoParams> {
  const CheckSubscriptionStatusUseCase(this._repository);
  final SubscriptionRepository _repository;

  @override
  Future<Either<AppFailure, Subscription>> execute(NoParams params) async {
    final result = await _repository.validateAndRefreshSubscription();

    return result.fold((failure) => Left(failure), (subscription) {
      if (subscription.daysUntilExpiration != null &&
          subscription.daysUntilExpiration! <= 7 &&
          subscription.daysUntilExpiration! > 0) {
      }

      return Right(subscription);
    });
  }
}
