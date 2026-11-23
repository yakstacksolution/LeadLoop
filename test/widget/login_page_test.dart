import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_lead/core/constants/enums.dart';
import 'package:futsal_lead/core/errors/failures.dart';
import 'package:futsal_lead/core/errors/result.dart';
import 'package:futsal_lead/core/theme/app_theme.dart';
import 'package:futsal_lead/features/auth/domain/entities/app_user.dart';
import 'package:futsal_lead/features/auth/domain/repositories/auth_repository.dart';
import 'package:futsal_lead/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:futsal_lead/features/auth/presentation/pages/login_page.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.signInResult});

  final Result<AppUser>? signInResult;

  String? lastEmail;
  String? lastPassword;

  final _authController = StreamController<String?>.broadcast();

  @override
  Stream<String?> authStateChanges() => _authController.stream;

  @override
  String? get currentUid => null;

  @override
  Stream<AppUser?> watchProfile(String uid) => const Stream.empty();

  @override
  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;
    return signInResult ??
        Result.success(
          const AppUser(
            id: 'uid-1',
            fullName: 'Dilli',
            email: 'dilli@hamrofutsal.com',
            role: UserRole.employee,
            status: UserStatus.active,
          ),
        );
  }

  @override
  Future<Result<void>> signOut() async => Result.success(null);

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
      throw UnimplementedError();

  @override
  Future<Result<void>> registerFirstAdminAccount({
    required String email,
    required String password,
  }) async =>
      Result.success(null);

  @override
  Future<Result<void>> updateOwnProfile(AppUser user) async => Result.success(null);
}

Widget _wrap(AuthCubit cubit) {
  return BlocProvider.value(
    value: cubit,
    child: MaterialApp(theme: AppTheme.light, home: const LoginPage()),
  );
}

void main() {
  testWidgets('shows the sign-in form', (tester) async {
    final cubit = AuthCubit(_FakeAuthRepository());
    addTearDown(cubit.close);

    await tester.pumpWidget(_wrap(cubit));

    expect(find.text('Sign in'), findsAtLeast(1));
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
  });

  testWidgets('blocks submission and shows validation errors when empty',
      (tester) async {
    final repository = _FakeAuthRepository();
    final cubit = AuthCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(_wrap(cubit));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    // Nothing should have reached the repository.
    expect(repository.lastEmail, isNull);
  });

  testWidgets('rejects a malformed email', (tester) async {
    final cubit = AuthCubit(_FakeAuthRepository());
    addTearDown(cubit.close);

    await tester.pumpWidget(_wrap(cubit));
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'not-an-email');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('passes valid credentials to the repository', (tester) async {
    final repository = _FakeAuthRepository();
    final cubit = AuthCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(_wrap(cubit));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'dilli@hamrofutsal.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(repository.lastEmail, 'dilli@hamrofutsal.com');
    expect(repository.lastPassword, 'password123');
  });

  testWidgets('shows the failure message returned by the repository',
      (tester) async {
    final cubit = AuthCubit(
      _FakeAuthRepository(
        signInResult: Result.failure<AppUser>(
          const AuthFailure('Incorrect email or password.'),
        ),
      ),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(_wrap(cubit));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'dilli@hamrofutsal.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'wrongpassword',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password.'), findsOneWidget);
  });

  testWidgets('toggles password visibility', (tester) async {
    final cubit = AuthCubit(_FakeAuthRepository());
    addTearDown(cubit.close);

    await tester.pumpWidget(_wrap(cubit));

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });
}
