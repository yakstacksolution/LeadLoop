import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/action_tiles.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../activities/domain/repositories/activity_repository.dart';
import '../../../activities/presentation/widgets/activity_card.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../employees/domain/repositories/employee_repository.dart';
import '../../../follow_ups/presentation/bloc/follow_up_cubit.dart';
import '../../../projects/domain/repositories/project_repository.dart';
import '../../../venues/domain/repositories/venue_repository.dart';
import '../../../visits/domain/repositories/visit_repository.dart';
import '../bloc/dashboard_cubit.dart';
import '../widgets/stat_card.dart';

class EmployeeDashboardPage extends StatelessWidget {
  const EmployeeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.select((AuthCubit cubit) => cubit.state.uid) ?? '';

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => DashboardCubit(
            venueRepository: sl<VenueRepository>(),
            activityRepository: sl<ActivityRepository>(),
            visitRepository: sl<VisitRepository>(),
            projectRepository: sl<ProjectRepository>(),
            employeeRepository: sl<EmployeeRepository>(),
            employeeId: uid,
          )..load(),
        ),
        BlocProvider(
          create: (_) => FollowUpCubit(
            repository: sl<ActivityRepository>(),
            employeeId: uid,
          )..watch(),
        ),
      ],
      child: const _EmployeeDashboardView(),
    );
  }
}

class _EmployeeDashboardView extends StatelessWidget {
  const _EmployeeDashboardView();

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit cubit) => cubit.state.user);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My dashboard'),
            if (user != null)
              Text(
                user.fullName,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.push(AppRoutes.profile),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<DashboardCubit>().refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: const [
            _QuickActions(),
            SizedBox(height: 18),
            _MyNumbers(),
            SizedBox(height: 18),
            _NextUp(),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return ActionTileGrid(
      actions: [
        AppAction(
          label: 'Add venue',
          icon: Icons.add_business_outlined,
          onTap: () => context.push(AppRoutes.createVenue),
        ),
        AppAction(
          label: 'My venues',
          icon: Icons.stadium_outlined,
          color: AppColors.secondary,
          onTap: () => context.go(AppRoutes.myVenues),
        ),
        AppAction(
          label: 'Follow-ups',
          icon: Icons.event_repeat_outlined,
          color: AppColors.info,
          onTap: () => context.go(AppRoutes.followUps),
        ),
        AppAction(
          label: 'My projects',
          icon: Icons.folder_outlined,
          color: AppColors.warning,
          onTap: () => context.go(AppRoutes.myProjects),
        ),
      ],
    );
  }
}

class _MyNumbers extends StatelessWidget {
  const _MyNumbers();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DashboardCubit, DashboardState>(
      // A failed refresh keeps the figures on screen and says so.
      listenWhen: (_, state) =>
          state.hasLoaded && state.status == DashboardStatus.failure,
      listener: (context, state) => context.showError(state.failure!),
      builder: (context, state) {
        if (state.isLoading) return const _NumbersSkeleton();
        if (state.failure != null && !state.hasLoaded) {
          return SectionCard(
            child: ErrorView(
              failure: state.failure!,
              onRetry: () => context.read<DashboardCubit>().refresh(),
            ),
          );
        }

        final stats = state.stats;

        return FadeIn(
          child: StatGrid(
            children: [
              StatCard(
                label: 'My venues',
                value: '${stats.totalVenues}',
                icon: Icons.stadium_outlined,
                onTap: () => context.go(AppRoutes.myVenues),
              ),
              StatCard(
                label: 'Due today',
                value: '${stats.todaysActivities}',
                icon: Icons.today_outlined,
                color: AppColors.info,
                onTap: () => context.go(AppRoutes.followUps),
              ),
              StatCard(
                label: 'Overdue follow-ups',
                value: '${stats.overdueFollowUps}',
                icon: Icons.warning_amber_rounded,
                color: AppColors.danger,
                emphasis: stats.overdueFollowUps > 0,
                onTap: () => context.go(AppRoutes.followUps),
              ),
              StatCard(
                label: 'Visits completed',
                value: '${stats.visitsCompleted}',
                icon: Icons.where_to_vote_outlined,
                color: AppColors.secondary,
              ),
              StatCard(
                label: 'New leads',
                value: '${stats.newLeads}',
                icon: Icons.fiber_new_outlined,
                color: AppColors.neutral,
              ),
              StatCard(
                label: 'Interested',
                value: '${stats.interested}',
                icon: Icons.thumb_up_outlined,
                color: AppColors.secondary,
              ),
              StatCard(
                label: 'Converted',
                value: '${stats.converted}',
                icon: Icons.verified_outlined,
                color: AppColors.success,
              ),
              StatCard(
                label: 'Pending follow-ups',
                value: '${stats.pendingFollowUps}',
                icon: Icons.schedule_outlined,
                color: AppColors.warning,
                onTap: () => context.go(AppRoutes.followUps),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NumbersSkeleton extends StatelessWidget {
  const _NumbersSkeleton();

  @override
  Widget build(BuildContext context) {
    return StatGrid(
      children: [for (var i = 0; i < 8; i++) const SkeletonBlock(height: 106)],
    );
  }
}

class _NextUp extends StatelessWidget {
  const _NextUp();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FollowUpCubit, FollowUpState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const SectionCard(
            title: 'Next up',
            child: SizedBox(height: 90, child: LoadingView()),
          );
        }
        if (state.failure != null) {
          return SectionCard(
            title: 'Next up',
            child: ErrorView(
              failure: state.failure!,
              onRetry: () => context.read<FollowUpCubit>().watch(),
            ),
          );
        }

        final groups = state.groups;
        // Deliberately the actual soonest commitments rather than a guess at
        // what the employee "should" do next.
        final items = [...groups.overdue, ...groups.today].take(4).toList();

        return SectionCard(
          title: 'Next up',
          action: TextButton(
            onPressed: () => context.go(AppRoutes.followUps),
            child: const Text('See all'),
          ),
          child: items.isEmpty
              ? const EmptyView(
                  icon: Icons.check_circle_outline,
                  title: 'Nothing due right now',
                  message:
                      'Scheduled calls, meetings and visits will appear here.',
                )
              : Column(
                  children: [
                    for (final activity in items)
                      ActivityCard(
                        activity: activity,
                        onTap: () => context.push(
                          AppRoutes.activityDetailFor(activity.id),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
