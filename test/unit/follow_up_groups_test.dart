import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_lead/core/constants/enums.dart';
import 'package:futsal_lead/features/activities/domain/entities/activity.dart';
import 'package:futsal_lead/features/follow_ups/domain/entities/follow_up_groups.dart';

Activity _activity({
  required String id,
  required DateTime scheduledAt,
  ActivityStatus status = ActivityStatus.scheduled,
}) {
  return Activity(
    id: id,
    venueId: 'venue-1',
    projectId: 'project-1',
    assignedEmployeeId: 'emp-1',
    type: ActivityType.phoneCall,
    title: 'Call the owner',
    status: status,
    scheduledAt: scheduledAt,
  );
}

void main() {
  group('FollowUpGroups.from', () {
    test('buckets by overdue, today and upcoming', () {
      final now = DateTime.now();

      final groups = FollowUpGroups.from([
        _activity(id: 'late', scheduledAt: now.subtract(const Duration(hours: 3))),
        _activity(id: 'later-today', scheduledAt: now.add(const Duration(minutes: 30))),
        _activity(id: 'next-week', scheduledAt: now.add(const Duration(days: 7))),
      ]);

      expect(groups.overdue.map((a) => a.id), ['late']);
      expect(groups.today.map((a) => a.id), ['later-today']);
      expect(groups.upcoming.map((a) => a.id), ['next-week']);
      expect(groups.totalCount, 3);
    });

    test('closed activities are excluded however old they are', () {
      final now = DateTime.now();

      final groups = FollowUpGroups.from([
        _activity(
          id: 'done',
          scheduledAt: now.subtract(const Duration(days: 30)),
          status: ActivityStatus.completed,
        ),
        _activity(
          id: 'cancelled',
          scheduledAt: now.subtract(const Duration(days: 30)),
          status: ActivityStatus.cancelled,
        ),
      ]);

      expect(groups.isEmpty, isTrue);
    });

    test('a rescheduled activity still counts as open', () {
      final groups = FollowUpGroups.from([
        _activity(
          id: 'moved',
          scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
          status: ActivityStatus.rescheduled,
        ),
      ]);

      expect(groups.overdue, hasLength(1));
    });

    test('each bucket is sorted by scheduled time', () {
      final now = DateTime.now();

      final groups = FollowUpGroups.from([
        _activity(id: 'b', scheduledAt: now.subtract(const Duration(hours: 1))),
        _activity(id: 'a', scheduledAt: now.subtract(const Duration(hours: 5))),
      ]);

      expect(groups.overdue.map((a) => a.id), ['a', 'b']);
    });

    test('nextUp prefers the oldest overdue item', () {
      final now = DateTime.now();

      final groups = FollowUpGroups.from([
        _activity(id: 'soon', scheduledAt: now.add(const Duration(minutes: 5))),
        _activity(id: 'oldest', scheduledAt: now.subtract(const Duration(days: 2))),
        _activity(id: 'late', scheduledAt: now.subtract(const Duration(hours: 1))),
      ]);

      expect(groups.nextUp?.id, 'oldest');
    });

    test('nextUp falls through to today, then upcoming', () {
      final now = DateTime.now();

      final todayOnly = FollowUpGroups.from([
        _activity(id: 'today', scheduledAt: now.add(const Duration(minutes: 10))),
        _activity(id: 'later', scheduledAt: now.add(const Duration(days: 3))),
      ]);
      expect(todayOnly.nextUp?.id, 'today');

      final upcomingOnly = FollowUpGroups.from([
        _activity(id: 'later', scheduledAt: now.add(const Duration(days: 3))),
      ]);
      expect(upcomingOnly.nextUp?.id, 'later');

      expect(const FollowUpGroups().nextUp, isNull);
    });
  });
}
