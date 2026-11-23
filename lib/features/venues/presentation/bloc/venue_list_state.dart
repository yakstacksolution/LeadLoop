part of 'venue_list_cubit.dart';

enum VenueListStatus { initial, loading, success, failure }

class VenueListState extends Equatable {
  const VenueListState({
    this.status = VenueListStatus.initial,
    this.venues = const [],
    this.filter = const VenueFilter(),
    this.cursor,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.failure,
  });

  final VenueListStatus status;
  final List<Venue> venues;
  final VenueFilter filter;

  /// Opaque paging cursor handed back to the repository.
  final Object? cursor;
  final bool hasMore;
  final bool isLoadingMore;
  final Failure? failure;

  bool get isLoading =>
      status == VenueListStatus.loading || status == VenueListStatus.initial;

  bool get isEmpty => status == VenueListStatus.success && venues.isEmpty;

  VenueListState copyWith({
    VenueListStatus? status,
    List<Venue>? venues,
    VenueFilter? filter,
    Object? cursor,
    bool? hasMore,
    bool? isLoadingMore,
    Failure? failure,
    bool clearFailure = false,
    bool clearCursor = false,
  }) {
    return VenueListState(
      status: status ?? this.status,
      venues: venues ?? this.venues,
      filter: filter ?? this.filter,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      hasMore: clearCursor ? false : (hasMore ?? this.hasMore),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
        status,
        venues,
        filter,
        cursor,
        hasMore,
        isLoadingMore,
        failure,
      ];
}
