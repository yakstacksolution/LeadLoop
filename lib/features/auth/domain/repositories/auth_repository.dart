import '../../../../core/errors/result.dart';
import '../entities/app_user.dart';

/// The domain's view of authentication. Deliberately mentions no Firebase
/// type, so the BLoCs and use cases can be tested against a fake.
abstract interface class AuthRepository {
  /// Emits the signed-in user's uid, or null when signed out.
  Stream<String?> authStateChanges();

  String? get currentUid;

  /// Live profile for [uid]. Emits null if the profile has not been created
  /// yet — which is the state a brand-new project's first admin starts in.
  Stream<AppUser?> watchProfile(String uid);

  Future<Result<AppUser>> signIn({required String email, required String password});

  Future<Result<void>> signOut();

  Future<Result<void>> sendPasswordResetEmail(String email);

  /// Re-reads the ID token so a freshly changed role claim takes effect
  /// without making the user sign in again.
  Future<Result<void>> refreshToken();

  /// Promotes the signed-in account to admin, but only while the project has
  /// no admin at all. Backed by the `bootstrapFirstAdmin` Cloud Function.
  Future<Result<AppUser>> bootstrapFirstAdmin({required String fullName, String phone});

  /// Creates the auth account for the very first admin, before any employee
  /// records exist. Fails once an admin is present.
  Future<Result<void>> registerFirstAdminAccount({
    required String email,
    required String password,
  });

  Future<Result<void>> updateOwnProfile(AppUser user);
}
