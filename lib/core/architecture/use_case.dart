import 'either.dart';
import 'failure.dart';

/// Base interface for all use cases in the application.
///
/// Use cases represent business logic operations and follow the Single
/// Responsibility Principle. Each use case should do one thing and do it well.
///
/// Type parameters:
/// - [Type]: The success result type
/// - [Params]: The parameters required to execute the use case
///
/// Example:
/// ```dart
/// class FetchNewsUseCase implements UseCase<List<Article>, FetchNewsParams> {
///   final NewsRepository repository;
///
///   FetchNewsUseCase(this.repository);
///
///   @override
///   Future<Either<AppFailure, List<Article>>> execute(FetchNewsParams params) async {
///     return await repository.getNews(page: params.page, limit: params.limit);
///   }
/// }
/// ```
abstract class UseCase<Type, Params> {
  /// Executes the use case with the given [params].
  ///
  /// Returns an [Either] with:
  /// - [Left] containing an [AppFailure] if the operation failed
  /// - [Right] containing the result of type [Type] if successful
  Future<Either<AppFailure, Type>> execute(Params params);
}

/// Use this class when a use case doesn't require any parameters.
///
/// Example:
/// ```dart
/// class GetCurrentUserUseCase implements UseCase<User, NoParams> {
///   @override
///   Future<Either<AppFailure, User>> execute(NoParams params) async {
///
///   }
/// }
///
///
/// final result = await getCurrentUserUseCase.execute(NoParams());
/// ```
class NoParams {
  const NoParams();
}

/// Base class for use cases that can be called directly (syntactic sugar).
///
/// This allows use cases to be called like functions:
/// ```dart
/// final result = await useCase(params);
/// ```
/// instead of:
/// ```dart
/// final result = await useCase.execute(params);
/// ```
abstract class CallableUseCase<Type, Params> implements UseCase<Type, Params> {
  Future<Either<AppFailure, Type>> call(Params params) => execute(params);
}

/// Base class for synchronous use cases.
///
/// Use this for use cases that don't require asynchronous operations,
/// such as data validation or transformation.
///
/// Example:
/// ```dart
/// class ValidateEmailUseCase implements SyncUseCase<bool, String> {
///   @override
///   Either<AppFailure, bool> execute(String params) {
///     if (params.contains('@')) {
///       return Right(true);
///     }
///     return Left(ValidationFailure('Invalid email format'));
///   }
/// }
/// ```
abstract class SyncUseCase<Type, Params> {
  /// Executes the synchronous use case with the given [params].
  Either<AppFailure, Type> execute(Params params);
}

/// Base class for stream-based use cases.
///
/// Use this for use cases that emit multiple values over time,
/// such as real-time data subscriptions or progress tracking.
///
/// Example:
/// ```dart
/// class WatchNewsUpdatesUseCase implements StreamUseCase<List<Article>, NoParams> {
///   final NewsRepository repository;
///
///   WatchNewsUpdatesUseCase(this.repository);
///
///   @override
///   Stream<Either<AppFailure, List<Article>>> execute(NoParams params) {
///     return repository.watchNews();
///   }
/// }
/// ```
abstract class StreamUseCase<Type, Params> {
  /// Executes the stream use case with the given [params].
  ///
  /// Returns a stream of [Either] values, allowing for error handling
  /// at each emission.
  Stream<Either<AppFailure, Type>> execute(Params params);
}
