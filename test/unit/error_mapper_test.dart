import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_lead/core/errors/error_mapper.dart';
import 'package:futsal_lead/core/errors/failures.dart';

void main() {
  group('auth errors', () {
    test('an unconfigured project explains itself instead of "internal error"',
        () {
      final failure = mapError(
        FirebaseAuthException(
          code: 'internal-error',
          message: 'An internal error has occurred. [ CONFIGURATION_NOT_FOUND ]',
        ),
      );

      expect(failure, isA<AuthFailure>());
      expect(failure.message, contains('not enabled'));
      expect(failure.message, isNot(contains('CONFIGURATION_NOT_FOUND')));
    });

    test('wrong credentials do not leak which field was wrong', () {
      final failure = mapError(FirebaseAuthException(code: 'wrong-password'));
      expect(failure.message, 'Incorrect email or password.');

      final unknownUser = mapError(FirebaseAuthException(code: 'user-not-found'));
      expect(unknownUser.message, 'Incorrect email or password.');
    });

    test('a disabled account says so', () {
      final failure = mapError(FirebaseAuthException(code: 'user-disabled'));
      expect(failure.message, contains('disabled'));
    });

    test('a network failure is classified as one', () {
      final failure = mapError(
        FirebaseAuthException(code: 'network-request-failed'),
      );
      expect(failure.message, contains('connection'));
    });

    test('the original code is preserved for diagnostics', () {
      final failure = mapError(FirebaseAuthException(code: 'too-many-requests'));
      expect(failure.code, 'too-many-requests');
    });
  });

  group('cloud functions', () {
    test('a bare NOT_FOUND means the function was never deployed', () {
      final failure = mapError(
        FirebaseFunctionsException(code: 'not-found', message: 'NOT_FOUND'),
      );

      expect(failure.code, 'functions-not-deployed');
      expect(failure.message, contains('not deployed'));
      expect(failure.message, isNot(contains('NOT_FOUND')));
    });

    test('a described not-found is still treated as a missing record', () {
      final failure = mapError(
        FirebaseFunctionsException(
          code: 'not-found',
          message: 'That user does not exist.',
        ),
      );

      expect(failure, isA<NotFoundFailure>());
      expect(failure.message, 'That user does not exist.');
    });

    test('permission-denied keeps the server message', () {
      final failure = mapError(
        FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'Admin privileges are required.',
        ),
      );

      expect(failure, isA<PermissionFailure>());
      expect(failure.message, 'Admin privileges are required.');
    });

    test('failed-precondition is a validation problem, not a crash', () {
      final failure = mapError(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'An administrator already exists.',
        ),
      );

      expect(failure, isA<ValidationFailure>());
    });
  });

  group('passthrough', () {
    test('an existing Failure is returned untouched', () {
      const original = ValidationFailure('Bad input.');
      expect(mapError(original), same(original));
    });

    test('an unknown error becomes an UnexpectedFailure rather than throwing', () {
      expect(mapError(StateError('boom')), isA<UnexpectedFailure>());
    });
  });
}
