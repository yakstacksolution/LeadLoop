import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/firestore_mapper.dart';
import '../../domain/entities/venue_contact.dart';

abstract final class VenueContactModel {
  static VenueContact fromMap(String id, Map<String, dynamic> data) {
    return VenueContact(
      id: id,
      venueId: Read.string(data, 'venueId'),
      projectId: Read.string(data, 'projectId'),
      assignedEmployeeId: Read.string(data, 'assignedEmployeeId'),
      fullName: Read.string(data, 'fullName'),
      designation: Read.string(data, 'designation'),
      phone: Read.string(data, 'phone'),
      email: Read.string(data, 'email'),
      preferredContactMethod:
          ContactMethod.fromValue(Read.stringOrNull(data, 'preferredContactMethod')),
      notes: Read.string(data, 'notes'),
      isPrimary: Read.boolValue(data, 'isPrimary'),
      createdBy: Read.stringOrNull(data, 'createdBy'),
      createdAt: Read.dateTime(data, 'createdAt'),
      updatedAt: Read.dateTime(data, 'updatedAt'),
    );
  }

  static VenueContact fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.id, doc.data() ?? const {});

  static Map<String, dynamic> toCreateMap(VenueContact contact, String createdBy) => {
        ..._fields(contact),
        'venueId': contact.venueId,
        'projectId': contact.projectId,
        'assignedEmployeeId': contact.assignedEmployeeId,
        'createdBy': createdBy,
        'createdAt': serverTime,
        'updatedAt': serverTime,
      };

  static Map<String, dynamic> toUpdateMap(VenueContact contact) => {
        ..._fields(contact),
        'updatedAt': serverTime,
      };

  static Map<String, dynamic> _fields(VenueContact contact) => {
        'fullName': contact.fullName.trim(),
        'designation': contact.designation.trim(),
        'phone': contact.phone.trim(),
        'email': contact.email.trim().toLowerCase(),
        'preferredContactMethod': contact.preferredContactMethod.value,
        'notes': contact.notes.trim(),
        'isPrimary': contact.isPrimary,
      };
}
