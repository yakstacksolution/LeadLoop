import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_lead/core/errors/failures.dart';
import 'package:futsal_lead/core/errors/result.dart';
import 'package:futsal_lead/features/venues/domain/entities/venue.dart';
import 'package:futsal_lead/features/venues/domain/entities/venue_filter.dart';
import 'package:futsal_lead/features/venues/domain/repositories/venue_repository.dart';
import 'package:futsal_lead/features/venues/presentation/bloc/venue_list_cubit.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements VenueRepository {}

class _FakeVenue extends Fake implements Venue {}

void main() {
  setUpAll(() => registerFallbackValue(const VenueFilter()));

  late _MockRepository repository;
  late VenueListCubit cubit;
  late List<Completer<Result<VenuePage>>> requests;

  setUp(() {
    repository = _MockRepository();
    requests = [];
    when(
      () => repository.fetchVenues(
        filter: any(named: 'filter'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) {
      requests.add(Completer());
      return requests.last.future;
    });
    cubit = VenueListCubit(repository: repository);
  });

  VenuePage page(Venue venue) => VenuePage(venues: [venue], cursor: null, hasMore: false);

  test('refresh keeps the current venues on screen', () async {
    final venue = _FakeVenue();
    final load = cubit.load();
    requests[0].complete(Success(page(venue)));
    await load;

    final refresh = cubit.refresh();
    expect(cubit.state.isLoading, isTrue);
    expect(cubit.state.venues, [venue]);
    requests[1].complete(const FailureResult(NotFoundFailure()));
    await refresh;

    expect(cubit.state.venues, [venue]);
    expect(cubit.state.failure, isNotNull);
  });

  test('a slow earlier search cannot overwrite a newer one', () async {
    final stale = _FakeVenue();
    final fresh = _FakeVenue();
    final first = cubit.search('a');
    final second = cubit.search('ab');
    requests[1].complete(Success(page(fresh)));
    await second;
    requests[0].complete(Success(page(stale)));
    await first;

    expect(cubit.state.venues, [fresh]);
  });

  test('a response after close is ignored', () async {
    final load = cubit.load();
    await cubit.close();
    requests[0].complete(Success(page(_FakeVenue())));
    await load;
  });
}
