import 'dart:async';
import 'dart:io';

// `cloud_functions` exports its own `Result`, which would collide with ours.
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_auth/firebase_auth.dart';

import 'failures.dart';
import 'result.dart';

/// Translates Firebase's error vocabulary into [Failure]s.
///
/// Every repository funnels its calls through [guard], which is the single
/// place where a platform exception becomes something the UI can show. Nothing
/// is swallowed: unclassified errors still surface as [UnexpectedFailure] with
/// the original code attached.
Failure mapError(Object error) {
  if (error is Failure) return error;

  if (error is FirebaseAuthException) {
    return AuthFailure(_authMessage(error), code: error.code);
  }

  if (error is FirebaseFunctionsException) {
    final message = error.message?.trim();
    return switch (error.code) {
      'unauthenticated' => const AuthFailure('Your session has expired. Please sign in again.'),
      'permission-denied' => PermissionFailure(
          message?.isNotEmpty == true ? message! : 'You do not have permission to do that.',
        ),
      // A callable that was never deployed comes back as a bare "NOT_FOUND"
      // with no detail. Our own functions always throw a descriptive message,
      // so a bare one means the function is missing rather than the record.
      'not-found' => (message == null || message.toUpperCase() == 'NOT_FOUND')
          ? const UnexpectedFailure(
              'This feature needs Cloud Functions, which are not deployed yet. '
              'Ask your administrator to run "firebase deploy --only functions" '
              '(it requires the Blaze plan).',
              'functions-not-deployed',
            )
          : NotFoundFailure(message),
      'invalid-argument' || 'failed-precondition' || 'already-exists' =>
        ValidationFailure(message ?? 'That request was not valid.'),
      'unavailable' || 'deadline-exceeded' => const NetworkFailure(),
      _ => UnexpectedFailure(message ?? 'Something went wrong.', error.code),
    };
  }

  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => const PermissionFailure(),
      'not-found' => const NotFoundFailure(),
      'unavailable' => const NetworkFailure(),
      'deadline-exceeded' => const NetworkFailure('The request timed out. Please try again.'),
      'resource-exhausted' =>
        const UnexpectedFailure('The service is busy right now. Please try again shortly.'),
      'failed-precondition' => UnexpectedFailure(
          // Almost always a missing composite index during development.
          error.message ?? 'This query needs a Firestore index that has not been created yet.',
          error.code,
        ),
      _ => UnexpectedFailure(error.message ?? 'Something went wrong.', error.code),
    };
  }

  if (error is SocketException || error is TimeoutException) {
    return const NetworkFailure();
  }

  return UnexpectedFailure(error.toString());
}

String _authMessage(FirebaseAuthException error) {
  // Firebase reports a project with no Authentication configuration as a bare
  // "internal error", which tells the user nothing. It means Email/Password
  // sign-in has not been enabled on the project, so say that instead.
  if ((error.message ?? '').contains('CONFIGURATION_NOT_FOUND') ||
      error.code == 'configuration-not-found') {
    return 'Email/Password sign-in is not enabled for this app yet. '
        'Ask your administrator to enable it in the Firebase console.';
  }

  return switch (error.code) {
      'invalid-email' => 'That email address is not valid.',
      'user-disabled' => 'This account has been disabled. Contact your administrator.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' =>
        'Incorrect email or password.',
      'too-many-requests' => 'Too many attempts. Please wait a moment and try again.',
      'network-request-failed' => 'No connection. Check your internet and try again.',
      'weak-password' => 'Choose a stronger password (at least 8 characters).',
      'email-already-in-use' => 'An account with that email already exists.',
      'requires-recent-login' => 'Please sign in again to complete this change.',
    _ => error.message ?? 'Authentication failed.',
  };
}

/// Runs [action] and converts any thrown error into a failed [Result].
Future<Result<T>> guard<T>(Future<T> Function() action) async {
  try {
    return Result.success(await action());
  } catch (error) {
    return Result.failure<T>(mapError(error));
  }
}
