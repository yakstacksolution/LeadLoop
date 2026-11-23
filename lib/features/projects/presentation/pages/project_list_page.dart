import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_fab.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/repositories/project_repository.dart';
import '../bloc/project_list_cubit.dart';
import '../widgets/project_card.dart';

/// Project list. Admins see and manage everything; employees see only the
/// projects they are assigned to, which is also all the rules will return.
class ProjectListPage extends StatelessWidget {
  const ProjectListPage({super.key, this.scopeToCurrentUser = false});

  final bool scopeToCurrentUser;

  @override
  Widget build(BuildContext context) {
    final auth = context.select((AuthCubit cubit) => cubit.state);

    return BlocProvider(
      create: (_) => ProjectListCubit(
        repository: sl<ProjectRepository>(),
        employeeId: scopeToCurrentUser ? auth.uid : null,
      )..watch(),
      child: _ProjectListView(
        title: scopeToCurrentUser ? 'My projects' : 'Projects',
        canCreate: auth.isAdmin,
      ),
    );
  }
}

class _ProjectListView extends StatefulWidget {
  const _ProjectListView({required this.title, required this.canCreate});

  final String title;
  final bool canCreate;

  @override
  State<_ProjectListView> createState() => _ProjectListViewState();
}

class _ProjectListViewState extends State<_ProjectListView> {
  /// Null shows everything. Archived projects are the reason this exists —
  /// they pile up and bury the live ones.
  ProjectStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final canCreate = widget.canCreate;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: canCreate
          ? AppFab(
              heroTag: 'fab-project-list',
              icon: Icons.add,
              label: 'New project',
              onPressed: () => context.push(AppRoutes.createProject),
            )
          : null,
      body: BlocBuilder<ProjectListCubit, ProjectListState>(
        builder: (context, state) {
          if (state.isLoading) return const SkeletonList();

          if (state.failure != null) {
            return ErrorView(
              failure: state.failure!,
              onRetry: () => context.read<ProjectListCubit>().watch(),
            );
          }

          if (state.isEmpty) {
            return EmptyView(
              icon: Icons.folder_outlined,
              title: canCreate ? 'No projects yet' : 'No projects assigned',
              message: canCreate
                  ? 'Create a project to group venues by area or campaign.'
                  : 'Your administrator has not assigned you to a project yet.',
              actionLabel: canCreate ? 'Create project' : null,
              onAction:
                  canCreate ? () => context.push(AppRoutes.createProject) : null,
            );
          }

          final projects = _statusFilter == null
              ? state.projects
              : state.projects
                  .where((project) => project.status == _statusFilter)
                  .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ProjectStatus?>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    segments: const [
                      ButtonSegment(value: null, label: Text('All')),
                      ButtonSegment(
                        value: ProjectStatus.active,
                        label: Text('Active'),
                      ),
                      ButtonSegment(
                        value: ProjectStatus.archived,
                        label: Text('Archived'),
                      ),
                    ],
                    selected: {_statusFilter},
                    onSelectionChanged: (selection) =>
                        setState(() => _statusFilter = selection.first),
                  ),
                ),
              ),
              Expanded(
                child: projects.isEmpty
                    ? const EmptyView(
                        icon: Icons.filter_list_off,
                        title: 'Nothing in this filter',
                        message: 'Switch back to All to see every project.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        itemCount: projects.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 2, bottom: 10),
                              child: Text(
                                '${projects.length} '
                                '${projects.length == 1 ? 'project' : 'projects'}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            );
                          }

                          final project = projects[index - 1];
                          return ProjectCard(
                            project: project,
                            onTap: () => context
                                .push(AppRoutes.projectDetailFor(project.id)),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
