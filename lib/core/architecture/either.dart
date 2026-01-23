/// Functional programming Either monad for error handling.
///
/// Either represents a value of one of two possible types (a disjoint union).
/// Instances of Either are either an instance of [Left] or [Right].
///
/// A common use of Either is as an alternative to Option for dealing with
/// possible missing values. In this usage, [Left] is used for failure and
/// [Right] is used for success.
sealed class Either<L, R> {
  const Either();

  /// Returns true if this is a [Left] value.
  bool isLeft() => this is Left<L, R>;

  /// Returns true if this is a [Right] value.
  bool isRight() => this is Right<L, R>;

  /// Applies [leftFn] if this is a [Left] or [rightFn] if this is a [Right].
  T fold<T>(T Function(L left) leftFn, T Function(R right) rightFn) {
    if (this is Left<L, R>) {
      return leftFn((this as Left<L, R>).value);
    } else {
      return rightFn((this as Right<L, R>).value);
    }
  }

  /// Maps the [Right] value with [fn], leaving [Left] unchanged.
  Either<L, T> map<T>(T Function(R right) fn) {
    return fold((left) => Left<L, T>(left), (right) => Right<L, T>(fn(right)));
  }

  /// Maps the [Left] value with [fn], leaving [Right] unchanged.
  Either<T, R> mapLeft<T>(T Function(L left) fn) {
    return fold((left) => Left<T, R>(fn(left)), (right) => Right<T, R>(right));
  }

  /// Flat maps the [Right] value with [fn], leaving [Left] unchanged.
  Either<L, T> flatMap<T>(Either<L, T> Function(R right) fn) {
    return fold((left) => Left<L, T>(left), (right) => fn(right));
  }

  /// Returns the [Right] value or null if this is a [Left].
  R? getOrNull() {
    return fold((_) => null, (right) => right);
  }

  /// Returns the [Right] value or [defaultValue] if this is a [Left].
  R getOrElse(R defaultValue) {
    return fold((_) => defaultValue, (right) => right);
  }

  /// Returns the [Right] value or calls [defaultFn] if this is a [Left].
  R getOrElseGet(R Function() defaultFn) {
    return fold((_) => defaultFn(), (right) => right);
  }
}

/// Represents the left side of [Either], typically used for failure.
class Left<L, R> extends Either<L, R> {
  const Left(this.value);
  final L value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Left<L, R> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Left($value)';
}

/// Represents the right side of [Either], typically used for success.
class Right<L, R> extends Either<L, R> {
  const Right(this.value);
  final R value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Right<L, R> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Right($value)';
}

/// Extension methods for working with async Either values.
extension EitherAsyncExtensions<L, R> on Future<Either<L, R>> {
  /// Maps the [Right] value with [fn], leaving [Left] unchanged.
  Future<Either<L, T>> mapAsync<T>(T Function(R right) fn) async {
    final either = await this;
    return either.map(fn);
  }

  /// Flat maps the [Right] value with async [fn], leaving [Left] unchanged.
  Future<Either<L, T>> flatMapAsync<T>(
    Future<Either<L, T>> Function(R right) fn,
  ) async {
    final either = await this;
    return either.fold((left) => Left<L, T>(left), (right) => fn(right));
  }
}
