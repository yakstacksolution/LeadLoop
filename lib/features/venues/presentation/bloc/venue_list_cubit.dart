import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/venue.dart';
import '../../domain/entities/venue_filter.dart';
import '../../domain/repositories/venue_repository.dart';

part 'venue_list_state.dart';

/// Paginated, filterable venue list.
///
/// Filtering resets the pagination cursor, because a page boundary from the
/// previous filter means nothing under the new one.
class VenueListCubit extends Cubit<VenueListState> {
  VenueListCubit({required this.repository, VenueFilter initialFilter = const VenueFilter()})
      : super(VenueListState(filter: initialFilter));

  final VenueRepository repository;

  /// Bumped by every [_fetch]. A response from an older one is dropped, so a
  /// slow search can never overwrite the results of a newer one.
  int _generation = 0;

  Future<void> load() => _fetch(filter: state.filter);

  Future<void> applyFilter(VenueFilter filter) => _fetch(filter: filter);

  Future<void> search(String term) =>
      applyFilter(state.filter.copyWith(searchTerm: term));

  /// Re-fetches as many venues as are already loaded, so the reader keeps
  /// their place in the list.
  Future<void> refresh() =>
      _fetch(filter: state.filter, limit: state.venues.length);

  /// The current venues stay on screen until the new ones arrive.
  Future<void> _fetch({required VenueFilter filter, int limit = 0}) async {
    final generation = ++_generation;
    final filterChanged = filter != state.filter;

    emit(state.copyWith(
      status: VenueListStatus.loading,
      filter: filter,
      isLoadingMore: false,
      clearFailure: true,
    ));

    final result = await repository.fetchVenues(
      filter: filter,
      limit: max(limit, AppLimits.pageSize),
    );
    if (isClosed || generation != _generation) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: VenueListStatus.failure,
        failure: failure,
        // Results for another filter would be misleading under this one.
        venues: filterChanged ? const [] : null,
        clearCursor: filterChanged,
      )),
      (page) => emit(state.copyWith(
        status: VenueListStatus.success,
        venues: page.venues,
        cursor: page.cursor,
        hasMore: page.hasMore,
        clearFailure: true,
      )),
    );
  }

  Future<void> loadMore() async {
    if (state.isLoading ||
        !state.hasMore ||
        state.isLoadingMore ||
        state.cursor == null) {
      return;
    }

    final generation = _generation;
    emit(state.copyWith(isLoadingMore: true));

    final result = await repository.fetchVenues(
      filter: state.filter,
      cursor: state.cursor,
      limit: AppLimits.pageSize,
    );
    if (isClosed || generation != _generation) return;

    result.fold(
      (failure) => emit(state.copyWith(isLoadingMore: false, failure: failure)),
      (page) => emit(state.copyWith(
        venues: [...state.venues, ...page.venues],
        cursor: page.cursor,
        hasMore: page.hasMore,
        isLoadingMore: false,
        clearFailure: true,
      )),
    );
  }

  /// Re-reads one venue and updates it where it sits.
  ///
  /// Called after returning from the detail screen, where the status, the
  /// follow-up date or the assignee may have changed. A single read beats a
  /// full [refresh], which would throw away every page loaded so far and
  /// leave the reader somewhere else in the list.
  Future<void> refreshVenue(String venueId) async {
    if (!state.venues.any((venue) => venue.id == venueId)) return;

    final result = await repository.getVenue(venueId);
    if (isClosed) return;

    // Looked up after the read: the list may have changed meanwhile.
    final index = state.venues.indexWhere((venue) => venue.id == venueId);
    if (index < 0) return;

    final venues = [...state.venues];

    result.fold(
      // Gone, or no longer readable by this user — either way it does not
      // belong on screen.
      (_) => venues.removeAt(index),
      (venue) {
        // A venue that no longer matches the filter drops out rather than
        // sitting there contradicting the filter chip above it.
        if (state.filter.matches(venue)) {
          venues[index] = venue;
        } else {
          venues.removeAt(index);
        }
      },
    );

    emit(state.copyWith(venues: venues));
  }
}
