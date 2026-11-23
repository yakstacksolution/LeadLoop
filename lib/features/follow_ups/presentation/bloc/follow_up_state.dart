part of 'follow_up_cubit.dart';

enum FollowUpStatus { initial, loading, success, failure }

class FollowUpState extends Equatable {
  const FollowUpState({
    this.status = FollowUpStatus.initial,
    this.groups = const FollowUpGroups(),
    this.failure,
  });

  final FollowUpStatus status;
  final FollowUpGroups groups;
  final Failure? failure;

  bool get isLoading =>
      status == FollowUpStatus.loading || status == FollowUpStatus.initial;

  bool get isEmpty => status == FollowUpStatus.success && groups.isEmpty;

  FollowUpState copyWith({
    FollowUpStatus? status,
    FollowUpGroups? groups,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return FollowUpState(
      status: status ?? this.status,
      groups: groups ?? this.groups,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, groups, failure];
}
