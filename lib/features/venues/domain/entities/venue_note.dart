import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// A free-text note on a venue's timeline.
///
/// Notes are append-only in spirit: an author may correct their own wording,
/// but the original text is preserved in [originalText] and the correction is
/// stamped, so the timeline never quietly rewrites history.
class VenueNote extends Equatable {
  const VenueNote({
    required this.id,
    required this.venueId,
    required this.projectId,
    required this.assignedEmployeeId,
    required this.employeeId,
    required this.text,
    this.employeeName = '',
    this.activityId,
    this.activityType,
    this.originalText,
    this.editedAt,
    this.createdAt,
  });

  final String id;
  final String venueId;
  final String projectId;

  /// The parent venue's assignee — see [VenueContact.assignedEmployeeId] for
  /// why every scoped record carries this.
  final String assignedEmployeeId;
  final String employeeId;
  final String employeeName;
  final String text;
  final String? activityId;
  final ActivityType? activityType;

  /// Populated the first time a note is edited.
  final String? originalText;
  final DateTime? editedAt;
  final DateTime? createdAt;

  bool get wasEdited => editedAt != null;

  VenueNote copyWith({String? text, String? originalText, DateTime? editedAt}) {
    return VenueNote(
      id: id,
      venueId: venueId,
      projectId: projectId,
      assignedEmployeeId: assignedEmployeeId,
      employeeId: employeeId,
      employeeName: employeeName,
      text: text ?? this.text,
      activityId: activityId,
      activityType: activityType,
      originalText: originalText ?? this.originalText,
      editedAt: editedAt ?? this.editedAt,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        venueId,
        projectId,
        assignedEmployeeId,
        employeeId,
        employeeName,
        text,
        activityId,
        activityType,
        originalText,
        editedAt,
        createdAt,
      ];
}

/// One immutable entry in a venue's lead-status history.
class StatusChange extends Equatable {
  const StatusChange({
    required this.id,
    required this.venueId,
    required this.projectId,
    required this.assignedEmployeeId,
    required this.newStatus,
    required this.changedBy,
    this.previousStatus,
    this.changedByName = '',
    this.reason = '',
    this.createdAt,
  });

  final String id;
  final String venueId;
  final String projectId;
  final String assignedEmployeeId;
  final LeadStatus? previousStatus;
  final LeadStatus newStatus;
  final String changedBy;
  final String changedByName;
  final String reason;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [
        id,
        venueId,
        projectId,
        assignedEmployeeId,
        previousStatus,
        newStatus,
        changedBy,
        changedByName,
        reason,
        createdAt,
      ];
}
