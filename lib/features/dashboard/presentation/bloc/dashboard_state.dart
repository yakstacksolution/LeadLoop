part of 'dashboard_cubit.dart';

enum DashboardStatus { initial, loading, success, failure }

class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.stats = const DashboardStats(),
    this.failure,
    this.hasLoaded = false,
  });

  final DashboardStatus status;
  final DashboardStats stats;
  final Failure? failure;

  /// True once any load has succeeded. From then on a refresh keeps the
  /// figures on screen.
  final bool hasLoaded;

  /// The first load only.
  bool get isLoading =>
      !hasLoaded &&
      (status == DashboardStatus.loading || status == DashboardStatus.initial);

  DashboardState copyWith({
    DashboardStatus? status,
    DashboardStats? stats,
    Failure? failure,
    bool? hasLoaded,
    bool clearFailure = false,
  }) {
    return DashboardState(
      status: status ?? this.status,
      stats: stats ?? this.stats,
      failure: clearFailure ? null : (failure ?? this.failure),
      hasLoaded: hasLoaded ?? this.hasLoaded,
    );
  }

  @override
  List<Object?> get props => [status, stats, failure, hasLoaded];
}
