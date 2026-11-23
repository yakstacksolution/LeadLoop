import '../../../../core/constants/enums.dart';
import '../../../../core/errors/result.dart';
import '../../../auth/domain/entities/app_user.dart';

/// What the server returned after provisioning an account.
class CreatedEmployee {
  const CreatedEmployee({
    required this.uid,
    required this.email,
    this.temporaryPassword,
    this.passwordResetLink,
  });

  final String uid;
  final String email;

  /// Shown to the admin exactly once, so they can hand the credentials over.
  /// Never persisted.
  final String? temporaryPassword;
  final String? passwordResetLink;
}

abstract interface class EmployeeRepository {
  Stream<List<AppUser>> watchEmployees({UserRole? role, UserStatus? status});

  Stream<AppUser?> watchEmployee(String uid);

  Future<Result<AppUser>> getEmployee(String uid);

  Future<Result<List<AppUser>>> getEmployeesByIds(List<String> ids);

  /// Provisions an account through the `createEmployee` Cloud Function.
  ///
  /// This is the one operation that genuinely cannot run on the client: it
  /// needs the Admin SDK to create the account without signing the calling
  /// admin out of their own session.
  Future<Result<CreatedEmployee>> createEmployee({
    required String fullName,
    required String email,
    required UserRole role,
    String phone,
    String employeeCode,
    List<String> assignedProjectIds,
    String? password,
  });

  Future<Result<void>> setStatus(String uid, UserStatus status);

  Future<Result<void>> setRole(String uid, UserRole role);

  /// Replaces the user's project list and mirrors it onto each project's
  /// `assignedEmployeeIds`.
  Future<Result<void>> setAssignedProjects(String uid, List<String> projectIds);

  Future<Result<void>> updateDetails(AppUser user);

  /// Removes an employee: their profile, their place on every project and —
  /// when possible — their Firebase Auth login.
  ///
  /// Their venues, contacts, activities, visits and notes are reassigned to
  /// the admin performing the deletion rather than deleted: those records are
  /// scoped by `assignedEmployeeId`, so pointing them at a uid that no longer
  /// exists would put them out of reach.
  ///
  /// Returns whether the login itself was deleted. A client can only do that
  /// by signing in as the account, which works while it is still on the
  /// shared starting password; once an employee has changed theirs, the login
  /// has to be removed from the Firebase console. Either way the account is
  /// inert — sign-in is refused for a user with no profile.
  Future<Result<bool>> deleteEmployee(String uid);

  Future<Result<int>> countEmployees({UserStatus? status});
}
