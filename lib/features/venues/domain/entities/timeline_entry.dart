import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import '../../../activities/domain/entities/activity.dart';
import '../../../visits/domain/entities/visit.dart';
import 'venue_note.dart';

enum TimelineKind { note, statusChange, activity, visit }

/// One dated item on a venue's history, whatever collection it came from.
///
/// Merging notes, status changes, activities and visits into a single sorted
/// list is what turns four collections into the readable narrative the spec
/// asks for.
class TimelineEntry extends Equatable {
  const TimelineEntry({
    required this.id,
    required this.kind,
    required this.occurredAt,
    required this.title,
    this.body = '',
    this.actorName = '',
    this.activityType,
    this.previousStatus,
    this.newStatus,
    this.isSelfReported,
    this.wasEdited = false,
  });

  final String id;
  final TimelineKind kind;
  final DateTime occurredAt;
  final String title;
  final String body;
  final String actorName;
  final ActivityType? activityType;
  final LeadStatus? previousStatus;
  final LeadStatus? newStatus;

  /// Only set for visits — lets the UI distinguish a self-reported visit from
  /// a location-supported one.
  final bool? isSelfReported;
  final bool wasEdited;

  factory TimelineEntry.fromNote(VenueNote note) => TimelineEntry(
        id: 'note_${note.id}',
        kind: TimelineKind.note,
        // Null while the server timestamp is still pending, which only
        // happens for a note written seconds ago — so "now" is right.
        occurredAt: note.createdAt ?? DateTime.now(),
        title: note.activityType?.label ?? 'Note',
        body: note.text,
        actorName: note.employeeName,
        activityType: note.activityType,
        wasEdited: note.wasEdited,
      );

  factory TimelineEntry.fromStatusChange(StatusChange change) => TimelineEntry(
        id: 'status_${change.id}',
        kind: TimelineKind.statusChange,
        occurredAt: change.createdAt ?? DateTime.now(),
        title: change.previousStatus == null
            ? 'Status set to ${change.newStatus.label}'
            : '${change.previousStatus!.label} → ${change.newStatus.label}',
        body: change.reason,
        actorName: change.changedByName,
        previousStatus: change.previousStatus,
        newStatus: change.newStatus,
      );

  factory TimelineEntry.fromActivity(Activity activity) => TimelineEntry(
        id: 'activity_${activity.id}',
        kind: TimelineKind.activity,
        // Completed work belongs at the time it was done; anything still open
        // belongs at the time it is due.
        occurredAt: activity.completedAt ?? activity.scheduledAt,
        title: activity.title.trim().isEmpty ? activity.type.label : activity.title,
        body: activity.outcomeNote.trim().isEmpty
            ? activity.description
            : activity.outcomeNote,
        activityType: activity.type,
      );

  factory TimelineEntry.fromVisit(Visit visit) => TimelineEntry(
        id: 'visit_${visit.id}',
        kind: TimelineKind.visit,
        occurredAt: visit.startAt,
        title: 'Venue visit — ${visit.status.label}',
        body: visit.notes,
        activityType: ActivityType.venueVisit,
        isSelfReported: visit.isSelfReported,
      );

  /// True for an activity that has not happened yet: it sits on the timeline
  /// at its scheduled slot, which is in the future.
  bool isUpcoming({DateTime? now}) =>
      occurredAt.isAfter(now ?? DateTime.now());

  /// Merges every source into one newest-first list.
  static List<TimelineEntry> merge({
    List<VenueNote> notes = const [],
    List<StatusChange> statusChanges = const [],
    List<Activity> activities = const [],
    List<Visit> visits = const [],
  }) {
    final entries = <TimelineEntry>[
      ...notes.map(TimelineEntry.fromNote),
      ...statusChanges.map(TimelineEntry.fromStatusChange),
      // An activity whose outcome was written as a note would appear twice, so
      // only completed-without-note and still-open activities are included.
      ...activities
          .where((a) => a.outcomeNote.trim().isEmpty)
          .map(TimelineEntry.fromActivity),
      ...visits.map(TimelineEntry.fromVisit),
    ];

    // Newest first. Two records written in the same batch — a status change
    // and its note — share a timestamp to the millisecond, so the id breaks
    // the tie and the order stops depending on which stream arrived first.
    entries.sort((a, b) {
      final byTime = b.occurredAt.toUtc().compareTo(a.occurredAt.toUtc());
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return entries;
  }

  @override
  List<Object?> get props => [
        id,
        kind,
        occurredAt,
        title,
        body,
        actorName,
        activityType,
        previousStatus,
        newStatus,
        isSelfReported,
        wasEdited,
      ];
}
