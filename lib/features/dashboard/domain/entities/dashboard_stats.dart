import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// The numbers behind a dashboard.
///
/// Every field is produced by a server-side `count()` aggregation, never by
/// downloading documents — see `DashboardCubit` for the queries.
class DashboardStats extends Equatable {
  const DashboardStats({
    this.totalProjects = 0,
    this.activeProjects = 0,
    this.activeEmployees = 0,
    this.totalVenues = 0,
    this.venuesByStatus = const {},
    this.meetingsScheduled = 0,
    this.visitsCompleted = 0,
    this.pendingFollowUps = 0,
    this.overdueFollowUps = 0,
    this.todaysActivities = 0,
  });

  final int totalProjects;
  final int activeProjects;
  final int activeEmployees;
  final int totalVenues;
  final Map<LeadStatus, int> venuesByStatus;
  final int meetingsScheduled;
  final int visitsCompleted;

  /// Open activities with a future due date.
  final int pendingFollowUps;

  /// Open activities whose slot has already passed.
  final int overdueFollowUps;
  final int todaysActivities;

  int countOf(LeadStatus status) => venuesByStatus[status] ?? 0;

  int get newLeads => countOf(LeadStatus.newLead);
  int get contacted => countOf(LeadStatus.contacted);
  int get interested => countOf(LeadStatus.interested);
  int get converted => countOf(LeadStatus.converted);
  int get unresponsive => countOf(LeadStatus.unresponsive);
  int get notInterested => countOf(LeadStatus.notInterested);

  /// Venues that are neither won nor lost — the live pipeline.
  int get inPipeline => totalVenues - converted - notInterested;

  /// Share of non-new venues that converted, as a percentage.
  ///
  /// Returns null when there is nothing to divide by, so the UI shows "—"
  /// rather than a misleading 0%.
  double? get conversionRate {
    if (totalVenues == 0) return null;
    return (converted / totalVenues) * 100;
  }

  @override
  List<Object?> get props => [
        totalProjects,
        activeProjects,
        activeEmployees,
        totalVenues,
        venuesByStatus,
        meetingsScheduled,
        visitsCompleted,
        pendingFollowUps,
        overdueFollowUps,
        todaysActivities,
      ];
}
