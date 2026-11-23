import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../activities/domain/entities/activity.dart';
import '../../../activities/domain/repositories/activity_repository.dart';
import '../../domain/entities/follow_up_groups.dart';

part 'follow_up_state.dart';

/// Streams one person's (or one project's) open activities and keeps them
/// bucketed into overdue / today / upcoming.
class FollowUpCubit extends Cubit<FollowUpState> {
  FollowUpCubit({
    required this.repository,
    this.employeeId,
    this.projectId,
  }) : super(const FollowUpState());

  final ActivityRepository repository;
  final String? employeeId;
  final String? projectId;

  StreamSubscription<List<Activity>>? _subscription;

  void watch() {
    _subscription?.cancel();
    emit(state.copyWith(status: FollowUpStatus.loading, clearFailure: true));

    final stream = projectId != null
        ? repository.watchOpenForProject(projectId!)
        : repository.watchOpenForEmployee(employeeId ?? '');

    _subscription = stream.listen(
      (activities) => emit(state.copyWith(
        status: FollowUpStatus.success,
        groups: FollowUpGroups.from(activities),
        clearFailure: true,
      )),
      onError: (Object error) => emit(state.copyWith(
        status: FollowUpStatus.failure,
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
