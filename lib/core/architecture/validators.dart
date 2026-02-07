import 'either.dart';
import 'failure.dart';

/// Common validation utilities used across the application.
///
/// All validators return [Either<ValidationFailure, T>] for consistent
/// error handling.
class Validators {
  Validators._(); 


  /// Validates that a string is not empty.
  static Either<ValidationFailure, String> notEmpty(
    String value, {
    String fieldName = 'Field',
  }) {
    if (value.trim().isEmpty) {
      return Left(
        ValidationFailure('$fieldName cannot be empty', {
          fieldName: '$fieldName cannot be empty',
        }),
      );
    }
    return Right(value);
  }

  /// Validates email format.
  static Either<ValidationFailure, String> email(String value) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return const Left(
        ValidationFailure('Invalid email format', {
          'email': 'Please enter a valid email address',
        }),
      );
    }
    return Right(value);
  }

  /// Validates minimum string length.
  static Either<ValidationFailure, String> minLength(
    String value,
    int minLength, {
    String fieldName = 'Field',
  }) {
    if (value.length < minLength) {
      return Left(
        ValidationFailure('$fieldName must be at least $minLength characters', {
          fieldName: '$fieldName must be at least $minLength characters',
        }),
      );
    }
    return Right(value);
  }

  /// Validates maximum string length.
  static Either<ValidationFailure, String> maxLength(
    String value,
    int maxLength, {
    String fieldName = 'Field',
  }) {
    if (value.length > maxLength) {
      return Left(
        ValidationFailure('$fieldName must not exceed $maxLength characters', {
          fieldName: '$fieldName must not exceed $maxLength characters',
        }),
      );
    }
    return Right(value);
  }

  /// Validates password strength.
  ///
  /// Requirements:
  /// - At least 8 characters
  /// - Contains uppercase letter
  /// - Contains lowercase letter
  /// - Contains number
  /// - Contains special character
  static Either<ValidationFailure, String> password(String value) {
    if (value.length < 8) {
      return const Left(
        ValidationFailure('Password must be at least 8 characters', {
          'password': 'Password must be at least 8 characters',
        }),
      );
    }

    if (!value.contains(RegExp(r'[A-Z]'))) {
      return const Left(
        ValidationFailure('Password must contain an uppercase letter', {
          'password': 'Password must contain an uppercase letter',
        }),
      );
    }

    if (!value.contains(RegExp(r'[a-z]'))) {
      return const Left(
        ValidationFailure('Password must contain a lowercase letter', {
          'password': 'Password must contain a lowercase letter',
        }),
      );
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return const Left(
        ValidationFailure('Password must contain a number', {
          'password': 'Password must contain a number',
        }),
      );
    }

    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return const Left(
        ValidationFailure('Password must contain a special character', {
          'password': 'Password must contain a special character',
        }),
      );
    }

    return Right(value);
  }


  /// Validates that a number is positive.
  static Either<ValidationFailure, num> positive(
    num value, {
    String fieldName = 'Value',
  }) {
    if (value <= 0) {
      return Left(
        ValidationFailure('$fieldName must be positive', {
          fieldName: '$fieldName must be greater than 0',
        }),
      );
    }
    return Right(value);
  }

  /// Validates that a number is within a range.
  static Either<ValidationFailure, num> range(
    num value,
    num min,
    num max, {
    String fieldName = 'Value',
  }) {
    if (value < min || value > max) {
      return Left(
        ValidationFailure('$fieldName must be between $min and $max', {
          fieldName: '$fieldName must be between $min and $max',
        }),
      );
    }
    return Right(value);
  }


  /// Validates that a list is not empty.
  static Either<ValidationFailure, List<T>> notEmptyList<T>(
    List<T> value, {
    String fieldName = 'List',
  }) {
    if (value.isEmpty) {
      return Left(
        ValidationFailure('$fieldName cannot be empty', {
          fieldName: '$fieldName must contain at least one item',
        }),
      );
    }
    return Right(value);
  }

  /// Validates list length.
  static Either<ValidationFailure, List<T>> listLength<T>(
    List<T> value,
    int minLength,
    int maxLength, {
    String fieldName = 'List',
  }) {
    if (value.length < minLength) {
      return Left(
        ValidationFailure('$fieldName must contain at least $minLength items', {
          fieldName: '$fieldName must contain at least $minLength items',
        }),
      );
    }

    if (value.length > maxLength) {
      return Left(
        ValidationFailure('$fieldName must not exceed $maxLength items', {
          fieldName: '$fieldName must not exceed $maxLength items',
        }),
      );
    }

    return Right(value);
  }


  /// Combines multiple validators and returns the first failure or success.
  ///
  /// Example:
  /// ```dart
  /// final result = Validators.combine<String>([
  ///   () => Validators.notEmpty(email, fieldName: 'Email'),
  ///   () => Validators.email(email),
  /// ]);
  /// ```
  static Either<ValidationFailure, T> combine<T>(
    List<Either<ValidationFailure, T> Function()> validators,
  ) {
    for (final validator in validators) {
      final result = validator();
      if (result.isLeft()) {
        return result;
      }
    }

    return validators.last();
  }

  /// Validates all fields and collects all errors.
  ///
  /// Returns all validation errors instead of just the first one.
  /// Useful for form validation where you want to show all errors at once.
  ///
  /// Example:
  /// ```dart
  /// final errors = Validators.validateAll({
  ///   'email': () => Validators.email(email),
  ///   'password': () => Validators.password(password),
  ///   'name': () => Validators.notEmpty(name, fieldName: 'Name'),
  /// });
  ///
  /// if (errors.isNotEmpty) {
  ///
  /// }
  /// ```
  static Map<String, String> validateAll(
    Map<String, Either<ValidationFailure, dynamic> Function()> validators,
  ) {
    final errors = <String, String>{};

    for (final entry in validators.entries) {
      final result = entry.value();
      if (result.isLeft()) {
        final failure = (result as Left<ValidationFailure, dynamic>).value;
        if (failure.fieldErrors != null) {
          errors.addAll(failure.fieldErrors!);
        } else {
          errors[entry.key] = failure.message;
        }
      }
    }

    return errors;
  }


  /// Creates a custom validator from a predicate function.
  ///
  /// Example:
  /// ```dart
  /// final isAdult = Validators.custom<int>(
  ///   age,
  ///   (value) => value >= 18,
  ///   'You must be at least 18 years old',
  /// );
  /// ```
  static Either<ValidationFailure, T> custom<T>(
    T value,
    bool Function(T) predicate,
    String errorMessage, {
    String? fieldName,
  }) {
    if (!predicate(value)) {
      return Left(
        ValidationFailure(
          errorMessage,
          fieldName != null ? {fieldName: errorMessage} : null,
        ),
      );
    }
    return Right(value);
  }
}
