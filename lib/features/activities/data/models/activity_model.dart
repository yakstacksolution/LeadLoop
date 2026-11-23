import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/firestore_mapper.dart';
import '../../domain/entities/activity.dart';

abstract final class ActivityModel {
  static Activity fromMap(String id, Map<String, dynamic> data) {
    return Activity(
      id: id,
      venueId: Read.string(data, 'venueId'),
      venueName: Read.string(data, 'venueName'),
      contactId: Read.stringOrNull(data, 'contactId'),
      projectId: Read.string(data, 'projectId'),
      assignedEmployeeId: Read.string(data, 'assignedEmployeeId'),
      type: ActivityType.fromValue(Read.stringOrNull(data, 'type')),
      title: Read.string(data, 'title'),
      description: Read.string(data, 'description'),
      // A missing schedule would break every ordering; fall back to the
      // creation time rather than dropping the record.
      scheduledAt: Read.dateTime(data, 'scheduledAt') ??
          Read.dateTime(data, 'createdAt') ??
          DateTime.now(),
      endAt: Read.dateTime(data, 'endAt'),
      reminderAt: Read.dateTime(data, 'reminderAt'),
      status: ActivityStatus.fromValue(Read.stringOrNull(data, 'status')),
      outcomeNote: Read.string(data, 'outcomeNote'),
      completedAt: Read.dateTime(data, 'completedAt'),
      rescheduledFrom: Read.dateTime(data, 'rescheduledFrom'),
      createdBy: Read.stringOrNull(data, 'createdBy'),
      createdAt: Read.dateTime(data, 'createdAt'),
      updatedAt: Read.dateTime(data, 'updatedAt'),
    );
  }

  static Activity fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.id, doc.data() ?? const {});

  static Map<String, dynamic> toCreateMap(Activity activity, String createdBy) => {
        'venueId': activity.venueId,
        'venueName': activity.venueName.trim(),
        'contactId': activity.contactId,
        'projectId': activity.projectId,
        'assignedEmployeeId': activity.assignedEmployeeId,
        ..._editableFields(activity),
        'status': activity.status.value,
        'outcomeNote': '',
        'completedAt': null,
        'rescheduledFrom': toTimestamp(activity.rescheduledFrom),
        'createdBy': createdBy,
        'createdAt': serverTime,
        'updatedAt': serverTime,
      };

  static Map<String, dynamic> toUpdateMap(Activity activity) => {
        ..._editableFields(activity),
        'contactId': activity.contactId,
        'status': activity.status.value,
        'outcomeNote': activity.outcomeNote.trim(),
        'completedAt': toTimestamp(activity.completedAt),
        'rescheduledFrom': toTimestamp(activity.rescheduledFrom),
        'updatedAt': serverTime,
      };

  static Map<String, dynamic> _editableFields(Activity activity) => {
        'type': activity.type.value,
        'title': activity.title.trim(),
        'description': activity.description.trim(),
        'scheduledAt': toTimestamp(activity.scheduledAt),
        'endAt': toTimestamp(activity.endAt),
        'reminderAt': toTimestamp(activity.reminderAt),
      };
}
