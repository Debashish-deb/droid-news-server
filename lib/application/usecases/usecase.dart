import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';

/// Base class for all Use Cases (Interactors) in the application.
///
/// Enforces the Command Pattern. Use cases should preserve the "Single Responsibility Principle".
///
/// [Result] is the return type of the success value.
/// [Params] is the parameter object passed to the use case.
abstract class UseCase<Result, Params> {
  /// Executes the use case.
  ///
  /// Returns `Future<Either<AppFailure, Result>>`.
  Future<Either<AppFailure, Result>> call(Params params);
}

/// Generic object for use cases that accept no parameters.
class NoParams {
  const NoParams();
}
