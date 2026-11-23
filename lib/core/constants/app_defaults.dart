/// Values the app seeds new records with.
abstract final class AppDefaults {
  /// The password every new employee account is created with.
  ///
  /// Deliberately fixed and shared so an admin can set up accounts in bulk and
  /// tell the team one thing. It is public knowledge by design, so the account
  /// is only as safe as the first sign-in: the app asks the employee to change
  /// it immediately, and [initialPasswordNotice] is the wording shown to the
  /// admin handing it over.
  static const initialEmployeePassword = 'Futsal@123';

  static const initialPasswordNotice =
      'Everyone starts with the same password, so ask them to change it as '
      'soon as they sign in.';
}
