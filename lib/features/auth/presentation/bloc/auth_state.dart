part of 'auth_cubit.dart';

/// Where the session currently stands.
enum AuthStatus {
  /// Still resolving the persisted session on app start.
  unknown,

  /// No signed-in user.
  unauthenticated,

  /// Signed in, with an active profile.
  authenticated,

  /// Signed in to Firebase Auth, but the project has no admin yet and this
  /// account has no profile — the one-time bootstrap path.
  needsBootstrap,

  /// Signed in, but the profile says the account was disabled.
  disabled,
}

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isSubmitting = false,
    this.failure,
  });

  final AuthStatus status;
  final AppUser? user;

  /// True while a sign-in, reset or bootstrap request is in flight.
  final bool isSubmitting;
  final Failure? failure;

  bool get isAdmin => user?.isAdmin ?? false;
  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  /// Convenience for repositories that need the caller's uid.
  String? get uid => user?.id;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool? isSubmitting,
    Failure? failure,
    bool clearFailure = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, user, isSubmitting, failure];
}
