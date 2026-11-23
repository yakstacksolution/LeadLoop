import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/firestore_mapper.dart';
import '../../domain/entities/venue.dart';

abstract final class VenueModel {
  static Venue fromMap(String id, Map<String, dynamic> data) {
    final point = Read.geoPoint(data, 'location');

    return Venue(
      id: id,
      name: Read.string(data, 'name'),
      address: Read.string(data, 'address'),
      city: Read.string(data, 'city'),
      area: Read.string(data, 'area'),
      latitude: point?.latitude ?? Read.doubleOrNull(data, 'latitude'),
      longitude: point?.longitude ?? Read.doubleOrNull(data, 'longitude'),
      courtCount: Read.intOrNull(data, 'courtCount'),
      venueType: VenueType.fromValue(Read.stringOrNull(data, 'venueType')),
      leadSource: LeadSource.fromValue(Read.stringOrNull(data, 'leadSource')),
      priority: VenuePriority.fromValue(Read.stringOrNull(data, 'priority')),
      status: LeadStatus.fromValue(Read.stringOrNull(data, 'status')),
      assignedEmployeeId: Read.string(data, 'assignedEmployeeId'),
      projectId: Read.string(data, 'projectId'),
      createdBy: Read.stringOrNull(data, 'createdBy'),
      createdAt: Read.dateTime(data, 'createdAt'),
      updatedAt: Read.dateTime(data, 'updatedAt'),
      lastActivityAt: Read.dateTime(data, 'lastActivityAt'),
      nextFollowUpAt: Read.dateTime(data, 'nextFollowUpAt'),
      nextFollowUpType: Read.stringOrNull(data, 'nextFollowUpType') == null
          ? null
          : ActivityType.fromValue(Read.stringOrNull(data, 'nextFollowUpType')),
      lastVisitedAt: Read.dateTime(data, 'lastVisitedAt'),
      visitCount: Read.intValue(data, 'visitCount'),
      isArchived: Read.boolValue(data, 'isArchived'),
    );
  }

  static Venue fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.id, doc.data() ?? const {});

  static Map<String, dynamic> toCreateMap(Venue venue, String createdBy) => {
        ..._sharedFields(venue),
        'assignedEmployeeId': venue.assignedEmployeeId,
        'projectId': venue.projectId,
        'status': venue.status.value,
        'visitCount': 0,
        'isArchived': false,
        'createdBy': createdBy,
        // The rules require exactly `request.time` here, which is also what
        // keeps list ordering independent of device clocks.
        'createdAt': serverTime,
        'updatedAt': serverTime,
        'lastActivityAt': serverTime,
      };

  /// Editable venue details. Deliberately omits `status`, `projectId`,
  /// `assignedEmployeeId` and the visit counters — each of those has its own
  /// guarded path.
  static Map<String, dynamic> toUpdateMap(Venue venue) => {
        ..._sharedFields(venue),
        'updatedAt': serverTime,
      };

  static Map<String, dynamic> _sharedFields(Venue venue) => {
        'name': venue.name.trim(),
        'address': venue.address.trim(),
        'city': venue.city.trim(),
        'area': venue.area.trim(),
        'location': venue.hasLocation
            ? GeoPoint(venue.latitude!, venue.longitude!)
            : null,
        'courtCount': venue.courtCount,
        'venueType': venue.venueType.value,
        'leadSource': venue.leadSource.value,
        'priority': venue.priority.value,
        'nextFollowUpAt': toTimestamp(venue.nextFollowUpAt),
        'nextFollowUpType': venue.nextFollowUpType?.value,
      };
}
