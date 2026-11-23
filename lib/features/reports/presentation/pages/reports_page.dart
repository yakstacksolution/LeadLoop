import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../activities/domain/repositories/activity_repository.dart';
import '../../../dashboard/presentation/bloc/dashboard_cubit.dart';
import '../../../dashboard/presentation/widgets/lead_status_breakdown.dart';
import '../../../dashboard/presentation/widgets/stat_card.dart';
import '../../../employees/domain/repositories/employee_repository.dart';
import '../../../projects/domain/repositories/project_repository.dart';
import '../../../venues/domain/repositories/venue_repository.dart';
import '../../../visits/domain/repositories/visit_repository.dart';
import '../widgets/report_charts.dart';

/// Organisation-wide reporting.
///
/// Everything here comes from server-side aggregation queries, so the page
/// costs a fixed handful of reads no matter how large the database gets.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

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
      child: const _ReportsView(),
    );
  }
}

class _ReportsView extends StatelessWidget {
  const _ReportsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context.read<DashboardCubit>().refresh(),
          ),
        ],
      ),
      body: BlocConsumer<DashboardCubit, DashboardState>(
        // A failed refresh keeps the figures on screen and says so.
        listenWhen: (_, state) =>
            state.hasLoaded && state.status == DashboardStatus.failure,
        listener: (context, state) => context.showError(state.failure!),
        builder: (context, state) {
          if (state.isLoading) return const SkeletonList();

          if (state.failure != null && !state.hasLoaded) {
            return ErrorView(
              failure: state.failure!,
              onRetry: () => context.read<DashboardCubit>().refresh(),
            );
          }

          final stats = state.stats;
          final rate = stats.conversionRate;

          return FadeIn(
            child: RefreshIndicator(
              onRefresh: () => context.read<DashboardCubit>().refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                children: [
                  StatGrid(
                    children: [
                      StatCard(
                        label: 'Total venues',
                        value: '${stats.totalVenues}',
                        icon: Icons.stadium_outlined,
                      ),
                      StatCard(
                        label: 'In pipeline',
                        value: '${stats.inPipeline}',
                        icon: Icons.timeline_outlined,
                        color: AppColors.info,
                      ),
                      StatCard(
                        label: 'Converted',
                        value: '${stats.converted}',
                        icon: Icons.verified_outlined,
                        color: AppColors.success,
                      ),
                      StatCard(
                        label: 'Conversion rate',
                        // An em dash rather than a misleading 0% when there is
                        // nothing to divide by.
                        value: rate == null
                            ? '—'
                            : '${rate.toStringAsFixed(1)}%',
                        icon: Icons.percent,
                        color: AppColors.secondary,
                      ),
                      StatCard(
                        label: 'Visits completed',
                        value: '${stats.visitsCompleted}',
                        icon: Icons.where_to_vote_outlined,
                        color: AppColors.secondary,
                      ),
                      StatCard(
                        label: 'Overdue follow-ups',
                        value: '${stats.overdueFollowUps}',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.danger,
                        emphasis: stats.overdueFollowUps > 0,
                      ),
                      StatCard(
                        label: 'Not interested',
                        value: '${stats.notInterested}',
                        icon: Icons.thumb_down_outlined,
                        color: AppColors.danger,
                      ),
                      StatCard(
                        label: 'Unresponsive',
                        value: '${stats.unresponsive}',
                        icon: Icons.phone_missed_outlined,
                        color: AppColors.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SectionCard(
                    title: 'Pipeline funnel',
                    child: PipelineFunnel(stats: stats),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Lead status share',
                    child: LeadStatusDoughnut(stats: stats),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Outcomes',
                    child: OutcomeChart(stats: stats),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Follow-up queue',
                    child: FollowUpChart(stats: stats),
                  ),
                  const SizedBox(height: 14),
                  const SectionCard(
                    title: 'Visits per month',
                    child: _VisitTrend(),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Lead status distribution',
                    child: LeadStatusBreakdown(stats: stats),
                  ),
                  const SizedBox(height: 18),
                  SectionCard(
                    title: 'Team',
                    child: Column(
                      children: [
                        DetailRow(
                          label: 'Active employees',
                          value: '${stats.activeEmployees}',
                          icon: Icons.groups_outlined,
                        ),
                        DetailRow(
                          label: 'Projects',
                          value:
                              '${stats.activeProjects} active of '
                              '${stats.totalProjects}',
                          icon: Icons.folder_outlined,
                        ),
                        DetailRow(
                          label: 'Scheduled activities',
                          value: '${stats.meetingsScheduled}',
                          icon: Icons.event_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const InlineMessage(
                    message:
                        'Figures come from server-side count queries and reflect '
                        'the moment this page was loaded. Pull down to refresh.',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Completed visits per month for the last six months.
///
/// Built from six `count()` aggregations — one cumulative total per month
/// boundary, differenced into per-month figures. Six aggregation reads, no
/// matter how many visits exist.
class _VisitTrend extends StatefulWidget {
  const _VisitTrend();

  @override
  State<_VisitTrend> createState() => _VisitTrendState();
}

class _VisitTrendState extends State<_VisitTrend> {
  late final Future<List<ChartDatum>> _series = _load();

  static const _months = 6;

  Future<List<ChartDatum>> _load() async {
    final now = DateTime.now();

    // Boundaries, newest first: the first of this month, of last month, and
    // so on.
    final boundaries = [
      for (var back = 0; back < _months; back++)
        DateTime(now.year, now.month - back, 1),
    ];

    final totals = await Future.wait([
      for (final since in boundaries)
        sl<VisitRepository>().countVisits(since: since),
    ]);

    // countVisits(since:) is cumulative, so each month is the difference
    // between its own total and the next-newer one.
    final counts = [
      for (var i = 0; i < boundaries.length; i++)
        (totals[i].valueOrNull ?? 0) -
            (i == 0 ? 0 : (totals[i - 1].valueOrNull ?? 0)),
    ];

    return [
      for (var i = boundaries.length - 1; i >= 0; i--)
        ChartDatum(
          AppDateUtils.formatMonth(boundaries[i]),
          counts[i] < 0 ? 0 : counts[i],
          AppColors.secondary,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChartDatum>>(
      future: _series,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 120, child: LoadingView());
        }
        return VisitTrendChart(data: snapshot.data!);
      },
    );
  }
}
