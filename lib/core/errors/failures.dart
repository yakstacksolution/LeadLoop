import 'package:equatable/equatable.dart';

/// A user-presentable description of something that went wrong.
///
/// Repositories never throw across the domain boundary; they return
/// [Result.failure] carrying one of these, so every BLoC has a message it can
/// put on screen without knowing that Firebase exists.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => '$runtimeType($code): $message';
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

class PermissionFailure extends Failure {
  const PermissionFailure([
    super.message = 'You do not have permission to do that.',
  ]);
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No connection. Check your internet and try again.',
  ]);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'That record no longer exists.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Anything we could not classify. The underlying message is kept for the
/// error widget's "details" affordance rather than being swallowed.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure([
    super.message = 'Something went wrong. Please try again.',
    String? code,
  ]) : super(code: code);
}
