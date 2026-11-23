import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/firestore_mapper.dart';
import '../../domain/entities/venue_note.dart';

abstract final class VenueNoteModel {
  static VenueNote fromMap(String id, Map<String, dynamic> data) {
    final type = Read.stringOrNull(data, 'activityType');

    return VenueNote(
      id: id,
      venueId: Read.string(data, 'venueId'),
      projectId: Read.string(data, 'projectId'),
      assignedEmployeeId: Read.string(data, 'assignedEmployeeId'),
      employeeId: Read.string(data, 'employeeId'),
      employeeName: Read.string(data, 'employeeName'),
      text: Read.string(data, 'text'),
      activityId: Read.stringOrNull(data, 'activityId'),
      activityType: type == null ? null : ActivityType.fromValue(type),
      originalText: Read.stringOrNull(data, 'originalText'),
      editedAt: Read.dateTime(data, 'editedAt'),
      createdAt: Read.dateTime(data, 'createdAt'),
    );
  }

  static VenueNote fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.id, doc.data() ?? const {});

  static Map<String, dynamic> toCreateMap(VenueNote note) => {
        'venueId': note.venueId,
        'projectId': note.projectId,
        'assignedEmployeeId': note.assignedEmployeeId,
        'employeeId': note.employeeId,
        'employeeName': note.employeeName.trim(),
        'text': note.text.trim(),
        'activityId': note.activityId,
        'activityType': note.activityType?.value,
        'originalText': null,
        'editedAt': null,
        'createdAt': serverTime,
      };

  /// An edit keeps `createdAt` untouched (the rules insist on it) and records
  /// the previous wording the first time round.
  static Map<String, dynamic> toEditMap(VenueNote note, String previousText) => {
        'text': note.text.trim(),
        'originalText': note.originalText ?? previousText,
        'editedAt': serverTime,
      };
}

abstract final class StatusChangeModel {
  static StatusChange fromMap(String id, Map<String, dynamic> data) {
    final previous = Read.stringOrNull(data, 'previousStatus');

    return StatusChange(
      id: id,
      venueId: Read.string(data, 'venueId'),
      projectId: Read.string(data, 'projectId'),
      assignedEmployeeId: Read.string(data, 'assignedEmployeeId'),
      previousStatus: previous == null ? null : LeadStatus.fromValue(previous),
      newStatus: LeadStatus.fromValue(Read.stringOrNull(data, 'newStatus')),
      changedBy: Read.string(data, 'changedBy'),
      changedByName: Read.string(data, 'changedByName'),
      reason: Read.string(data, 'reason'),
      createdAt: Read.dateTime(data, 'createdAt'),
    );
  }

  static StatusChange fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.id, doc.data() ?? const {});

  static Map<String, dynamic> toCreateMap(StatusChange change) => {
        'venueId': change.venueId,
        'projectId': change.projectId,
        'assignedEmployeeId': change.assignedEmployeeId,
        'previousStatus': change.previousStatus?.value,
        'newStatus': change.newStatus.value,
        'changedBy': change.changedBy,
        'changedByName': change.changedByName.trim(),
        'reason': change.reason.trim(),
        'source': 'client',
        'createdAt': serverTime,
      };
}
