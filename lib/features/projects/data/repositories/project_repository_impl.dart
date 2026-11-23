import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/firestore_mapper.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';
import '../models/project_model.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  ProjectRepositoryImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _projects =>
      firestore.collection(FirestoreCollections.projects);

  CollectionReference<Map<String, dynamic>> get _users =>
      firestore.collection(FirestoreCollections.users);

  @override
  Stream<List<Project>> watchAllProjects({List<ProjectStatus> statuses = const []}) {
    Query<Map<String, dynamic>> query = _projects;

    if (statuses.isNotEmpty) {
      query = query.where(
        'status',
        whereIn: statuses.map((s) => s.value).take(AppLimits.whereInMax).toList(),
      );
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ProjectModel.fromDoc).toList());
  }

  @override
  Stream<List<Project>> watchProjectsForEmployee(String uid) {
    return _projects
        .where('assignedEmployeeIds', arrayContains: uid)
        .snapshots()
        .map((snap) {
      final projects = snap.docs.map(ProjectModel.fromDoc).toList();
      // Sorted client-side: adding an orderBy here would force a second
      // composite index for a list that is only ever a handful of rows.
      projects.sort((a, b) {
        final byStatus = a.status.index.compareTo(b.status.index);
        if (byStatus != 0) return byStatus;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return projects;
    });
  }

  @override
  Stream<Project?> watchProject(String projectId) {
    return _projects
        .doc(projectId)
        .snapshots()
        .map((doc) => doc.exists ? ProjectModel.fromDoc(doc) : null);
  }

  @override
  Future<Result<Project>> getProject(String projectId) {
    return guard(() async {
      final doc = await _projects.doc(projectId).get();
      if (!doc.exists) throw const NotFoundFailure('That project no longer exists.');
      return ProjectModel.fromDoc(doc);
    });
  }

  @override
  Future<Result<List<Project>>> getProjectsByIds(List<String> ids) {
    return guard(() async {
      if (ids.isEmpty) return <Project>[];

      // `whereIn` caps at 30 values, so fetch in chunks and flatten.
      final chunks = <List<String>>[];
      for (var i = 0; i < ids.length; i += AppLimits.whereInMax) {
        chunks.add(ids.sublist(i, (i + AppLimits.whereInMax).clamp(0, ids.length)));
      }

      final results = await Future.wait(
        chunks.map((chunk) => _projects.where(FieldPath.documentId, whereIn: chunk).get()),
      );

      return results
          .expand((snap) => snap.docs)
          .map(ProjectModel.fromDoc)
          .toList();
    });
  }

  @override
  Future<Result<String>> createProject(Project project, {required String createdBy}) {
    return guard(() async {
      final ref = await _projects.add(ProjectModel.toCreateMap(project, createdBy));

      if (project.assignedEmployeeIds.isNotEmpty) {
        await _applyAssignments(
          projectId: ref.id,
          added: project.assignedEmployeeIds,
          removed: const [],
        );
      }
      return ref.id;
    });
  }

  @override
  Future<Result<void>> updateProject(Project project) {
    return guard(() => _projects.doc(project.id).update(ProjectModel.toUpdateMap(project)));
  }

  @override
  Future<Result<void>> setStatus(String projectId, ProjectStatus status) {
    return guard(() => _projects.doc(projectId).update({
          'status': status.value,
          'updatedAt': serverTime,
        }));
  }

  @override
  Future<Result<void>> setAssignedEmployees({
    required String projectId,
    required List<String> employeeIds,
  }) {
    return guard(() async {
      final doc = await _projects.doc(projectId).get();
      if (!doc.exists) throw const NotFoundFailure('That project no longer exists.');

      final previous = ProjectModel.fromDoc(doc).assignedEmployeeIds;
      final next = employeeIds.toSet().toList();

      await _applyAssignments(
        projectId: projectId,
        added: next.where((id) => !previous.contains(id)).toList(),
        removed: previous.where((id) => !next.contains(id)).toList(),
      );
    });
  }

  /// Writes both directions of the membership link in one atomic batch, so a
  /// partial failure can never leave a user assigned to a project that does
  /// not list them (which would silently break their security-rule access).
  Future<void> _applyAssignments({
    required String projectId,
    required List<String> added,
    required List<String> removed,
  }) async {
    if (added.isEmpty && removed.isEmpty) return;

    final batch = firestore.batch();
    final projectRef = _projects.doc(projectId);

    if (added.isNotEmpty) {
      batch.update(projectRef, {
        'assignedEmployeeIds': FieldValue.arrayUnion(added),
        'updatedAt': serverTime,
      });
    }
    if (removed.isNotEmpty) {
      batch.update(projectRef, {
        'assignedEmployeeIds': FieldValue.arrayRemove(removed),
        'updatedAt': serverTime,
      });
    }

    for (final uid in added) {
      batch.update(_users.doc(uid), {
        'assignedProjectIds': FieldValue.arrayUnion([projectId]),
        'updatedAt': serverTime,
      });
    }
    for (final uid in removed) {
      batch.update(_users.doc(uid), {
        'assignedProjectIds': FieldValue.arrayRemove([projectId]),
        'updatedAt': serverTime,
      });
    }

    await batch.commit();
  }
}
