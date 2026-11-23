import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/firestore_mapper.dart';
import '../../domain/entities/venue_contact.dart';
import '../../domain/repositories/contact_repository.dart';
import '../models/venue_contact_model.dart';

class ContactRepositoryImpl implements ContactRepository {
  ContactRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _contacts =>
      firestore.collection(FirestoreCollections.venueContacts);

  Query<Map<String, dynamic>> _forVenue(String venueId, String assignedEmployeeId) =>
      _contacts
          .where('venueId', isEqualTo: venueId)
          .where('assignedEmployeeId', isEqualTo: assignedEmployeeId)
          .orderBy('isPrimary', descending: true)
          .orderBy('createdAt');

  @override
  Stream<List<VenueContact>> watchContactsForVenue(
    String venueId, {
    required String assignedEmployeeId,
  }) {
    return _forVenue(venueId, assignedEmployeeId)
        .snapshots()
        .map((snap) => snap.docs.map(VenueContactModel.fromDoc).toList());
  }

  @override
  Future<Result<List<VenueContact>>> getContactsForVenue(
    String venueId, {
    required String assignedEmployeeId,
  }) {
    return guard(() async {
      final snapshot = await _forVenue(venueId, assignedEmployeeId).get();
      return snapshot.docs.map(VenueContactModel.fromDoc).toList();
    });
  }

  @override
  Future<Result<String>> createContact(VenueContact contact, {required String createdBy}) {
    return guard(() async {
      final existing = await _contacts
          .where('venueId', isEqualTo: contact.venueId)
          .where('assignedEmployeeId', isEqualTo: contact.assignedEmployeeId)
          .get();

      // The first contact on a venue becomes primary automatically — a venue
      // with contacts but no primary is never useful.
      final isFirst = existing.docs.isEmpty;
      final shouldBePrimary = contact.isPrimary || isFirst;

      final batch = firestore.batch();
      final ref = _contacts.doc();

      batch.set(
        ref,
        VenueContactModel.toCreateMap(
          contact.copyWith(isPrimary: shouldBePrimary),
          createdBy,
        ),
      );

      if (shouldBePrimary) {
        for (final doc in existing.docs) {
          if (doc.data()['isPrimary'] == true) {
            batch.update(doc.reference, {'isPrimary': false, 'updatedAt': serverTime});
          }
        }
      }

      await batch.commit();
      return ref.id;
    });
  }

  @override
  Future<Result<void>> updateContact(VenueContact contact) {
    return guard(
      () => _contacts.doc(contact.id).update(VenueContactModel.toUpdateMap(contact)),
    );
  }

  @override
  Future<Result<void>> setPrimary({
    required String venueId,
    required String contactId,
    required String assignedEmployeeId,
  }) {
    return guard(() async {
      final existing = await _contacts
          .where('venueId', isEqualTo: venueId)
          .where('assignedEmployeeId', isEqualTo: assignedEmployeeId)
          .get();
      final batch = firestore.batch();

      for (final doc in existing.docs) {
        final shouldBePrimary = doc.id == contactId;
        if ((doc.data()['isPrimary'] == true) != shouldBePrimary) {
          batch.update(doc.reference, {
            'isPrimary': shouldBePrimary,
            'updatedAt': serverTime,
          });
        }
      }

      await batch.commit();
    });
  }

  @override
  Future<Result<void>> deleteContact(String contactId) {
    return guard(() => _contacts.doc(contactId).delete());
  }
}
