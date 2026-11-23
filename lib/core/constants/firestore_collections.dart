/// Canonical Firestore collection names.
///
/// Kept in one place so a rename never has to be hunted down across
/// repositories, security rules and index definitions.
abstract final class FirestoreCollections {
  static const users = 'users';
  static const projects = 'projects';
  static const venues = 'venues';
  static const venueContacts = 'venue_contacts';
  static const activities = 'activities';
  static const visits = 'visits';
  static const notes = 'notes';
  static const statusHistory = 'status_history';
  static const auditLogs = 'audit_logs';
  static const notifications = 'notifications';
  static const devices = 'devices';
}

/// Names of the callable Cloud Functions in `functions/index.js`.
abstract final class CloudFunctionNames {
  static const bootstrapFirstAdmin = 'bootstrapFirstAdmin';
  static const createEmployee = 'createEmployee';
  static const setEmployeeStatus = 'setEmployeeStatus';
  static const setEmployeeRole = 'setEmployeeRole';
  static const setEmployeeProjects = 'setEmployeeProjects';
  static const deleteEmployee = 'deleteEmployee';
  static const sendPasswordReset = 'sendPasswordReset';

  /// Must match `setGlobalOptions({ region })` in functions/index.js.
  static const region = 'asia-south1';
}

abstract final class AppLimits {
  /// Page size for every paginated Firestore list in the app.
  static const pageSize = 20;

  /// Firestore rejects `whereIn` filters with more than 30 values.
  static const whereInMax = 30;
}
