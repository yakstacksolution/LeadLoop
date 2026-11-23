import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_defaults.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/firestore_mapper.dart';
import '../../../auth/data/models/app_user_model.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/account_provisioner.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  EmployeeRepositoryImpl({
    required this.firestore,
    required this.provisioner,
    required this.currentUserId,
  });

  final FirebaseFirestore firestore;

  final AccountProvisioner provisioner;

  /// The signed-in admin's uid, for `createdBy` attribution.
  final String Function() currentUserId;

  CollectionReference<Map<String, dynamic>> get _users =>
      firestore.collection(FirestoreCollections.users);

  CollectionReference<Map<String, dynamic>> get _projects =>
      firestore.collection(FirestoreCollections.projects);

  @override
  Stream<List<AppUser>> watchEmployees({UserRole? role, UserStatus? status}) {
    Query<Map<String, dynamic>> query = _users;

    if (role != null) query = query.where('role', isEqualTo: role.value);
    if (status != null) query = query.where('status', isEqualTo: status.value);

    return query.snapshots().map((snap) {
      final users = snap.docs.map(AppUserModel.fromDoc).toList();
      // Sorted here rather than in the query: `fullName` ordering combined
      // with the optional role/status filters would need an index per
      // permutation, for a list measured in dozens.
      users.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      return users;
    });
  }

  @override
  Stream<AppUser?> watchEmployee(String uid) {
    return _users
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? AppUserModel.fromDoc(doc) : null);
  }

  @override
  Future<Result<AppUser>> getEmployee(String uid) {
    return guard(() async {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) throw const NotFoundFailure('That employee no longer exists.');
      return AppUserModel.fromDoc(doc);
    });
  }

  @override
  Future<Result<List<AppUser>>> getEmployeesByIds(List<String> ids) {
    return guard(() async {
      if (ids.isEmpty) return <AppUser>[];

      final chunks = <List<String>>[];
      for (var i = 0; i < ids.length; i += AppLimits.whereInMax) {
        chunks.add(ids.sublist(i, (i + AppLimits.whereInMax).clamp(0, ids.length)));
      }

      final results = await Future.wait(
        chunks.map((chunk) => _users.where(FieldPath.documentId, whereIn: chunk).get()),
      );

      return results.expand((snap) => snap.docs).map(AppUserModel.fromDoc).toList();
    });
  }

  @override
  Future<Result<CreatedEmployee>> createEmployee({
    required String fullName,
    required String email,
    required UserRole role,
    String phone = '',
    String employeeCode = '',
    List<String> assignedProjectIds = const [],
    String? password,
  }) {
    return guard(() async {
      final normalisedEmail = email.trim().toLowerCase();
      // Every account starts on the same known password so an admin can set
      // up staff in bulk and tell them one thing. A caller may still pass
      // their own, but nothing is ever generated: a random password the admin
      // has to read out loud helps no one here.
      final chosenPassword = (password != null && password.length >= 8)
          ? password
          : AppDefaults.initialEmployeePassword;

      // Creates the auth account on a secondary Firebase app, so the admin
      // doing this stays signed in on the default app.
      final uid = await provisioner.createAccount(
        email: normalisedEmail,
        password: chosenPassword,
      );

      try {
        final now = serverTime;

        // Written from the admin's own session, which is what satisfies the
        // `allow create: if isAdmin()` rule.
        await _users.doc(uid).set({
          'id': uid,
          'fullName': fullName.trim(),
          'email': normalisedEmail,
          'phone': phone.trim(),
          'employeeCode': employeeCode.trim(),
          'role': role.value,
          'status': UserStatus.active.value,
          'assignedProjectIds': assignedProjectIds,
          'createdAt': now,
          'updatedAt': now,
          'createdBy': currentUserId(),
        });

        // Keep the reverse index on each project in step.
        for (final projectId in assignedProjectIds) {
          await _projects.doc(projectId).update({
            'assignedEmployeeIds': FieldValue.arrayUnion([uid]),
            'updatedAt': serverTime,
          });
        }
      } catch (error) {
        // Never leave an auth account with no profile behind — it could sign
        // in while matching no security rule.
        await provisioner.deleteJustCreatedAccount(
          email: normalisedEmail,
          password: chosenPassword,
        );
        rethrow;
      }

      return CreatedEmployee(
        uid: uid,
        email: normalisedEmail,
        // Shown to the admin so they can hand it over. Never stored.
        temporaryPassword: chosenPassword,
      );
    });
  }

  /// Status, role and project assignment are written directly by an admin.
  ///
  /// The security rules already restrict these fields to admins, and the
  /// `syncUserClaims` trigger mirrors role and status into the auth account
  /// once Cloud Functions are deployed. Until then the rules' profile
  /// fallback keeps authorisation correct — see README, "Blaze plan".
  @override
  Future<Result<void>> setStatus(String uid, UserStatus status) {
    return guard(() => _users.doc(uid).update({
          'status': status.value,
          'updatedAt': serverTime,
        }));
  }

  @override
  Future<Result<void>> setRole(String uid, UserRole role) {
    return guard(() => _users.doc(uid).update({
          'role': role.value,
          'updatedAt': serverTime,
        }));
  }

  @override
  Future<Result<void>> setAssignedProjects(String uid, List<String> projectIds) {
    return guard(() async {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) throw const NotFoundFailure('That employee no longer exists.');

      final previous = AppUserModel.fromDoc(doc).assignedProjectIds;
      final next = projectIds.toSet().toList();

      final added = next.where((id) => !previous.contains(id)).toList();
      final removed = previous.where((id) => !next.contains(id)).toList();

      final batch = firestore.batch();

      batch.update(_users.doc(uid), {
        'assignedProjectIds': next,
        'updatedAt': serverTime,
      });

      // Both sides of the link move together, or neither does.
      for (final projectId in added) {
        batch.update(_projects.doc(projectId), {
          'assignedEmployeeIds': FieldValue.arrayUnion([uid]),
          'updatedAt': serverTime,
        });
      }
      for (final projectId in removed) {
        batch.update(_projects.doc(projectId), {
          'assignedEmployeeIds': FieldValue.arrayRemove([uid]),
          'updatedAt': serverTime,
        });
      }

      await batch.commit();
    });
  }

  @override
  Future<Result<void>> updateDetails(AppUser user) {
    return guard(() => _users.doc(user.id).update({
          'fullName': user.fullName.trim(),
          'phone': user.phone.trim(),
          'employeeCode': user.employeeCode.trim(),
          'updatedAt': serverTime,
        }));
  }

  /// Collections scoped by `assignedEmployeeId`, which all have to be handed
  /// to someone else before their owner disappears.
  static const _ownedCollections = [
    FirestoreCollections.venues,
    FirestoreCollections.venueContacts,
    FirestoreCollections.activities,
    FirestoreCollections.visits,
    FirestoreCollections.notes,
  ];

  @override
  Future<Result<bool>> deleteEmployee(String uid) {
    return guard(() async {
      final adminUid = currentUserId();
      if (adminUid.isEmpty) {
        throw const PermissionFailure('You must be signed in to do that.');
      }
      if (uid == adminUid) {
        throw const PermissionFailure('You cannot delete your own account.');
      }

      final snapshot = await _users.doc(uid).get();
      if (!snapshot.exists) {
        throw const NotFoundFailure('That employee no longer exists.');
      }
      final user = AppUserModel.fromDoc(snapshot);

      // Their work is reassigned, never deleted. `assignedEmployeeId` is what
      // every employee-scoped rule filters on, so a record left pointing at a
      // deleted uid could not be read by anyone but an admin again.
      for (final collection in _ownedCollections) {
        await _reassign(collection, from: uid, to: adminUid);
      }

      // Keep the reverse index on each project in step.
      for (final projectId in user.assignedProjectIds) {
        await _projects.doc(projectId).update({
          'assignedEmployeeIds': FieldValue.arrayRemove([uid]),
          'updatedAt': serverTime,
        });
      }

      await _users.doc(uid).delete();

      // Last, because it is the only step that can fail harmlessly: the login
      // can be removed from a client only by signing in as it, which works
      // while the account is still on the shared starting password. If they
      // changed it, the profile is gone regardless — the account can no
      // longer read anything or sign in — and the caller says so.
      return provisioner.deleteAccount(
        email: user.email,
        password: AppDefaults.initialEmployeePassword,
      );
    });
  }

  /// Moves every document in [collection] owned by [from] over to [to], a
  /// page at a time so a busy employee cannot exceed a batch's 500-write cap.
  Future<void> _reassign(
    String collection, {
    required String from,
    required String to,
  }) async {
    const pageSize = 400;

    while (true) {
      final page = await firestore
          .collection(collection)
          .where('assignedEmployeeId', isEqualTo: from)
          .limit(pageSize)
          .get();
      if (page.docs.isEmpty) return;

      final batch = firestore.batch();
      for (final doc in page.docs) {
        batch.update(doc.reference, {
          'assignedEmployeeId': to,
          'updatedAt': serverTime,
        });
      }
      await batch.commit();

      if (page.docs.length < pageSize) return;
    }
  }

  @override
  Future<Result<int>> countEmployees({UserStatus? status}) {
    return guard(() async {
      Query<Map<String, dynamic>> query = _users;
      if (status != null) query = query.where('status', isEqualTo: status.value);
      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    });
  }
}
