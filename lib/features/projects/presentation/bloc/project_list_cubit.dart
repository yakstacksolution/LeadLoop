import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';

part 'project_list_state.dart';

/// Streams the project list.
///
/// Pass [employeeId] to scope it to one person's assignments; leave it null
/// for the admin's full list.
class ProjectListCubit extends Cubit<ProjectListState> {
  ProjectListCubit({required this.repository, this.employeeId})
      : super(const ProjectListState());

  final ProjectRepository repository;
  final String? employeeId;

  StreamSubscription<List<Project>>? _subscription;

  void watch({List<ProjectStatus> statuses = const []}) {
    _subscription?.cancel();
    emit(state.copyWith(status: ProjectListStatus.loading, clearFailure: true));

    final stream = employeeId != null
        ? repository.watchProjectsForEmployee(employeeId!)
        : repository.watchAllProjects(statuses: statuses);

    _subscription = stream.listen(
      (projects) => emit(state.copyWith(
        status: ProjectListStatus.success,
        projects: projects,
        clearFailure: true,
      )),
      onError: (Object error) => emit(state.copyWith(
        status: ProjectListStatus.failure,
        failure: mapError(error),
      )),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
