import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/app_date_utils.dart';

/// A scheduled call, meeting, visit or follow-up.
///
/// The app records the *plan* and its outcome. It does not place calls and
/// makes no claim that one happened — `status` is set by the employee.
class Activity extends Equatable {
  const Activity({
    required this.id,
    required this.venueId,
    required this.projectId,
    required this.assignedEmployeeId,
    required this.type,
    required this.title,
    required this.status,
    required this.scheduledAt,
    this.contactId,
    this.venueName = '',
    this.description = '',
    this.endAt,
    this.reminderAt,
    this.outcomeNote = '',
    this.completedAt,
    this.rescheduledFrom,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String venueId;

  /// Denormalised for list rendering — an activity list would otherwise need
  /// one venue read per row.
  final String venueName;
  final String? contactId;
  final String projectId;
  final String assignedEmployeeId;
  final ActivityType type;
  final String title;
  final String description;
  final DateTime scheduledAt;
  final DateTime? endAt;
  final DateTime? reminderAt;
  final ActivityStatus status;
  final String outcomeNote;
  final DateTime? completedAt;

  /// Set when this activity replaced an earlier slot, so the history shows the
  /// reschedule rather than silently moving the original.
  final DateTime? rescheduledFrom;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Past its slot and still open. A cancelled or completed activity is never
  /// overdue, however old it is.
  bool get isOverdue => status.isOpen && AppDateUtils.isOverdue(scheduledAt);

  bool get isToday => status.isOpen && AppDateUtils.isToday(scheduledAt);

  bool get isUpcoming => status.isOpen && AppDateUtils.isUpcoming(scheduledAt);

  bool get isDone => status == ActivityStatus.completed;

  Activity copyWith({
    String? title,
    String? description,
    String? contactId,
    ActivityType? type,
    DateTime? scheduledAt,
    DateTime? endAt,
    DateTime? reminderAt,
    ActivityStatus? status,
    String? outcomeNote,
    DateTime? completedAt,
    DateTime? rescheduledFrom,
    bool clearEndAt = false,
    bool clearReminder = false,
  }) {
    return Activity(
      id: id,
      venueId: venueId,
      venueName: venueName,
      contactId: contactId ?? this.contactId,
      projectId: projectId,
      assignedEmployeeId: assignedEmployeeId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      endAt: clearEndAt ? null : (endAt ?? this.endAt),
      reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
      status: status ?? this.status,
      outcomeNote: outcomeNote ?? this.outcomeNote,
      completedAt: completedAt ?? this.completedAt,
      rescheduledFrom: rescheduledFrom ?? this.rescheduledFrom,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        venueId,
        venueName,
        contactId,
        projectId,
        assignedEmployeeId,
        type,
        title,
        description,
        scheduledAt,
        endAt,
        reminderAt,
        status,
        outcomeNote,
        completedAt,
        rescheduledFrom,
        createdBy,
        createdAt,
        updatedAt,
      ];
}
