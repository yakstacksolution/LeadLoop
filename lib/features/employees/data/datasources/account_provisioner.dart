import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../../firebase_options.dart';

/// Creates Firebase Auth accounts from the client without disturbing the
/// signed-in admin.
///
/// The Admin SDK is the textbook way to do this, but it needs a server, and a
/// server means the Blaze plan. The supported client-side equivalent is a
/// SECONDARY [FirebaseApp]: `FirebaseAuth` keeps one session per app instance,
/// so signing a brand-new user in on a second instance leaves the default
/// instance — the admin — completely untouched.
///
/// Limits worth knowing, and stated honestly in the UI:
/// * Custom auth claims cannot be set from a client. The security rules read
///   the role from the user's profile document as well as the claim, so
///   authorisation is still correct.
/// * An account cannot be disabled at the Firebase Auth level from a client.
///   Disabling sets `status: 'disabled'` on the profile, which the rules
///   enforce for every read and write, and the app refuses the sign-in.
class AccountProvisioner {
  AccountProvisioner({this.appName = 'employeeProvisioner'});

  /// Name of the secondary app. Anything other than '[DEFAULT]'.
  final String appName;

  static const _passwordAlphabet =
      'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#%^&*';

  /// A cryptographically random password, avoiding characters that are easy to
  /// misread when an admin reads one aloud or copies it by hand.
  ///
  /// No longer used when creating an employee — accounts start on
  /// `AppDefaults.initialEmployeePassword` — but kept for any flow that needs
  /// a one-off password.
  static String generatePassword({int length = 14}) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => _passwordAlphabet[random.nextInt(_passwordAlphabet.length)],
    ).join();
  }

  Future<FirebaseApp> _secondaryApp() async {
    try {
      return Firebase.app(appName);
    } on FirebaseException {
      // Not initialised yet on this launch.
      return Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  /// Creates the account and returns its uid. The secondary session is always
  /// signed out afterwards, including when the caller later fails.
  Future<String> createAccount({
    required String email,
    required String password,
  }) async {
    final app = await _secondaryApp();
    final secondaryAuth = FirebaseAuth.instanceFor(app: app);

    final credential = await secondaryAuth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid == null) {
      await secondaryAuth.signOut();
      throw FirebaseAuthException(
        code: 'unknown',
        message: 'The account was not created.',
      );
    }

    await secondaryAuth.signOut();
    return uid;
  }

  /// Deletes an auth account from the client, by signing in as that user on
  /// the secondary app and calling `delete()` on them.
  ///
  /// This is the only way to remove a login without the Admin SDK, and it
  /// works exactly as far as [password] is still correct — an employee who
  /// changed theirs can only be removed from the Firebase console. Returns
  /// whether the login is gone.
  ///
  /// The secondary app is a separate session, so the admin doing this stays
  /// signed in on the default app throughout.
  Future<bool> deleteAccount({
    required String email,
    required String password,
  }) async {
    final app = await _secondaryApp();
    final secondaryAuth = FirebaseAuth.instanceFor(app: app);

    try {
      final credential = await secondaryAuth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      await credential.user?.delete();
      return true;
    } catch (_) {
      // Wrong password, or the account is already gone. Either way there is
      // nothing more a client can do, and the caller reports it.
      return false;
    } finally {
      await secondaryAuth.signOut();
    }
  }

  /// Removes an account created moments ago, used to roll back when the
  /// profile write fails.
  Future<void> deleteJustCreatedAccount({
    required String email,
    required String password,
  }) =>
      deleteAccount(email: email, password: password);

  /// Sends the password-reset email so the employee can choose their own.
  Future<void> sendPasswordReset(String email) async {
    final app = await _secondaryApp();
    await FirebaseAuth.instanceFor(app: app)
        .sendPasswordResetEmail(email: email.trim().toLowerCase());
  }
}
