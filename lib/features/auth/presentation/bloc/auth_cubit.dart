import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_state.dart';

/// Owns the session for the whole app.
///
/// It listens to auth changes and, while signed in, to the user's own profile
/// document — so an admin disabling an account or changing its role takes
/// effect in the running app without a restart.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthState()) {
    _authSubscription = _repository.authStateChanges().listen(_onAuthChanged);
  }

  final AuthRepository _repository;
  StreamSubscription<String?>? _authSubscription;
  StreamSubscription<AppUser?>? _profileSubscription;

  void _onAuthChanged(String? uid) {
    _profileSubscription?.cancel();
    _profileSubscription = null;

    if (uid == null) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }

    _profileSubscription = _repository.watchProfile(uid).listen(
      _onProfileChanged,
      onError: (Object error) {
        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          failure: mapError(error),
          isSubmitting: false,
          clearUser: true,
        ));
      },
    );
  }

  void _onProfileChanged(AppUser? user) {
    if (user == null) {
      // Authenticated with no profile: either the first admin before
      // bootstrapping, or an account an admin has not finished setting up.
      emit(state.copyWith(
        status: AuthStatus.needsBootstrap,
        isSubmitting: false,
        clearUser: true,
      ));
      return;
    }

    emit(state.copyWith(
      status: user.isActive ? AuthStatus.authenticated : AuthStatus.disabled,
      user: user,
      isSubmitting: false,
      clearFailure: true,
    ));
  }

  Future<void> signIn({required String email, required String password}) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final result = await _repository.signIn(email: email, password: password);

    result.fold(
      (failure) => emit(
        state.copyWith(
          isSubmitting: false,
          // A missing profile is not a login error — the auth stream is about
          // to route to the bootstrap screen, so showing "sign-in failed"
          // here would be plainly wrong.
          failure: failure.code == AuthRepositoryImpl.profilePendingCode
              ? null
              : failure,
          clearFailure: failure.code == AuthRepositoryImpl.profilePendingCode,
        ),
      ),
      // On success the auth stream drives the transition, so there is nothing
      // to emit here beyond clearing the spinner if the stream is slow.
      (_) => emit(state.copyWith(isSubmitting: false, clearFailure: true)),
    );
  }

  Future<bool> sendPasswordReset(String email) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));
    final result = await _repository.sendPasswordResetEmail(email);

    return result.fold(
      (failure) {
        emit(state.copyWith(isSubmitting: false, failure: failure));
        return false;
      },
      (_) {
        emit(state.copyWith(isSubmitting: false));
        return true;
      },
    );
  }

  /// One-time setup of the very first administrator.
  Future<bool> bootstrapFirstAdmin({required String fullName, String phone = ''}) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));
    final result = await _repository.bootstrapFirstAdmin(fullName: fullName, phone: phone);

    return result.fold(
      (failure) {
        emit(state.copyWith(isSubmitting: false, failure: failure));
        return false;
      },
      (user) {
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isSubmitting: false,
          clearFailure: true,
        ));
        return true;
      },
    );
  }

  Future<bool> registerFirstAdminAccount({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));
    final result = await _repository.registerFirstAdminAccount(
      email: email,
      password: password,
    );

    return result.fold(
      (failure) {
        emit(state.copyWith(isSubmitting: false, failure: failure));
        return false;
      },
      (_) => true,
    );
  }

  Future<bool> updateOwnProfile(AppUser user) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));
    final result = await _repository.updateOwnProfile(user);

    return result.fold(
      (failure) {
        emit(state.copyWith(isSubmitting: false, failure: failure));
        return false;
      },
      // The profile stream delivers the new values.
      (_) {
        emit(state.copyWith(isSubmitting: false));
        return true;
      },
    );
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  void clearFailure() => emit(state.copyWith(clearFailure: true));

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    return super.close();
  }
}
