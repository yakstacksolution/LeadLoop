import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/app_user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  /// Signals that sign-in worked but no profile document exists yet. The
  /// session is left open on purpose so the app can route to the bootstrap
  /// screen; the UI suppresses this rather than showing it as an error.
  static const profilePendingCode = 'profile-pending';

  AuthRepositoryImpl({
    required this.auth,
    required this.firestore,
  });

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      firestore.collection(FirestoreCollections.users);

  @override
  Stream<String?> authStateChanges() => auth.authStateChanges().map((user) => user?.uid);

  @override
  String? get currentUid => auth.currentUser?.uid;

  @override
  Stream<AppUser?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map(
          (doc) => doc.exists ? AppUserModel.fromDoc(doc) : null,
        );
  }

  @override
  Future<Result<AppUser>> signIn({required String email, required String password}) {
    return guard(() async {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        throw const AuthFailure('Sign-in did not return an account.');
      }

      final doc = await _users.doc(uid).get();
      if (!doc.exists) {
        // No profile. That means one of two very different things, and the
        // sentinel tells them apart.
        final claimed =
            await firestore.collection('system').doc('claimed').get();

        if (claimed.exists) {
          // The workspace is already set up, so this is an account whose
          // profile was deleted. The auth login itself cannot be removed
          // without the Admin SDK, so refusing here is what makes a deleted
          // employee inert.
          await auth.signOut();
          throw const AuthFailure(
            'This account has been removed. Contact your administrator.',
          );
        }

        // Nothing claimed yet: the very first admin. Deliberately stay signed
        // in — AuthCubit turns this into AuthStatus.needsBootstrap, which is
        // what makes the one-time "Set up your workspace" screen reachable.
        // Signing out here would make that screen impossible to reach and
        // would look, from the login form, like the password was wrong.
        throw const AuthFailure(
          'Finishing sign-in…',
          code: AuthRepositoryImpl.profilePendingCode,
        );
      }

      final user = AppUserModel.fromDoc(doc);
      if (!user.isActive) {
        await auth.signOut();
        throw const AuthFailure(
          'This account has been disabled. Contact your administrator.',
        );
      }

      return user;
    });
  }

  @override
  Future<Result<void>> signOut() => guard(() => auth.signOut());

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) {
    return guard(() => auth.sendPasswordResetEmail(email: email.trim().toLowerCase()));
  }

  @override
  Future<Result<void>> refreshToken() {
    return guard(() async {
      await auth.currentUser?.getIdToken(true);
    });
  }

  @override
  Future<Result<void>> registerFirstAdminAccount({
    required String email,
    required String password,
  }) {
    return guard(() async {
      await auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    });
  }

  @override
  Future<Result<AppUser>> bootstrapFirstAdmin({
    required String fullName,
    String phone = '',
  }) {
    return guard(() async {
      final uid = auth.currentUser?.uid;
      if (uid == null) throw const AuthFailure('You are no longer signed in.');

      final now = FieldValue.serverTimestamp();

      // Written as one batch with the /system/claimed sentinel. Firestore's
      // `create` fails if a document already exists, so the sentinel can be
      // written exactly once — which is what permanently closes the bootstrap
      // path for everyone else. The security rules require both halves.
      final batch = firestore.batch();

      batch.set(_users.doc(uid), {
        'id': uid,
        'fullName': fullName.trim(),
        'email': (auth.currentUser?.email ?? '').toLowerCase(),
        'phone': phone.trim(),
        'employeeCode': '',
        'role': 'admin',
        'status': 'active',
        'assignedProjectIds': <String>[],
        'createdAt': now,
        'updatedAt': now,
        'createdBy': uid,
      });

      batch.set(
        firestore.collection('system').doc('claimed'),
        {'claimedBy': uid, 'claimedAt': now},
      );

      try {
        await batch.commit();
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') {
          // The only way this happens is that the sentinel already exists.
          throw const PermissionFailure(
            'An administrator has already been set up for this workspace. '
            'Ask them to create your account.',
          );
        }
        rethrow;
      }

      final doc = await _users.doc(uid).get();
      if (!doc.exists) {
        throw const UnexpectedFailure('The admin profile was not created.');
      }
      return AppUserModel.fromDoc(doc);
    });
  }

  @override
  Future<Result<void>> updateOwnProfile(AppUser user) {
    return guard(() => _users.doc(user.id).update(user.toProfileUpdate()));
  }
}
