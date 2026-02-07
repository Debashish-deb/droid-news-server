import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../core/architecture/use_case.dart';
import '../../domain/interfaces/subscription_repository.dart' show SubscriptionRepository;

/// Use case for validating if a user can access a specific feature.
///
/// This centralizes feature gating logic, ensuring consistent
/// access control across the application.
class ValidateFeatureAccessUseCase
    implements UseCase<bool, ValidateFeatureAccessParams> {
  const ValidateFeatureAccessUseCase(this._repository);
  final SubscriptionRepository _repository;

  @override
  Future<Either<AppFailure, bool>> execute(
    ValidateFeatureAccessParams params,
  ) async {
    if (params.featureId.trim().isEmpty) {
      return const Left(
        ValidationFailure('Feature ID cannot be empty', {
          'featureId': 'Feature ID is required',
        }),
      );
    }

    final result = await _repository.canAccessFeature(params.featureId);

    return result.fold((failure) => Left(failure), (hasAccess) {
      if (!hasAccess && params.throwOnDenied) {
        return Left(
          FeatureLockedFailure(
            params.featureId,
            params.requiredTier ?? 'Premium',
          ),
        );
      }

      return Right(hasAccess);
    });
  }
}

/// Parameters for validating feature access.
class ValidateFeatureAccessParams {
  const ValidateFeatureAccessParams({
    required this.featureId,
    this.throwOnDenied = false,
    this.requiredTier,
  });
  final String featureId;
  final bool throwOnDenied;
  final String? requiredTier;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidateFeatureAccessParams &&
          runtimeType == other.runtimeType &&
          featureId == other.featureId &&
          throwOnDenied == other.throwOnDenied &&
          requiredTier == other.requiredTier;

  @override
  int get hashCode => Object.hash(featureId, throwOnDenied, requiredTier);

  @override
  String toString() =>
      'ValidateFeatureAccessParams(featureId: $featureId, throwOnDenied: $throwOnDenied)';
}
