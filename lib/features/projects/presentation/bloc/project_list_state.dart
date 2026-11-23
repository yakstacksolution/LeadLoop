part of 'project_list_cubit.dart';

enum ProjectListStatus { initial, loading, success, failure }

class ProjectListState extends Equatable {
  const ProjectListState({
    this.status = ProjectListStatus.initial,
    this.projects = const [],
    this.failure,
  });

  final ProjectListStatus status;
  final List<Project> projects;
  final Failure? failure;

  bool get isLoading =>
      status == ProjectListStatus.loading || status == ProjectListStatus.initial;

  bool get isEmpty => status == ProjectListStatus.success && projects.isEmpty;

  ProjectListState copyWith({
    ProjectListStatus? status,
    List<Project>? projects,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ProjectListState(
      status: status ?? this.status,
      projects: projects ?? this.projects,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, projects, failure];
}
