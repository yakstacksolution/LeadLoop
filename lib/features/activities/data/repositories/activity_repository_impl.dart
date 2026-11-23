import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/firestore_mapper.dart';
import '../../domain/entities/activity.dart';
import '../../domain/repositories/activity_repository.dart';
import '../models/activity_model.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  ActivityRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _activities =>
      firestore.collection(FirestoreCollections.activities);

  CollectionReference<Map<String, dynamic>> get _venues =>
      firestore.collection(FirestoreCollections.venues);

  CollectionReference<Map<String, dynamic>> get _notes =>
      firestore.collection(FirestoreCollections.notes);

  /// The two statuses that still need doing. Firestore's `whereIn` covers
  /// both without needing a separate "isOpen" flag on every document.
  static final _openStatuses = [
    ActivityStatus.scheduled.value,
    ActivityStatus.rescheduled.value,
  ];

  @override
  Stream<List<Activity>> watchForVenue(
    String venueId, {
    required String assignedEmployeeId,
    int limit = 50,
  }) {
    return _activities
        .where('venueId', isEqualTo: venueId)
        .where('assignedEmployeeId', isEqualTo: assignedEmployeeId)
        .orderBy('scheduledAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ActivityModel.fromDoc).toList());
  }

  @override
  Stream<List<Activity>> watchOpenForEmployee(String employeeId, {int limit = 100}) {
    return _activities
        .where('assignedEmployeeId', isEqualTo: employeeId)
        .where('status', whereIn: _openStatuses)
        .orderBy('scheduledAt')
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ActivityModel.fromDoc).toList());
  }

  @override
  Stream<List<Activity>> watchOpenForProject(String projectId, {int limit = 100}) {
    return _activities
        .where('projectId', isEqualTo: projectId)
        .where('status', whereIn: _openStatuses)
        .orderBy('scheduledAt')
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ActivityModel.fromDoc).toList());
  }

  @override
  Stream<List<Activity>> watchOpenOrgWide({int limit = 50}) {
    return _activities
        .where('status', whereIn: _openStatuses)
        .orderBy('scheduledAt')
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ActivityModel.fromDoc).toList());
  }

  @override
  Future<Result<List<Activity>>> fetchForEmployee({
    required String employeeId,
    DateTime? from,
    DateTime? to,
    List<ActivityStatus> statuses = const [],
    int limit = AppLimits.pageSize,
  }) {
    return guard(() async {
      Query<Map<String, dynamic>> query =
          _activities.where('assignedEmployeeId', isEqualTo: employeeId);

      if (statuses.isNotEmpty) {
        query = query.where(
          'status',
          whereIn: statuses.map((s) => s.value).take(AppLimits.whereInMax).toList(),
        );
      }
      if (from != null) {
        query = query.where('scheduledAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from));
      }
      if (to != null) {
        query = query.where('scheduledAt', isLessThan: Timestamp.fromDate(to));
      }

      final snapshot = await query.orderBy('scheduledAt').limit(limit).get();
      return snapshot.docs.map(ActivityModel.fromDoc).toList();
    });
  }

  @override
  Stream<Activity?> watchActivity(String activityId) {
    return _activities
        .doc(activityId)
        .snapshots()
        .map((doc) => doc.exists ? ActivityModel.fromDoc(doc) : null);
  }

  @override
  Future<Result<String>> createActivity(Activity activity, {required String createdBy}) {
    return guard(() async {
      final batch = firestore.batch();
      final ref = _activities.doc();

      batch.set(ref, ActivityModel.toCreateMap(activity, createdBy));

      // Keep the venue's "next follow-up" pointer honest: only move it
      // earlier, never later, so the soonest commitment always wins.
      batch.update(_venues.doc(activity.venueId), {
        'lastActivityAt': serverTime,
        'updatedAt': serverTime,
      });

      await batch.commit();
      await _refreshNextFollowUp(activity.venueId, activity.assignedEmployeeId);
      return ref.id;
    });
  }

  @override
  Future<Result<void>> updateActivity(Activity activity) {
    return guard(() async {
      await _activities.doc(activity.id).update(ActivityModel.toUpdateMap(activity));
      await _refreshNextFollowUp(activity.venueId, activity.assignedEmployeeId);
    });
  }

  @override
  Future<Result<void>> complete({
    required Activity activity,
    required String outcomeNote,
    required String employeeName,
  }) {
    return guard(() async {
      final batch = firestore.batch();
      final trimmedNote = outcomeNote.trim();

      batch.update(_activities.doc(activity.id), {
        'status': ActivityStatus.completed.value,
        'outcomeNote': trimmedNote,
        'completedAt': serverTime,
        'updatedAt': serverTime,
      });

      // The outcome also becomes a timeline note, so the venue history reads
      // as one narrative rather than splitting across two collections.
      if (trimmedNote.isNotEmpty) {
        batch.set(_notes.doc(), {
          'venueId': activity.venueId,
          'projectId': activity.projectId,
          // Required by the note create rule and by every employee query.
          'assignedEmployeeId': activity.assignedEmployeeId,
          'employeeId': activity.assignedEmployeeId,
          'employeeName': employeeName.trim(),
          'text': trimmedNote,
          'activityId': activity.id,
          'activityType': activity.type.value,
          'originalText': null,
          'editedAt': null,
          'createdAt': serverTime,
        });
      }

      batch.update(_venues.doc(activity.venueId), {
        'lastActivityAt': serverTime,
        'updatedAt': serverTime,
      });

      await batch.commit();
      await _refreshNextFollowUp(activity.venueId, activity.assignedEmployeeId);
    });
  }

  @override
  Future<Result<void>> cancel(Activity activity, {String reason = ''}) {
    return guard(() async {
      await _activities.doc(activity.id).update({
        'status': ActivityStatus.cancelled.value,
        'outcomeNote': reason.trim(),
        'updatedAt': serverTime,
      });
      await _refreshNextFollowUp(activity.venueId, activity.assignedEmployeeId);
    });
  }

  @override
  Future<Result<String>> reschedule({
    required Activity activity,
    required DateTime newScheduledAt,
    required String createdBy,
  }) {
    return guard(() async {
      final batch = firestore.batch();
      final ref = _activities.doc();

      batch.update(_activities.doc(activity.id), {
        'status': ActivityStatus.rescheduled.value,
        'updatedAt': serverTime,
      });

      batch.set(
        ref,
        ActivityModel.toCreateMap(
          activity.copyWith(
            scheduledAt: newScheduledAt,
            status: ActivityStatus.scheduled,
            rescheduledFrom: activity.scheduledAt,
            clearEndAt: true,
          ),
          createdBy,
        ),
      );

      await batch.commit();
      await _refreshNextFollowUp(activity.venueId, activity.assignedEmployeeId);
      return ref.id;
    });
  }

  @override
  Future<Result<int>> countOpen({
    String? employeeId,
    String? projectId,
    DateTime? dueBefore,
  }) {
    return guard(() async {
      Query<Map<String, dynamic>> query =
          _activities.where('status', whereIn: _openStatuses);

      if (employeeId != null) {
        query = query.where('assignedEmployeeId', isEqualTo: employeeId);
      }
      if (projectId != null) {
        query = query.where('projectId', isEqualTo: projectId);
      }
      if (dueBefore != null) {
        query = query.where('scheduledAt', isLessThan: Timestamp.fromDate(dueBefore));
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    });
  }

  @override
  Future<Result<int>> countByStatus({
    required ActivityStatus status,
    String? employeeId,
    String? projectId,
  }) {
    return guard(() async {
      Query<Map<String, dynamic>> query =
          _activities.where('status', isEqualTo: status.value);

      if (employeeId != null) {
        query = query.where('assignedEmployeeId', isEqualTo: employeeId);
      }
      if (projectId != null) {
        query = query.where('projectId', isEqualTo: projectId);
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    });
  }

  /// Recomputes a venue's `nextFollowUpAt` from its soonest open activity.
  ///
  /// Done as a follow-up read rather than inside the batch because it depends
  /// on the state *after* the write. A failure here is non-fatal: the pointer
  /// is a convenience, and the activities collection remains the truth.
  Future<void> _refreshNextFollowUp(String venueId, String assignedEmployeeId) async {
    try {
      final snapshot = await _activities
          .where('venueId', isEqualTo: venueId)
          .where('assignedEmployeeId', isEqualTo: assignedEmployeeId)
          .where('status', whereIn: _openStatuses)
          .orderBy('scheduledAt')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        await _venues.doc(venueId).update({
          'nextFollowUpAt': null,
          'nextFollowUpType': null,
          'updatedAt': serverTime,
        });
        return;
      }

      final next = ActivityModel.fromDoc(snapshot.docs.first);
      await _venues.doc(venueId).update({
        'nextFollowUpAt': Timestamp.fromDate(next.scheduledAt),
        'nextFollowUpType': next.type.value,
        'updatedAt': serverTime,
      });
    } catch (_) {
      // Left deliberately quiet: the caller's own write already succeeded and
      // surfacing a denormalisation hiccup would only confuse the user.
    }
  }
}
