import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_lead/core/constants/enums.dart';
import 'package:futsal_lead/features/activities/domain/entities/activity.dart';
import 'package:futsal_lead/features/venues/domain/entities/timeline_entry.dart';
import 'package:futsal_lead/features/venues/domain/entities/venue_note.dart';

void main() {
  VenueNote note(String id, DateTime at, {String text = 'x'}) => VenueNote(
        id: id,
        venueId: 'v',
        projectId: 'p',
        assignedEmployeeId: 'e',
        employeeId: 'e',
        employeeName: 'Employee',
        text: text,
        createdAt: at,
      );

  Activity activity(String id, DateTime scheduledAt) => Activity(
        id: id,
        venueId: 'v',
        venueName: 'Venue',
        projectId: 'p',
        assignedEmployeeId: 'e',
        type: ActivityType.phoneCall,
        title: 'Call',
        scheduledAt: scheduledAt,
        status: ActivityStatus.scheduled,
      );

  group('TimelineEntry.merge', () {
    test('orders newest first', () {
      final entries = TimelineEntry.merge(
        notes: [
          note('old', DateTime(2026, 1, 1)),
          note('newest', DateTime(2026, 3, 1)),
          note('middle', DateTime(2026, 2, 1)),
        ],
      );

      expect(
        entries.map((e) => e.occurredAt).toList(),
        [DateTime(2026, 3, 1), DateTime(2026, 2, 1), DateTime(2026, 1, 1)],
      );
    });

    test('breaks ties on id so a shared timestamp keeps a stable order', () {
      final sameInstant = DateTime(2026, 5, 5, 10);
      final first = TimelineEntry.merge(
        notes: [note('b', sameInstant), note('a', sameInstant)],
      );
      final second = TimelineEntry.merge(
        notes: [note('a', sameInstant), note('b', sameInstant)],
      );

      expect(first.map((e) => e.id).toList(), second.map((e) => e.id).toList());
    });

    test('compares across time zones by absolute instant', () {
      final utc = DateTime.utc(2026, 4, 1, 12);
      final entries = TimelineEntry.merge(
        notes: [
          note('utc', utc),
          note('later', utc.add(const Duration(hours: 2)).toLocal()),
        ],
      );

      expect(entries.first.id, 'note_later');
    });
  });

  group('isUpcoming', () {
    final now = DateTime(2026, 6, 1, 9);

    test('is true for an activity scheduled ahead of now', () {
      final entry = TimelineEntry.fromActivity(
        activity('a', now.add(const Duration(days: 2))),
      );
      expect(entry.isUpcoming(now: now), isTrue);
    });

    test('is false for anything already past', () {
      final entry = TimelineEntry.fromActivity(
        activity('a', now.subtract(const Duration(minutes: 1))),
      );
      expect(entry.isUpcoming(now: now), isFalse);
    });
  });
}
