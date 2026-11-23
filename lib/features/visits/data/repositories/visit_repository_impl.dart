import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/firestore_mapper.dart';
import '../../domain/entities/visit.dart';
import '../../domain/repositories/visit_repository.dart';
import '../models/visit_model.dart';

class VisitRepositoryImpl implements VisitRepository {
  VisitRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _visits =>
      firestore.collection(FirestoreCollections.visits);

  CollectionReference<Map<String, dynamic>> get _venues =>
      firestore.collection(FirestoreCollections.venues);

  CollectionReference<Map<String, dynamic>> get _notes =>
      firestore.collection(FirestoreCollections.notes);

  @override
  Stream<List<Visit>> watchForVenue(
    String venueId, {
    required String assignedEmployeeId,
    int limit = 50,
  }) {
    return _visits
        .where('venueId', isEqualTo: venueId)
        .where('assignedEmployeeId', isEqualTo: assignedEmployeeId)
        .orderBy('startAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(VisitModel.fromDoc).toList());
  }

  @override
  Stream<List<Visit>> watchForEmployee(String employeeId, {int limit = 50}) {
    return _visits
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('startAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(VisitModel.fromDoc).toList());
  }

  @override
  Stream<List<Visit>> watchForProject(String projectId, {int limit = 50}) {
    return _visits
        .where('projectId', isEqualTo: projectId)
        .orderBy('startAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(VisitModel.fromDoc).toList());
  }

  @override
  Future<Result<Visit?>> findOpenVisit(String employeeId) {
    return guard(() async {
      final snapshot = await _visits
          .where('employeeId', isEqualTo: employeeId)
          .where('status', isEqualTo: VisitStatus.inProgress.value)
          .orderBy('startAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return VisitModel.fromDoc(snapshot.docs.first);
    });
  }

  @override
  Stream<Visit?> watchVisit(String visitId) {
    return _visits
        .doc(visitId)
        .snapshots()
        .map((doc) => doc.exists ? VisitModel.fromDoc(doc) : null);
  }

  @override
  Future<Result<String>> startVisit(Visit visit) {
    return guard(() async {
      final ref = _visits.doc();
      await ref.set(VisitModel.toCreateMap(visit));
      return ref.id;
    });
  }

  @override
  Future<Result<void>> completeVisit({
    required Visit visit,
    required String notes,
    DateTime? nextFollowUpAt,
  }) {
    return guard(() async {
      final batch = firestore.batch();
      final endedAt = DateTime.now();
      final trimmedNotes = notes.trim();

      batch.update(
        _visits.doc(visit.id),
        VisitModel.toUpdateMap(
          visit.copyWith(
            status: VisitStatus.completed,
            endAt: endedAt,
            notes: trimmedNotes,
            nextFollowUpAt: nextFollowUpAt,
          ),
        ),
      );

      // Denormalise onto the venue so "visited / not visited" is answerable
      // from the venue list without a per-row query.
      batch.update(_venues.doc(visit.venueId), {
        'lastVisitedAt': Timestamp.fromDate(visit.startAt),
        'visitCount': FieldValue.increment(1),
        'lastActivityAt': serverTime,
        'updatedAt': serverTime,
      });

      if (trimmedNotes.isNotEmpty) {
        batch.set(_notes.doc(), {
          'venueId': visit.venueId,
          'projectId': visit.projectId,
          // Required by the note create rule and by every employee query.
          'assignedEmployeeId': visit.assignedEmployeeId,
          'employeeId': visit.employeeId,
          'employeeName': '',
          'text': trimmedNotes,
          'activityId': visit.activityId,
          'activityType': ActivityType.venueVisit.value,
          'originalText': null,
          'editedAt': null,
          'createdAt': serverTime,
        });
      }

      await batch.commit();
    });
  }

  @override
  Future<Result<void>> cancelVisit(Visit visit, {String reason = ''}) {
    return guard(() => _visits.doc(visit.id).update({
          'status': VisitStatus.cancelled.value,
          'notes': reason.trim(),
          'endAt': Timestamp.fromDate(DateTime.now()),
          'updatedAt': serverTime,
        }));
  }

  @override
  Future<Result<int>> countVisits({
    String? employeeId,
    String? projectId,
    String? venueId,
    DateTime? since,
  }) {
    return guard(() async {
      Query<Map<String, dynamic>> query =
          _visits.where('status', isEqualTo: VisitStatus.completed.value);

      if (employeeId != null) query = query.where('employeeId', isEqualTo: employeeId);
      if (projectId != null) query = query.where('projectId', isEqualTo: projectId);
      if (venueId != null) query = query.where('venueId', isEqualTo: venueId);
      if (since != null) {
        query = query.where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    });
  }
}
