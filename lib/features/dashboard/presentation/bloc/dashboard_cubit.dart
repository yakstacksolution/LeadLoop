import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../activities/domain/repositories/activity_repository.dart';
import '../../../employees/domain/repositories/employee_repository.dart';
import '../../../projects/domain/repositories/project_repository.dart';
import '../../../venues/domain/repositories/venue_repository.dart';
import '../../../visits/domain/repositories/visit_repository.dart';
import '../../domain/entities/dashboard_stats.dart';

part 'dashboard_state.dart';

/// Loads the summary numbers for either dashboard.
///
/// Pass [employeeId] for an employee's own scope, or leave it null for the
/// admin's organisation-wide view. The query set is otherwise identical.
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({
    required VenueRepository venueRepository,
    required ActivityRepository activityRepository,
    required VisitRepository visitRepository,
    required ProjectRepository projectRepository,
    required EmployeeRepository employeeRepository,
    this.employeeId,
  })  : _venues = venueRepository,
        _activities = activityRepository,
        _visits = visitRepository,
        _projects = projectRepository,
        _employees = employeeRepository,
        super(const DashboardState());

  final VenueRepository _venues;
  final ActivityRepository _activities;
  final VisitRepository _visits;
  final ProjectRepository _projects;
  final EmployeeRepository _employees;

  /// Null means "the whole organisation" — the admin dashboard.
  final String? employeeId;

  bool get isAdminScope => employeeId == null;

  /// The only lead statuses the employee dashboard puts on screen.
  static const _employeeStatuses = [
    LeadStatus.newLead,
    LeadStatus.interested,
    LeadStatus.converted,
  ];

  Future<void> load() async {
    emit(state.copyWith(status: DashboardStatus.loading, clearFailure: true));

    final now = DateTime.now();
    final endOfToday = AppDateUtils.endOfToday();

    // Independent aggregation queries, fired together — running them in
    // sequence would make the dashboard feel slow on a field phone.
    final results = await Future.wait([
      _venues.countVenues(assignedEmployeeId: employeeId),
      _venues.countByStatus(
        assignedEmployeeId: employeeId,
        // The admin dashboard renders the full pipeline breakdown; an
        // employee's screen shows only three figures, so counting the other
        // eight would be eight wasted round trips on a mobile connection.
        statuses: isAdminScope ? const [] : _employeeStatuses,
      ),
      _activities.countOpen(employeeId: employeeId),
      _activities.countOpen(employeeId: employeeId, dueBefore: now),
      _activities.countOpen(employeeId: employeeId, dueBefore: endOfToday),
      _activities.countByStatus(
        status: ActivityStatus.scheduled,
        employeeId: employeeId,
      ),
      _visits.countVisits(employeeId: employeeId),
    ]);

    if (isClosed) return;

    final failed = results.where((r) => r.isFailure).toList();
    if (failed.isNotEmpty) {
      emit(state.copyWith(
        status: DashboardStatus.failure,
        failure: failed.first.failureOrNull,
      ));
      return;
    }

    final totalVenues = results[0].valueOrNull as int? ?? 0;
    final byStatus = results[1].valueOrNull as Map<LeadStatus, int>? ?? const {};
    final openActivities = results[2].valueOrNull as int? ?? 0;
    final overdue = results[3].valueOrNull as int? ?? 0;
    final dueToday = results[4].valueOrNull as int? ?? 0;
    final scheduled = results[5].valueOrNull as int? ?? 0;
    final visits = results[6].valueOrNull as int? ?? 0;

    // Project and headcount totals only mean something organisation-wide, so
    // an employee dashboard leaves them at zero rather than showing figures
    // their own security rules would not let them verify.
    var totalProjects = 0;
    var activeProjects = 0;
    var activeEmployees = 0;

    if (isAdminScope) {
      final headcount = await _employees.countEmployees(status: UserStatus.active);
      activeEmployees = headcount.valueOrNull ?? 0;

      final projects = await _projects.watchAllProjects().first;
      totalProjects = projects.length;
      activeProjects =
          projects.where((p) => p.status == ProjectStatus.active).length;
    }

    if (isClosed) return;

    emit(state.copyWith(
      status: DashboardStatus.success,
      hasLoaded: true,
      stats: DashboardStats(
        totalProjects: totalProjects,
        activeProjects: activeProjects,
        activeEmployees: activeEmployees,
        totalVenues: totalVenues,
        venuesByStatus: byStatus,
        meetingsScheduled: scheduled,
        visitsCompleted: visits,
        // Anything open that is not already late is still pending.
        pendingFollowUps: (openActivities - overdue).clamp(0, openActivities),
        overdueFollowUps: overdue,
        todaysActivities: dueToday,
      ),
    ));
  }

  Future<void> refresh() => load();
}
