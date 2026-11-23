import '../../../../core/constants/enums.dart';
import '../../../../core/errors/result.dart';
import '../entities/activity.dart';

/// The bucket a follow-up falls into on the "My Next Follow-Ups" screen.
enum FollowUpBucket { overdue, today, upcoming }

abstract interface class ActivityRepository {
  /// Activities for one venue. [assignedEmployeeId] is the venue's assignee —
  /// required so the query satisfies the employee `list` rule.
  Stream<List<Activity>> watchForVenue(
    String venueId, {
    required String assignedEmployeeId,
    int limit,
  });

  /// Open activities for one employee, ordered by when they are due.
  Stream<List<Activity>> watchOpenForEmployee(String employeeId, {int limit});

  /// Open activities across a project — the admin's view of a team's plan.
  Stream<List<Activity>> watchOpenForProject(String projectId, {int limit});

  /// Every open activity, oldest first. Admin-only in practice: the security
  /// rules reject the unscoped query for an employee.
  Stream<List<Activity>> watchOpenOrgWide({int limit});

  Future<Result<List<Activity>>> fetchForEmployee({
    required String employeeId,
    DateTime? from,
    DateTime? to,
    List<ActivityStatus> statuses = const [],
    int limit,
  });

  Stream<Activity?> watchActivity(String activityId);

  Future<Result<String>> createActivity(Activity activity, {required String createdBy});

  Future<Result<void>> updateActivity(Activity activity);

  /// Marks an activity done and records the outcome note on the venue
  /// timeline in the same batch.
  Future<Result<void>> complete({
    required Activity activity,
    required String outcomeNote,
    required String employeeName,
  });

  Future<Result<void>> cancel(Activity activity, {String reason = ''});

  /// Closes the old slot as `rescheduled` and opens a new one, so the history
  /// shows the move instead of silently editing the original time.
  Future<Result<String>> reschedule({
    required Activity activity,
    required DateTime newScheduledAt,
    required String createdBy,
  });

  Future<Result<int>> countOpen({
    String? employeeId,
    String? projectId,
    DateTime? dueBefore,
  });

  Future<Result<int>> countByStatus({
    required ActivityStatus status,
    String? employeeId,
    String? projectId,
  });
}
