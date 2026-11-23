import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/entities/venue_filter.dart';
import '../../domain/repositories/venue_repository.dart';
import '../bloc/venue_list_cubit.dart';
import '../widgets/venue_card.dart';
import '../widgets/venue_filter_sheet.dart';
import '../../../../shared/widgets/app_fab.dart';
import '../../../../shared/widgets/app_shell.dart';

/// The venue list, used for both "My venues" and the admin's "All venues".
///
/// The only difference is the initial filter: employees are scoped to their
/// own uid, admins to everything. The security rules enforce the same split
/// server-side, so a tampered client gains nothing.
class VenueListPage extends StatelessWidget {
  const VenueListPage({super.key, this.scopeToCurrentUser = true, this.title});

  final bool scopeToCurrentUser;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final uid = context.select((AuthCubit cubit) => cubit.state.uid);

    // An employee-scoped list without a uid would query every venue in the
    // org, which the security rules refuse — it would surface as a permission
    // error rather than an empty list. Wait for the session instead.
    if (scopeToCurrentUser && (uid == null || uid.isEmpty)) {
      return const Scaffold(body: LoadingView());
    }

    return BlocProvider(
      create: (_) => VenueListCubit(
        repository: sl<VenueRepository>(),
        initialFilter: VenueFilter(
          assignedEmployeeId: scopeToCurrentUser ? uid : null,
        ),
      )..load(),
      child: _VenueListView(
        title: title ?? (scopeToCurrentUser ? 'My venues' : 'All venues'),
        scopedToSelf: scopeToCurrentUser,
      ),
    );
  }
}

class _VenueListView extends StatefulWidget {
  const _VenueListView({required this.title, required this.scopedToSelf});

  final String title;

  /// True for "My venues" — an empty list there means nothing is assigned to
  /// you, which is a different problem from an empty database.
  final bool scopedToSelf;

  @override
  State<_VenueListView> createState() => _VenueListViewState();
}

class _VenueListViewState extends State<_VenueListView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  /// Search re-runs the Firestore query, so it waits for a pause in typing
  /// rather than firing on every character.
  Timer? _searchDebounce;
  static const _searchDelay = Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDelay, () {
      if (mounted) context.read<VenueListCubit>().search(value);
    });
  }

  /// Fetches the next page a little before the list actually runs out, so
  /// scrolling stays smooth instead of stalling at the bottom.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      context.read<VenueListCubit>().loadMore();
    }
  }

  Future<void> _openFilters() async {
    final cubit = context.read<VenueListCubit>();
    final updated = await showVenueFilterSheet(
      context,
      current: cubit.state.filter,
    );
    if (updated != null) await cubit.applyFilter(updated);
  }

  @override
  Widget build(BuildContext context) {
    return BranchRefresh(
      // Coming back to this tab should show what is in Firestore now, not the
      // page that was fetched the first time it was opened.
      onReturn: () => context.read<VenueListCubit>().refresh(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            // Ahead of the filter: the list is a one-shot query rather than a
            // live stream, so re-fetching is the more common of the two.
            BlocBuilder<VenueListCubit, VenueListState>(
              buildWhen: (a, b) => a.isLoading != b.isLoading,
              builder: (context, state) => IconButton(
                tooltip: 'Refresh',
                onPressed: state.isLoading
                    ? null
                    : () => context.read<VenueListCubit>().refresh(),
                icon: state.isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ),
            BlocBuilder<VenueListCubit, VenueListState>(
              buildWhen: (a, b) => a.filter != b.filter,
              builder: (context, state) {
                final active =
                    state.filter.status != null ||
                    state.filter.priority != null ||
                    (state.filter.area?.isNotEmpty ?? false) ||
                    state.filter.includeArchived ||
                    state.filter.sort != VenueSort.lastActivity;

                return IconButton(
                  tooltip: 'Filter',
                  onPressed: _openFilters,
                  icon: Badge(
                    isLabelVisible: active,
                    smallSize: 8,
                    child: const Icon(Icons.filter_list),
                  ),
                );
              },
            ),
          ],
        ),
        floatingActionButton: AppFab(
          heroTag: 'fab-venue-list',
          icon: Icons.add,
          label: 'Add venue',
          onPressed: () => context.push(AppRoutes.createVenue),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: SearchBar(
                controller: _searchController,
                hintText: 'Search name, address or area',
                leading: const Icon(Icons.search, size: 20),
                elevation: const WidgetStatePropertyAll(0),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: AppColors.outline),
                ),
                backgroundColor: const WidgetStatePropertyAll(
                  AppColors.surface,
                ),
                onChanged: _onSearchChanged,
                trailing: [
                  ListenableBuilder(
                    listenable: _searchController,
                    builder: (context, _) => _searchController.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchDebounce?.cancel();
                              _searchController.clear();
                              context.read<VenueListCubit>().search('');
                            },
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocConsumer<VenueListCubit, VenueListState>(
                listenWhen: (previous, state) =>
                    state.failure != null &&
                    state.failure != previous.failure &&
                    state.venues.isNotEmpty,
                listener: (context, state) => context.showError(state.failure!),
                builder: (context, state) {
                  if (state.isLoading && state.venues.isEmpty) {
                    return const SkeletonList(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    );
                  }

                  if (state.failure != null && state.venues.isEmpty) {
                    return ErrorView(
                      failure: state.failure!,
                      onRetry: () => context.read<VenueListCubit>().refresh(),
                    );
                  }

                  if (state.isEmpty) {
                    final filtered =
                        state.filter.hasClientFilters ||
                        state.filter.status != null;

                    if (filtered) {
                      return EmptyView(
                        icon: Icons.stadium_outlined,
                        title: 'No venues match',
                        message:
                            'Try clearing the filters or searching for '
                            'something else.',
                        actionLabel: 'Clear filters',
                        onAction: () {
                          _searchDebounce?.cancel();
                          _searchController.clear();
                          context.read<VenueListCubit>().applyFilter(
                            VenueFilter(
                              assignedEmployeeId:
                                  state.filter.assignedEmployeeId,
                            ),
                          );
                        },
                      );
                    }

                    return EmptyView(
                      icon: Icons.stadium_outlined,
                      title: widget.scopedToSelf
                          ? 'No venues assigned to you'
                          : 'No venues yet',
                      message: widget.scopedToSelf
                          ? 'You only see venues assigned to you. Add one '
                                'yourself, or ask your administrator to assign you '
                                'some existing venues.'
                          : 'Add your first venue to start tracking it.',
                      actionLabel: 'Add venue',
                      onAction: () => context.push(AppRoutes.createVenue),
                    );
                  }

                  return FadeIn(
                    child: RefreshIndicator(
                      onRefresh: () => context.read<VenueListCubit>().refresh(),
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                        itemCount:
                            state.venues.length + (state.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= state.venues.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                ),
                              ),
                            );
                          }

                          final venue = state.venues[index];
                          return VenueCard(
                            key: ValueKey(venue.id),
                            venue: venue,
                            onTap: () async {
                              await context.push(
                                AppRoutes.venueDetailFor(venue.id),
                              );
                              // The status, the next follow-up or the assignee
                              // may have changed while that screen was open.
                              if (!context.mounted) return;
                              context.read<VenueListCubit>().refreshVenue(
                                venue.id,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
