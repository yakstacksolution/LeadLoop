import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/firestore_mapper.dart';
import '../../domain/entities/venue.dart';
import '../../domain/entities/venue_filter.dart';
import '../../domain/entities/venue_note.dart';
import '../../domain/repositories/venue_repository.dart';
import '../models/venue_model.dart';
import '../models/venue_note_model.dart';

class VenueRepositoryImpl implements VenueRepository {
  VenueRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _venues =>
      firestore.collection(FirestoreCollections.venues);

  CollectionReference<Map<String, dynamic>> get _notes =>
      firestore.collection(FirestoreCollections.notes);

  CollectionReference<Map<String, dynamic>> get _history =>
      firestore.collection(FirestoreCollections.statusHistory);

  /// Builds the server-side half of a filter. Only the predicates that have a
  /// matching composite index in firestore.indexes.json go in here.
  Query<Map<String, dynamic>> _query(VenueFilter filter) {
    Query<Map<String, dynamic>> query = _venues;

    if (filter.projectId != null) {
      query = query.where('projectId', isEqualTo: filter.projectId);
    }
    if (filter.assignedEmployeeId != null) {
      query = query.where('assignedEmployeeId', isEqualTo: filter.assignedEmployeeId);
    }
    if (filter.status != null) {
      query = query.where('status', isEqualTo: filter.status!.value);
    }

    return query.orderBy(filter.sort.field, descending: filter.sort.descending);
  }

  /// The in-memory half: predicates Firestore cannot combine with the above
  /// without an index per permutation. `VenueFilter.matches` holds the rules
  /// so the list cubit can apply exactly the same ones to a single venue.
  List<Venue> _applyClientFilters(List<Venue> venues, VenueFilter filter) =>
      venues.where(filter.matches).toList();

  @override
  Future<Result<VenuePage>> fetchVenues({
    required VenueFilter filter,
    Object? cursor,
    int limit = AppLimits.pageSize,
  }) {
    return guard(() async {
      Query<Map<String, dynamic>> query = _query(filter).limit(limit);

      if (cursor is DocumentSnapshot) {
        query = query.startAfterDocument(cursor);
      }

      final snapshot = await query.get();
      final venues = snapshot.docs.map(VenueModel.fromDoc).toList();

      return VenuePage(
        venues: _applyClientFilters(venues, filter),
        cursor: snapshot.docs.isEmpty ? null : snapshot.docs.last,
        // Judged on the raw page size: a page that was entirely filtered out
        // in memory still means there is more to read on the server.
        hasMore: snapshot.docs.length == limit,
      );
    });
  }

  @override
  Stream<Venue?> watchVenue(String venueId) {
    return _venues
        .doc(venueId)
        .snapshots()
        .map((doc) => doc.exists ? VenueModel.fromDoc(doc) : null);
  }

  @override
  Future<Result<Venue>> getVenue(String venueId) {
    return guard(() async {
      final doc = await _venues.doc(venueId).get();
      if (!doc.exists) throw const NotFoundFailure('That venue no longer exists.');
      return VenueModel.fromDoc(doc);
    });
  }

  @override
  Future<Result<String>> createVenue(Venue venue, {required String createdBy}) {
    return guard(() async {
      final ref = _venues.doc();
      final batch = firestore.batch();

      batch.set(ref, VenueModel.toCreateMap(venue, createdBy));

      // Seed the history so the timeline starts at "New" rather than with a
      // gap before the first manual status change.
      batch.set(_history.doc(), {
        'venueId': ref.id,
        'projectId': venue.projectId,
        'assignedEmployeeId': venue.assignedEmployeeId,
        'previousStatus': null,
        'newStatus': venue.status.value,
        'changedBy': createdBy,
        'changedByName': '',
        'reason': 'Venue created',
        'source': 'client',
        'createdAt': serverTime,
      });

      await batch.commit();
      return ref.id;
    });
  }

  @override
  Future<Result<void>> updateVenue(Venue venue) {
    return guard(() => _venues.doc(venue.id).update(VenueModel.toUpdateMap(venue)));
  }

  @override
  Future<Result<void>> changeStatus({
    required Venue venue,
    required LeadStatus newStatus,
    required String changedBy,
    required String changedByName,
    String reason = '',
  }) {
    return guard(() async {
      if (venue.status == newStatus) return;

      final batch = firestore.batch();

      batch.update(_venues.doc(venue.id), {
        'status': newStatus.value,
        // Read back by the recordVenueStatusChange trigger for attribution.
        'lastStatusChangedBy': changedBy,
        'lastStatusChangeReason': reason.trim(),
        'lastActivityAt': serverTime,
        'updatedAt': serverTime,
      });

      batch.set(
        _history.doc(),
        StatusChangeModel.toCreateMap(
          StatusChange(
            id: '',
            venueId: venue.id,
            projectId: venue.projectId,
            assignedEmployeeId: venue.assignedEmployeeId,
            previousStatus: venue.status,
            newStatus: newStatus,
            changedBy: changedBy,
            changedByName: changedByName,
            reason: reason,
          ),
        ),
      );

      await batch.commit();
    });
  }

  @override
  Future<Result<void>> reassign({
    required String venueId,
    required String employeeId,
    String? projectId,
  }) {
    return guard(() async {
      final snapshot = await _venues.doc(venueId).get();
      if (!snapshot.exists) {
        throw const NotFoundFailure('That venue no longer exists.');
      }

      final previousAssignee = VenueModel.fromDoc(snapshot).assignedEmployeeId;

      await _venues.doc(venueId).update({
        'assignedEmployeeId': employeeId,
        'projectId': ?projectId,
        'updatedAt': serverTime,
      });

      if (previousAssignee == employeeId) return;

      // Every child record carries the venue's assignee so that employees can
      // query it. Leaving them on the old assignee would make the whole
      // history invisible to the new one, so they move with the venue.
      await _reassignChildren(
        venueId: venueId,
        previousAssignee: previousAssignee,
        employeeId: employeeId,
        projectId: projectId,
      );
    });
  }

  /// Rewrites `assignedEmployeeId` on a venue's child records.
  ///
  /// Done in chunks because a batch is capped at 500 writes, and a long-running
  /// venue can accumulate more history than that.
  Future<void> _reassignChildren({
    required String venueId,
    required String previousAssignee,
    required String employeeId,
    String? projectId,
  }) async {
    final collections = [
      FirestoreCollections.venueContacts,
      FirestoreCollections.activities,
      FirestoreCollections.visits,
      FirestoreCollections.notes,
      FirestoreCollections.statusHistory,
    ];

    for (final collection in collections) {
      var hasMore = true;

      while (hasMore) {
        final page = await firestore
            .collection(collection)
            .where('venueId', isEqualTo: venueId)
            .where('assignedEmployeeId', isEqualTo: previousAssignee)
            .limit(400)
            .get();

        if (page.docs.isEmpty) {
          hasMore = false;
          continue;
        }

        final batch = firestore.batch();
        for (final doc in page.docs) {
          batch.update(doc.reference, {
            'assignedEmployeeId': employeeId,
            'projectId': ?projectId,
          });
        }
        await batch.commit();

        hasMore = page.docs.length == 400;
      }
    }
  }

  @override
  Future<Result<void>> setArchived(String venueId, bool archived) {
    return guard(() => _venues.doc(venueId).update({
          'isArchived': archived,
          'updatedAt': serverTime,
        }));
  }

  @override
  Future<Result<void>> setNextFollowUp({
    required String venueId,
    DateTime? at,
    ActivityType? type,
  }) {
    return guard(() => _venues.doc(venueId).update({
          'nextFollowUpAt': toTimestamp(at),
          'nextFollowUpType': type?.value,
          'updatedAt': serverTime,
        }));
  }

  @override
  Stream<List<StatusChange>> watchStatusHistory(
    String venueId, {
    required String assignedEmployeeId,
  }) {
    // Deliberately unordered in the query, then sorted here.
    //
    // `createdAt` is a server timestamp, and a document written moments ago
    // still has it as null locally. Firestore drops documents whose orderBy
    // field is null, so ordering in the query means a status change the user
    // just made is invisible until the server acknowledges it — the timeline
    // would sit unchanged for the round trip. Sorting in Dart lets the local
    // write show immediately, with the pending entry treated as newest.
    return _history
        .where('venueId', isEqualTo: venueId)
        .where('assignedEmployeeId', isEqualTo: assignedEmployeeId)
        .snapshots()
        .map((snap) {
          final changes = snap.docs.map(StatusChangeModel.fromDoc).toList()
            ..sort((a, b) {
              final aAt = a.createdAt;
              final bAt = b.createdAt;
              if (aAt == null && bAt == null) return 0;
              // A pending timestamp is a write from this device, seconds old.
              if (aAt == null) return -1;
              if (bAt == null) return 1;
              return bAt.compareTo(aAt);
            });
          return changes;
        });
  }

  @override
  Stream<List<VenueNote>> watchNotes(
    String venueId, {
    required String assignedEmployeeId,
    int limit = 50,
  }) {
    return _notes
        .where('venueId', isEqualTo: venueId)
        .where('assignedEmployeeId', isEqualTo: assignedEmployeeId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(VenueNoteModel.fromDoc).toList());
  }

  @override
  Future<Result<String>> addNote(VenueNote note) {
    return guard(() async {
      final batch = firestore.batch();
      final ref = _notes.doc();

      batch.set(ref, VenueNoteModel.toCreateMap(note));
      batch.update(_venues.doc(note.venueId), {
        'lastActivityAt': serverTime,
        'updatedAt': serverTime,
      });

      await batch.commit();
      return ref.id;
    });
  }

  @override
  Future<Result<void>> editNote(VenueNote note, {required String previousText}) {
    return guard(
      () => _notes.doc(note.id).update(VenueNoteModel.toEditMap(note, previousText)),
    );
  }

  @override
  Future<Result<Map<LeadStatus, int>>> countByStatus({
    String? projectId,
    String? assignedEmployeeId,
    List<LeadStatus> statuses = const [],
  }) {
    return guard(() async {
      Query<Map<String, dynamic>> base = _venues;
      if (projectId != null) base = base.where('projectId', isEqualTo: projectId);
      if (assignedEmployeeId != null) {
        base = base.where('assignedEmployeeId', isEqualTo: assignedEmployeeId);
      }

      // One server-side count per status — still far cheaper than streaming
      // every venue document to the client, but each one is a round trip, so
      // only the requested statuses are counted.
      final wanted = statuses.isEmpty ? LeadStatus.values : statuses;

      final counts = await Future.wait(
        wanted.map((status) async {
          final snapshot =
              await base.where('status', isEqualTo: status.value).count().get();
          return MapEntry(status, snapshot.count ?? 0);
        }),
      );

      return Map.fromEntries(counts);
    });
  }

  @override
  Future<Result<int>> countVenues({String? projectId, String? assignedEmployeeId}) {
    return guard(() async {
      Query<Map<String, dynamic>> base = _venues;
      if (projectId != null) base = base.where('projectId', isEqualTo: projectId);
      if (assignedEmployeeId != null) {
        base = base.where('assignedEmployeeId', isEqualTo: assignedEmployeeId);
      }
      final snapshot = await base.count().get();
      return snapshot.count ?? 0;
    });
  }

  @override
  Future<Result<List<Venue>>> fetchDueFollowUps({
    required String assignedEmployeeId,
    required DateTime before,
    int limit = 50,
  }) {
    return guard(() async {
      final snapshot = await _venues
          .where('assignedEmployeeId', isEqualTo: assignedEmployeeId)
          .where('nextFollowUpAt', isLessThanOrEqualTo: Timestamp.fromDate(before))
          .orderBy('nextFollowUpAt')
          .limit(limit)
          .get();

      // Won and lost leads keep their last follow-up date but should not keep
      // appearing on anyone's to-do list.
      return snapshot.docs
          .map(VenueModel.fromDoc)
          .where((venue) => !venue.isArchived && !venue.status.isClosed)
          .toList();
    });
  }
}
