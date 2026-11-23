import 'package:equatable/equatable.dart';

import '../../../activities/domain/entities/activity.dart';

/// Open activities split into the three buckets the follow-up screen shows.
///
/// The split is computed once, in the domain, so the dashboard, the follow-up
/// list and the admin overview all agree on what "overdue" means.
class FollowUpGroups extends Equatable {
  const FollowUpGroups({
    this.overdue = const [],
    this.today = const [],
    this.upcoming = const [],
  });

  final List<Activity> overdue;
  final List<Activity> today;
  final List<Activity> upcoming;

  /// Sorts [activities] into buckets against [now] (injectable for tests).
  factory FollowUpGroups.from(List<Activity> activities, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final overdue = <Activity>[];
    final today = <Activity>[];
    final upcoming = <Activity>[];

    for (final activity in activities) {
      if (!activity.status.isOpen) continue;

      if (activity.isOverdue) {
        overdue.add(activity);
      } else if (activity.scheduledAt.isBefore(_endOfDay(reference))) {
        // Later today: not late yet, but it is today's work.
        today.add(activity);
      } else {
        upcoming.add(activity);
      }
    }

    int bySchedule(Activity a, Activity b) => a.scheduledAt.compareTo(b.scheduledAt);
    overdue.sort(bySchedule);
    today.sort(bySchedule);
    upcoming.sort(bySchedule);

    return FollowUpGroups(overdue: overdue, today: today, upcoming: upcoming);
  }

  static DateTime _endOfDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day).add(const Duration(days: 1));
  }

  int get totalCount => overdue.length + today.length + upcoming.length;
  bool get isEmpty => totalCount == 0;

  /// The single next thing to do: the oldest overdue item, else the next one
  /// due today, else the next upcoming. Never guessed from anything else.
  Activity? get nextUp {
    if (overdue.isNotEmpty) return overdue.first;
    if (today.isNotEmpty) return today.first;
    if (upcoming.isNotEmpty) return upcoming.first;
    return null;
  }

  @override
  List<Object?> get props => [overdue, today, upcoming];
}
