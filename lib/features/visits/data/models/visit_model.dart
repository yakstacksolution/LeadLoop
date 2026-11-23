import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/firestore_mapper.dart';
import '../../domain/entities/visit.dart';

abstract final class VisitModel {
  static Visit fromMap(String id, Map<String, dynamic> data) {
    final point = Read.geoPoint(data, 'location');

    return Visit(
      id: id,
      venueId: Read.string(data, 'venueId'),
      venueName: Read.string(data, 'venueName'),
      projectId: Read.string(data, 'projectId'),
      assignedEmployeeId: Read.string(data, 'assignedEmployeeId'),
      employeeId: Read.string(data, 'employeeId'),
      activityId: Read.stringOrNull(data, 'activityId'),
      startAt: Read.dateTime(data, 'startAt') ??
          Read.dateTime(data, 'createdAt') ??
          DateTime.now(),
      endAt: Read.dateTime(data, 'endAt'),
      status: VisitStatus.fromValue(Read.stringOrNull(data, 'status')),
      latitude: point?.latitude,
      longitude: point?.longitude,
      locationAccuracy: Read.doubleOrNull(data, 'locationAccuracy'),
      notes: Read.string(data, 'notes'),
      // Absent flag means the record predates location support, so treat it
      // as the weaker claim.
      isSelfReported: Read.boolValue(data, 'isSelfReported', true),
      nextFollowUpAt: Read.dateTime(data, 'nextFollowUpAt'),
      createdAt: Read.dateTime(data, 'createdAt'),
      updatedAt: Read.dateTime(data, 'updatedAt'),
    );
  }

  static Visit fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.id, doc.data() ?? const {});

  static Map<String, dynamic> toCreateMap(Visit visit) => {
        'venueId': visit.venueId,
        'venueName': visit.venueName.trim(),
        'projectId': visit.projectId,
        'assignedEmployeeId': visit.assignedEmployeeId,
        'employeeId': visit.employeeId,
        'activityId': visit.activityId,
        'startAt': toTimestamp(visit.startAt),
        'endAt': toTimestamp(visit.endAt),
        'status': visit.status.value,
        'location': visit.hasLocation
            ? GeoPoint(visit.latitude!, visit.longitude!)
            : null,
        'locationAccuracy': visit.locationAccuracy,
        'notes': visit.notes.trim(),
        'isSelfReported': visit.isSelfReported,
        'nextFollowUpAt': toTimestamp(visit.nextFollowUpAt),
        'createdAt': serverTime,
        'updatedAt': serverTime,
      };

  /// `isSelfReported`, `employeeId`, `venueId` and `projectId` are omitted on
  /// purpose — the security rules reject any attempt to change them.
  static Map<String, dynamic> toUpdateMap(Visit visit) => {
        'endAt': toTimestamp(visit.endAt),
        'status': visit.status.value,
        'notes': visit.notes.trim(),
        'nextFollowUpAt': toTimestamp(visit.nextFollowUpAt),
        'updatedAt': serverTime,
      };
}
