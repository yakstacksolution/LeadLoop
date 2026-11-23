import 'package:equatable/equatable.dart';

import 'failures.dart';

/// A minimal success-or-failure wrapper.
///
/// Chosen over a third-party Either so the domain layer stays dependency-free
/// while still forcing every caller to acknowledge the failure branch.
sealed class Result<T> extends Equatable {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  /// The value, or null when this is a failure.
  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        FailureResult<T>() => null,
      };

  /// The failure, or null when this is a success.
  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        FailureResult<T>(:final failure) => failure,
      };

  R fold<R>(R Function(Failure failure) onFailure, R Function(T value) onSuccess) =>
      switch (this) {
        Success<T>(:final value) => onSuccess(value),
        FailureResult<T>(:final failure) => onFailure(failure),
      };

  static Result<T> success<T>(T value) => Success<T>(value);
  static Result<T> failure<T>(Failure failure) => FailureResult<T>(failure);
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;

  @override
  List<Object?> get props => [value];
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
