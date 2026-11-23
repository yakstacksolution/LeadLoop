import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../employees/domain/repositories/employee_repository.dart';
import '../../../venues/domain/entities/venue_filter.dart';
import '../../../venues/domain/repositories/venue_repository.dart';
import '../../../venues/presentation/widgets/venue_card.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  late final Stream<Project?> _project =
      sl<ProjectRepository>().watchProject(widget.projectId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: _project,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Project')),
            body: ErrorView(failure: mapError(snapshot.error!)),
          );
        }
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingView());
        }

        final project = snapshot.data;
        if (project == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Project')),
            body: const EmptyView(
              icon: Icons.folder_off_outlined,
              title: 'Project not found',
              message: 'It may have been removed.',
            ),
          );
        }

        return _ProjectDetailView(project: project);
      },
    );
  }
}

class _ProjectDetailView extends StatefulWidget {
  const _ProjectDetailView({required this.project});

  final Project project;

  @override
  State<_ProjectDetailView> createState() => _ProjectDetailViewState();
}

class _ProjectDetailViewState extends State<_ProjectDetailView>
    with SingleTickerProviderStateMixin {
  // Not DefaultTabController: its scope notifies TabBarView when tickers are
  // muted (e.g. a route covers this page), and TabBarView then jumps pages
  // mid-build, causing "markNeedsBuild() called during build".
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _setStatus(BuildContext context, ProjectStatus status) async {
    final result = await sl<ProjectRepository>().setStatus(widget.project.id, status);
    if (!context.mounted) return;
    result.fold(
      context.showError,
      (_) => context.showSuccess('Project marked ${status.label.toLowerCase()}.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select((AuthCubit cubit) => cubit.state.isAdmin);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name, overflow: TextOverflow.ellipsis),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit project',
              onPressed: () => context.push(AppRoutes.editProjectFor(widget.project.id)),
            ),
            PopupMenuButton<ProjectStatus>(
              onSelected: (status) => _setStatus(context, status),
              itemBuilder: (context) => [
                for (final status in ProjectStatus.values)
                  if (status != widget.project.status)
                    PopupMenuItem(
                      value: status,
                      child: Text('Mark ${status.label.toLowerCase()}'),
                    ),
              ],
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Venues')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(project: widget.project),
          _VenuesTab(project: widget.project),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab({required this.project});

  final Project project;

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab>
    with AutomaticKeepAliveClientMixin {
  /// Swiping between tabs must not re-run this tab's query.
  @override
  bool get wantKeepAlive => true;

  Project get project => widget.project;

  /// Re-fetched only when the membership list actually changes, not on every
  /// rebuild of the surrounding StreamBuilder.
  Future<Result<List<AppUser>>>? _team;
  List<String>? _teamScope;

  Future<Result<List<AppUser>>> get team {
    if (_teamScope == null ||
        !listEquals(_teamScope, project.assignedEmployeeIds)) {
      _teamScope = List.of(project.assignedEmployeeIds);
      _team = sl<EmployeeRepository>()
          .getEmployeesByIds(project.assignedEmployeeIds);
    }
    return _team!;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusChip.project(project.status),
                  StatusChip.priority(project.priority),
                ],
              ),
              if (project.description.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  project.description,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Details',
          child: Column(
            children: [
              DetailRow(
                label: 'Priority',
                value: project.priority.label,
                icon: Icons.flag_outlined,
              ),
              // Area and the date range are only shown when a project
              // actually carries them: the form stopped asking, so newer
              // projects have none.
              if (project.area.trim().isNotEmpty)
                DetailRow(
                  label: 'Target area',
                  value: project.area,
                  icon: Icons.place_outlined,
                ),
              if (project.startDate != null)
                DetailRow(
                  label: 'Start date',
                  value: AppDateUtils.formatDate(project.startDate),
                ),
              if (project.endDate != null)
                DetailRow(
                  label: 'End date',
                  value: AppDateUtils.formatDate(project.endDate),
                ),
              DetailRow(
                label: 'Created',
                value: AppDateUtils.formatDate(project.createdAt),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Team (${project.assignedEmployeeIds.length})',
          child: project.assignedEmployeeIds.isEmpty
              ? const Text(
                  'Nobody is assigned yet. Employees can only see a project '
                  'after they are assigned to it.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                )
              : FutureBuilder(
                  future: team,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(height: 60, child: LoadingView());
                    }

                    final result = snapshot.data!;
                    if (result.isFailure) {
                      return ErrorView(failure: result.failureOrNull!);
                    }

                    final members = result.valueOrNull ?? <AppUser>[];

                    return Column(
                      children: [
                        for (final member in members)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 17,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.14),
                              child: Text(
                                member.initials,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            title: Text(member.fullName),
                            subtitle: Text(
                              member.email,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: member.isActive
                                ? null
                                : const StatusChip(
                                    label: 'Disabled',
                                    color: AppColors.danger,
                                    dense: true,
                                  ),
                            onTap: () => context
                                .push(AppRoutes.employeeDetailFor(member.id)),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _VenuesTab extends StatefulWidget {
  const _VenuesTab({required this.project});

  final Project project;

  @override
  State<_VenuesTab> createState() => _VenuesTabState();
}

class _VenuesTabState extends State<_VenuesTab>
    with AutomaticKeepAliveClientMixin {
  /// Swiping between tabs must not re-run this tab's query.
  @override
  bool get wantKeepAlive => true;

  /// Issued once per screen. A FutureBuilder built inline re-runs its query on
  /// every rebuild, which on a tab view is constant.
  late final Future<Result<VenuePage>> _venues = sl<VenueRepository>().fetchVenues(
    filter: VenueFilter(projectId: widget.project.id),
    limit: 50,
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FutureBuilder(
      future: _venues,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SkeletonList();

        final result = snapshot.data!;
        if (result.isFailure) {
          return ErrorView(failure: result.failureOrNull!);
        }

        final venues = result.valueOrNull?.venues ?? [];
        if (venues.isEmpty) {
          return const EmptyView(
            icon: Icons.stadium_outlined,
            title: 'No venues yet',
            message: 'Venues added under this project will appear here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
          itemCount: venues.length,
          itemBuilder: (context, index) {
            final venue = venues[index];
            return VenueCard(
              venue: venue,
              onTap: () => context.push(AppRoutes.venueDetailFor(venue.id)),
            );
          },
        );
      },
    );
  }
}
