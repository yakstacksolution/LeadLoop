import '../../../../core/errors/result.dart';
import '../entities/venue_contact.dart';

abstract interface class ContactRepository {
  /// Contacts for a venue, primary contact first.
  ///
  /// [assignedEmployeeId] is the parent venue's assignee. It is not a
  /// convenience filter: without it the query cannot satisfy the `list` rule
  /// for an employee, because Firestore matches rules against query filters.
  Stream<List<VenueContact>> watchContactsForVenue(
    String venueId, {
    required String assignedEmployeeId,
  });

  Future<Result<List<VenueContact>>> getContactsForVenue(
    String venueId, {
    required String assignedEmployeeId,
  });

  Future<Result<String>> createContact(VenueContact contact, {required String createdBy});

  Future<Result<void>> updateContact(VenueContact contact);

  /// Marks one contact primary and demotes the rest, atomically.
  Future<Result<void>> setPrimary({
    required String venueId,
    required String contactId,
    required String assignedEmployeeId,
  });

  Future<Result<void>> deleteContact(String contactId);
}
