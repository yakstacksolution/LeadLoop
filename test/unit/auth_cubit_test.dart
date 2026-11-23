import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_lead/core/constants/enums.dart';
import 'package:futsal_lead/core/errors/failures.dart';
import 'package:futsal_lead/core/errors/result.dart';
import 'package:futsal_lead/features/auth/domain/entities/app_user.dart';
import 'package:futsal_lead/features/auth/domain/repositories/auth_repository.dart';
import 'package:futsal_lead/features/auth/presentation/bloc/auth_cubit.dart';

/// An in-memory AuthRepository whose streams the tests drive by hand.
class FakeAuthRepository implements AuthRepository {
  final _authController = StreamController<String?>.broadcast();
  final _profileController = StreamController<AppUser?>.broadcast();

  Result<AppUser> signInResult = Result.success(_activeEmployee);
  bool signOutCalled = false;

  void emitAuth(String? uid) => _authController.add(uid);
  void emitProfile(AppUser? user) => _profileController.add(user);

  Future<void> dispose() async {
    await _authController.close();
    await _profileController.close();
  }

  @override
  Stream<String?> authStateChanges() => _authController.stream;

  @override
  String? get currentUid => null;

  @override
  Stream<AppUser?> watchProfile(String uid) => _profileController.stream;

  @override
  Future<Result<AppUser>> signIn({required String email, required String password}) async =>
      signInResult;

  @override
  Future<Result<void>> signOut() async {
    signOutCalled = true;
    return Result.success(null);
  }

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) async =>
      Result.success(null);

  @override
  Future<Result<void>> refreshToken() async => Result.success(null);

  @override
  Future<Result<AppUser>> bootstrapFirstAdmin({
    required String fullName,
    String phone = '',
  }) async =>
      Result.success(_admin);

  @override
  Future<Result<void>> registerFirstAdminAccount({
    required String email,
    required String password,
  }) async =>
      Result.success(null);

  @override
  Future<Result<void>> updateOwnProfile(AppUser user) async => Result.success(null);
}

const _activeEmployee = AppUser(
  id: 'uid-1',
  fullName: 'Dilli Bhandari',
  email: 'dilli@hamrofutsal.com',
  role: UserRole.employee,
  status: UserStatus.active,
  assignedProjectIds: ['p1'],
);

const _disabledEmployee = AppUser(
  id: 'uid-1',
  fullName: 'Dilli Bhandari',
  email: 'dilli@hamrofutsal.com',
  role: UserRole.employee,
  status: UserStatus.disabled,
);

const _admin = AppUser(
  id: 'uid-2',
  fullName: 'Admin User',
  email: 'admin@hamrofutsal.com',
  role: UserRole.admin,
  status: UserStatus.active,
);

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());
  tearDown(() => repository.dispose());

  test('starts in the unknown state while the session resolves', () {
    final cubit = AuthCubit(repository);
    expect(cubit.state.status, AuthStatus.unknown);
    cubit.close();
  });

  blocTest<AuthCubit, AuthState>(
    'signing out moves to unauthenticated',
    build: () => AuthCubit(repository),
    act: (_) => repository.emitAuth(null),
    wait: const Duration(milliseconds: 10),
    verify: (cubit) => expect(cubit.state.status, AuthStatus.unauthenticated),
  );

  blocTest<AuthCubit, AuthState>(
    'an active profile authenticates the session',
    build: () => AuthCubit(repository),
    act: (_) async {
      repository.emitAuth('uid-1');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      repository.emitProfile(_activeEmployee);
    },
    wait: const Duration(milliseconds: 20),
    verify: (cubit) {
      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.isAdmin, isFalse);
      expect(cubit.state.uid, 'uid-1');
    },
  );

  blocTest<AuthCubit, AuthState>(
    'an admin profile sets isAdmin',
    build: () => AuthCubit(repository),
    act: (_) async {
      repository.emitAuth('uid-2');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      repository.emitProfile(_admin);
    },
    wait: const Duration(milliseconds: 20),
    verify: (cubit) => expect(cubit.state.isAdmin, isTrue),
  );

  blocTest<AuthCubit, AuthState>(
    'a disabled profile is surfaced rather than treated as signed in',
    build: () => AuthCubit(repository),
    act: (_) async {
      repository.emitAuth('uid-1');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      repository.emitProfile(_disabledEmployee);
    },
    wait: const Duration(milliseconds: 20),
    verify: (cubit) {
      expect(cubit.state.status, AuthStatus.disabled);
      expect(cubit.state.isAuthenticated, isFalse);
    },
  );

  blocTest<AuthCubit, AuthState>(
    'signed in with no profile routes to the bootstrap flow',
    build: () => AuthCubit(repository),
    act: (_) async {
      repository.emitAuth('uid-3');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      repository.emitProfile(null);
    },
    wait: const Duration(milliseconds: 20),
    verify: (cubit) => expect(cubit.state.status, AuthStatus.needsBootstrap),
  );

  blocTest<AuthCubit, AuthState>(
    'a failed sign-in surfaces the failure and stops the spinner',
    build: () {
      repository.signInResult =
          Result.failure<AppUser>(const AuthFailure('Incorrect email or password.'));
      return AuthCubit(repository);
    },
    act: (cubit) => cubit.signIn(email: 'a@b.com', password: 'wrong'),
    verify: (cubit) {
      expect(cubit.state.isSubmitting, isFalse);
      expect(cubit.state.failure, isA<AuthFailure>());
      expect(cubit.state.failure!.message, 'Incorrect email or password.');
    },
  );

  blocTest<AuthCubit, AuthState>(
    'clearFailure removes a stale error',
    build: () {
      repository.signInResult = Result.failure<AppUser>(const AuthFailure('Nope'));
      return AuthCubit(repository);
    },
    act: (cubit) async {
      await cubit.signIn(email: 'a@b.com', password: 'wrong');
      cubit.clearFailure();
    },
    verify: (cubit) => expect(cubit.state.failure, isNull),
  );

  blocTest<AuthCubit, AuthState>(
    'a missing profile is not shown as a login error',
    build: () {
      repository.signInResult = Result.failure<AppUser>(
        const AuthFailure('Finishing sign-in…', code: 'profile-pending'),
      );
      return AuthCubit(repository);
    },
    act: (cubit) => cubit.signIn(email: 'a@b.com', password: 'correct'),
    verify: (cubit) {
      // The session stays open so the router can reach the bootstrap screen.
      expect(cubit.state.failure, isNull);
      expect(cubit.state.isSubmitting, isFalse);
    },
  );

  blocTest<AuthCubit, AuthState>(
    'signOut delegates to the repository',
    build: () => AuthCubit(repository),
    act: (cubit) => cubit.signOut(),
    verify: (_) => expect(repository.signOutCalled, isTrue),
  );
}
