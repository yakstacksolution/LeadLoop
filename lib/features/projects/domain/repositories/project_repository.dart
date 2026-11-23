import '../../../../core/constants/enums.dart';
import '../../../../core/errors/result.dart';
import '../entities/project.dart';

abstract interface class ProjectRepository {
  /// Every project, for admins. [statuses] empty means "all".
  Stream<List<Project>> watchAllProjects({List<ProjectStatus> statuses = const []});

  /// Only the projects [uid] is assigned to — the employee's whole world.
  Stream<List<Project>> watchProjectsForEmployee(String uid);

  Stream<Project?> watchProject(String projectId);

  Future<Result<Project>> getProject(String projectId);

  /// Fetches several projects by id, for screens that resolve project names
  /// on venue or activity rows.
  Future<Result<List<Project>>> getProjectsByIds(List<String> ids);

  Future<Result<String>> createProject(Project project, {required String createdBy});

  Future<Result<void>> updateProject(Project project);

  Future<Result<void>> setStatus(String projectId, ProjectStatus status);

  /// Replaces a project's employee list, keeping each user's
  /// `assignedProjectIds` in step so both sides of the link stay true.
  Future<Result<void>> setAssignedEmployees({
    required String projectId,
    required List<String> employeeIds,
  });
}
