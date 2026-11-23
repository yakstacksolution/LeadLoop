import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../activities/domain/entities/activity.dart';
import '../../../activities/domain/repositories/activity_repository.dart';
import '../../../activities/presentation/widgets/activity_card.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../bloc/follow_up_cubit.dart';

/// "My next follow-ups": everything still open, split into overdue, today and
/// upcoming.
///
/// The ordering within each bucket is strictly by scheduled time. Nothing here
/// invents a priority order the employee did not set.
class FollowUpsPage extends StatelessWidget {
  const FollowUpsPage({super.key, this.orgWide = false});

  /// Admins see the whole organisation's open work rather than their own.
  final bool orgWide;

  @override
  Widget build(BuildContext context) {
    final uid = context.select((AuthCubit cubit) => cubit.state.uid);

    if (orgWide) return const _OrgWideFollowUps();

    return BlocProvider(
      create: (_) => FollowUpCubit(
        repository: sl<ActivityRepository>(),
        employeeId: uid,
      )..watch(),
      child: const _FollowUpsView(title: 'My follow-ups'),
    );
  }
}

class _FollowUpsView extends StatefulWidget {
  const _FollowUpsView({required this.title});

  final String title;

  @override
  State<_FollowUpsView> createState() => _FollowUpsViewState();
}

class _FollowUpsViewState extends State<_FollowUpsView>
    with SingleTickerProviderStateMixin {
  // Not DefaultTabController: its scope notifies TabBarView when tickers are
  // muted (e.g. a route covers this page), and TabBarView then jumps pages
  // mid-build, causing "markNeedsBuild() called during build".
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        // Wrapped in PreferredSize because AppBar.bottom needs an intrinsic
        // height that a BlocBuilder cannot report on its own.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: BlocBuilder<FollowUpCubit, FollowUpState>(
            builder: (context, state) {
              final groups = state.groups;
              return TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: 'Overdue (${groups.overdue.length})'),
                  Tab(text: 'Today (${groups.today.length})'),
                  Tab(text: 'Upcoming (${groups.upcoming.length})'),
                ],
              );
            },
          ),
        ),
      ),
      body: BlocBuilder<FollowUpCubit, FollowUpState>(
        builder: (context, state) {
          if (state.isLoading) return const SkeletonList();

          if (state.failure != null) {
            return ErrorView(
              failure: state.failure!,
              onRetry: () => context.read<FollowUpCubit>().watch(),
            );
          }

          final groups = state.groups;

          return TabBarView(
            controller: _tabController,
            children: [
              _FollowUpList(
                activities: groups.overdue,
                emptyTitle: 'Nothing overdue',
                emptyMessage: 'You are on top of your follow-ups.',
                emptyIcon: Icons.check_circle_outline,
              ),
              _FollowUpList(
                activities: groups.today,
                emptyTitle: 'Nothing left today',
                emptyMessage: 'Anything scheduled for later today appears here.',
                emptyIcon: Icons.today_outlined,
              ),
              _FollowUpList(
                activities: groups.upcoming,
                emptyTitle: 'Nothing scheduled',
                emptyMessage:
                    'Schedule a call, meeting or visit from any venue screen.',
                emptyIcon: Icons.event_outlined,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FollowUpList extends StatelessWidget {
  const _FollowUpList({
    required this.activities,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  final List<Activity> activities;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return EmptyView(icon: emptyIcon, title: emptyTitle, message: emptyMessage);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return ActivityCard(
          activity: activity,
          onTap: () => context.push(AppRoutes.activityDetailFor(activity.id)),
          trailing: IconButton(
            icon: const Icon(Icons.stadium_outlined, size: 19),
            tooltip: 'Open venue',
            color: AppColors.textMuted,
            onPressed: () => context.push(AppRoutes.venueDetailFor(activity.venueId)),
          ),
        );
      },
    );
  }
}

/// The admin variant: every employee's open activities in one feed.
class _OrgWideFollowUps extends StatefulWidget {
  const _OrgWideFollowUps();

  @override
  State<_OrgWideFollowUps> createState() => _OrgWideFollowUpsState();
}

class _OrgWideFollowUpsState extends State<_OrgWideFollowUps> {
  late final Stream<List<Activity>> _activities =
      sl<ActivityRepository>().watchOpenOrgWide(limit: 100);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All activities')),
      body: StreamBuilder<List<Activity>>(
        stream: _activities,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ErrorView(
              failure: PermissionFailure(
                'Could not load activities. You may not have permission.',
              ),
            );
          }
          if (!snapshot.hasData) return const SkeletonList();

          final activities = snapshot.data!;
          if (activities.isEmpty) {
            return const EmptyView(
              icon: Icons.event_available_outlined,
              title: 'Nothing outstanding',
              message: 'Open calls, meetings and visits across the team appear here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return ActivityCard(
                activity: activity,
                onTap: () => context.push(AppRoutes.activityDetailFor(activity.id)),
              );
            },
          );
        },
      ),
    );
  }
}
