import '../utils/logger.dart';

/// A discriminated union that holds either a success value [T] or a typed
/// [AppFailure].  All repository / use-case methods return [Result<T>] so
/// that the presentation layer never has to catch raw exceptions.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
        Success(:final value) => value,
        Failure() => null,
      };

  AppFailure? get failureOrNull => switch (this) {
        Success() => null,
        Failure(:final failure) => failure,
      };

  /// Applies [onSuccess] or [onFailure] and returns the result.
  R when<R>({
    required R Function(T value) onSuccess,
    required R Function(AppFailure failure) onFailure,
  }) =>
      switch (this) {
        Success(:final value) => onSuccess(value),
        Failure(:final failure) => onFailure(failure),
      };

  /// Maps the success value, leaving failures untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success(:final value) => Success(transform(value)),
        Failure(:final failure) => Failure(failure),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);
  final AppFailure failure;
}

// ── Failure hierarchy ─────────────────────────────────────────────────────────

sealed class AppFailure {
  const AppFailure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class DatabaseFailure extends AppFailure {
  const DatabaseFailure(super.message, {this.cause});
  final Object? cause;
}

final class CameraFailure extends AppFailure {
  const CameraFailure(super.message, {this.cause});
  final Object? cause;
}

final class ProcessingFailure extends AppFailure {
  const ProcessingFailure(super.message, {this.cause});
  final Object? cause;
}

final class AnalysisFailure extends AppFailure {
  const AnalysisFailure(super.message, {this.cause});
  final Object? cause;
}

final class AudioFailure extends AppFailure {
  const AudioFailure(super.message, {this.cause});
  final Object? cause;
}

final class StorageFailure extends AppFailure {
  const StorageFailure(super.message, {this.cause});
  final Object? cause;
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message, {this.cause});
  final Object? cause;
}

// ── Guard helper ──────────────────────────────────────────────────────────────

/// Wraps any async operation in a [Result], catching all exceptions.
///
/// ```dart
/// final result = await guard(
///   () => someAsyncOperation(),
///   onError: (e, st) => DatabaseFailure('Could not save', cause: e),
/// );
/// ```
Future<Result<T>> guard<T>(
  Future<T> Function() action, {
  required AppFailure Function(Object error, StackTrace stackTrace) onError,
}) async {
  try {
    final value = await action();
    return Success(value);
  } catch (e, st) {
    AppLogger.e('guard caught exception', error: e, stackTrace: st);
    return Failure(onError(e, st));
  }
}

/// Synchronous variant of [guard].
Result<T> guardSync<T>(
  T Function() action, {
  required AppFailure Function(Object error, StackTrace stackTrace) onError,
}) {
  try {
    return Success(action());
  } catch (e, st) {
    AppLogger.e('guardSync caught exception', error: e, stackTrace: st);
    return Failure(onError(e, st));
  }
}
