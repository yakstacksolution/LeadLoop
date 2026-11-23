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
import '../../../../core/errors/error_mapper.dart';
import '../../../activities/domain/entities/activity.dart';
import '../../../activities/domain/repositories/activity_repository.dart';
import '../../../activities/presentation/widgets/activity_card.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../employees/domain/repositories/employee_repository.dart';
import '../../../projects/domain/repositories/project_repository.dart';
import '../../../venues/domain/repositories/venue_repository.dart';
import '../../../visits/domain/repositories/visit_repository.dart';
import '../bloc/dashboard_cubit.dart';
import '../widgets/lead_status_breakdown.dart';
import '../widgets/overview_widgets.dart';
import '../widgets/stat_card.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DashboardCubit(
        venueRepository: sl<VenueRepository>(),
        activityRepository: sl<ActivityRepository>(),
        visitRepository: sl<VisitRepository>(),
        projectRepository: sl<ProjectRepository>(),
        employeeRepository: sl<EmployeeRepository>(),
      )..load(),
      child: const _AdminDashboardView(),
    );
  }
}

class _AdminDashboardView extends StatelessWidget {
  const _AdminDashboardView();

  /// Beyond this the page stops stretching: 8-word-wide stat labels and
  /// full-bleed bars are unreadable on a desktop monitor.
  static const _maxContentWidth = 1040.0;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit cubit) => cubit.state.user);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context.read<DashboardCubit>().refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.push(AppRoutes.profile),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocConsumer<DashboardCubit, DashboardState>(
        // A failed refresh keeps the figures on screen and says so.
        listenWhen: (_, state) =>
            state.hasLoaded && state.status == DashboardStatus.failure,
        listener: (context, state) => context.showError(state.failure!),
        builder: (context, state) {
          if (state.isLoading) return const OverviewSkeleton();

          if (state.failure != null && !state.hasLoaded) {
            return ErrorView(
              failure: state.failure!,
              onRetry: () => context.read<DashboardCubit>().refresh(),
            );
          }

          final stats = state.stats;
          final needsAttention =
              stats.overdueFollowUps > 0 || stats.todaysActivities > 0;

          return FadeIn(
            child: RefreshIndicator(
              onRefresh: () => context.read<DashboardCubit>().refresh(),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      OverviewHeader(stats: stats, name: user?.fullName),
                      if (needsAttention) ...[
                        const SizedBox(height: 12),
                        AttentionBanner(
                          overdue: stats.overdueFollowUps,
                          dueToday: stats.todaysActivities,
                          onTap: () => context.go(AppRoutes.adminActivities),
                        ),
                      ],
                      const SizedBox(height: 22),
                      const SectionHeading(title: 'Quick actions'),
                      ActionTileGrid(
                        actions: [
                          AppAction(
                            label: 'Add employee',
                            icon: Icons.person_add_alt_outlined,
                            onTap: () => context.push(AppRoutes.createEmployee),
                          ),
                          AppAction(
                            label: 'New project',
                            icon: Icons.create_new_folder_outlined,
                            color: AppColors.secondary,
                            onTap: () => context.push(AppRoutes.createProject),
                          ),
                          AppAction(
                            label: 'All venues',
                            icon: Icons.stadium_outlined,
                            color: AppColors.info,
                            onTap: () => context.go(AppRoutes.adminVenues),
                          ),
                          AppAction(
                            label: 'Reports',
                            icon: Icons.insights_outlined,
                            color: AppColors.warning,
                            onTap: () => context.go(AppRoutes.reports),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const SectionHeading(title: 'Follow-ups'),
                      StatGrid(
                        children: [
                          StatCard(
                            label: 'Overdue',
                            value: '${stats.overdueFollowUps}',
                            icon: Icons.warning_amber_rounded,
                            color: AppColors.danger,
                            emphasis: stats.overdueFollowUps > 0,
                            onTap: () => context.go(AppRoutes.adminActivities),
                          ),
                          StatCard(
                            label: 'Due today',
                            value: '${stats.todaysActivities}',
                            icon: Icons.today_outlined,
                            color: AppColors.info,
                            onTap: () => context.go(AppRoutes.adminActivities),
                          ),
                          StatCard(
                            label: 'Pending',
                            value: '${stats.pendingFollowUps}',
                            icon: Icons.schedule_outlined,
                            color: AppColors.warning,
                            onTap: () => context.go(AppRoutes.adminActivities),
                          ),
                          StatCard(
                            label: 'Visits completed',
                            value: '${stats.visitsCompleted}',
                            icon: Icons.where_to_vote_outlined,
                            color: AppColors.secondary,
                            onTap: () => context.go(AppRoutes.adminVisits),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const SectionHeading(title: 'Organisation'),
                      StatGrid(
                        children: [
                          StatCard(
                            label: 'Total venues',
                            value: '${stats.totalVenues}',
                            icon: Icons.stadium_outlined,
                            onTap: () => context.go(AppRoutes.adminVenues),
                          ),
                          StatCard(
                            label: 'Active employees',
                            value: '${stats.activeEmployees}',
                            icon: Icons.groups_outlined,
                            color: AppColors.secondary,
                            onTap: () => context.go(AppRoutes.employees),
                          ),
                          StatCard(
                            label: 'Active projects',
                            value:
                                '${stats.activeProjects} / ${stats.totalProjects}',
                            icon: Icons.folder_outlined,
                            color: AppColors.info,
                            onTap: () => context.go(AppRoutes.projects),
                          ),
                          StatCard(
                            label: 'Converted',
                            value: '${stats.converted}',
                            icon: Icons.verified_outlined,
                            color: AppColors.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const SectionHeading(title: 'Pipeline'),
                      SectionCard(
                        title: 'Lead status distribution',
                        action: Text(
                          '${stats.totalVenues} venues',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        child: LeadStatusBreakdown(
                          stats: stats,
                          onStatusTap: (_) => context.go(AppRoutes.adminVenues),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const SectionHeading(title: 'Team'),
                      const _TeamFollowUps(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The soonest open activities across the whole organisation — the admin's
/// main "who needs chasing" signal.
class _TeamFollowUps extends StatefulWidget {
  const _TeamFollowUps();

  @override
  State<_TeamFollowUps> createState() => _TeamFollowUpsState();
}

class _TeamFollowUpsState extends State<_TeamFollowUps> {
  /// Subscribed once for the life of the dashboard. Building it inline would
  /// reopen the listener on every dashboard rebuild.
  late final Stream<List<Activity>> _openActivities = sl<ActivityRepository>()
      .watchOpenOrgWide(limit: 6);

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Needs attention across the team',
      action: TextButton(
        onPressed: () => context.go(AppRoutes.adminActivities),
        child: const Text('See all'),
      ),
      child: StreamBuilder<List<Activity>>(
        stream: _openActivities,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(failure: mapError(snapshot.error!));
          }
          if (!snapshot.hasData) {
            return const SizedBox(height: 90, child: LoadingView());
          }

          final activities = snapshot.data!;
          if (activities.isEmpty) {
            return const EmptyView(
              icon: Icons.check_circle_outline,
              title: 'Nothing outstanding',
              message: 'Scheduled calls, meetings and visits will appear here.',
            );
          }

          return Column(
            children: [
              for (final activity in activities)
                ActivityCard(
                  activity: activity,
                  onTap: () =>
                      context.push(AppRoutes.activityDetailFor(activity.id)),
                ),
            ],
          );
        },
      ),
    );
  }
}
