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
import '../../../../core/utils/validators.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../projects/domain/entities/project.dart';
import '../../../projects/domain/repositories/project_repository.dart';
import '../../../venues/domain/entities/venue_filter.dart';
import '../../../venues/domain/repositories/venue_repository.dart';
import '../../../venues/presentation/widgets/venue_card.dart';
import '../../domain/repositories/employee_repository.dart';

class EmployeeDetailPage extends StatefulWidget {
  const EmployeeDetailPage({super.key, required this.employeeId});

  final String employeeId;

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  late final Stream<AppUser?> _employee =
      sl<EmployeeRepository>().watchEmployee(widget.employeeId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _employee,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Employee')),
            body: ErrorView(failure: mapError(snapshot.error!)),
          );
        }
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingView());
        }

        final user = snapshot.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Employee')),
            body: const EmptyView(
              icon: Icons.person_off_outlined,
              title: 'Employee not found',
              message: 'The account may have been removed.',
            ),
          );
        }

        return _EmployeeDetailView(user: user);
      },
    );
  }
}

class _EmployeeDetailView extends StatefulWidget {
  const _EmployeeDetailView({required this.user});

  final AppUser user;

  @override
  State<_EmployeeDetailView> createState() => _EmployeeDetailViewState();
}

class _EmployeeDetailViewState extends State<_EmployeeDetailView> {
  AppUser get user => widget.user;

  Future<Result<List<Project>>>? _projects;
  List<String>? _projectScope;

  /// Only re-queried when the assignment list actually changes.
  Future<Result<List<Project>>> get projects {
    if (_projectScope == null ||
        !listEquals(_projectScope, user.assignedProjectIds)) {
      _projectScope = List.of(user.assignedProjectIds);
      _projects =
          sl<ProjectRepository>().getProjectsByIds(user.assignedProjectIds);
    }
    return _projects!;
  }

  late final Future<Result<VenuePage>> _recentVenues =
      sl<VenueRepository>().fetchVenues(
    filter: VenueFilter(assignedEmployeeId: user.id),
    limit: 5,
  );

  EmployeeRepository get _repository => sl<EmployeeRepository>();

  Future<void> _toggleStatus(BuildContext context) async {
    final disabling = user.isActive;

    final ok = await confirm(
      context,
      title: disabling ? 'Disable account?' : 'Re-enable account?',
      message: disabling
          ? '${user.fullName} loses access to all data immediately — the '
              'security rules refuse every read and write, and the app '
              'refuses the sign-in. Their venues, visits and notes are kept.\n\n'
              'Their Firebase Auth login itself stays enabled: switching that '
              'off needs the Admin SDK, which needs the Blaze plan.'
          : '${user.fullName} will be able to sign in again.',
      confirmLabel: disabling ? 'Disable' : 'Enable',
      isDestructive: disabling,
    );
    if (!ok || !context.mounted) return;

    final result = await _repository.setStatus(
      user.id,
      disabling ? UserStatus.disabled : UserStatus.active,
    );
    if (!context.mounted) return;

    result.fold(
      context.showError,
      (_) => context.showSuccess(disabling ? 'Account disabled.' : 'Account enabled.'),
    );
  }

  Future<void> _changeRole(BuildContext context, UserRole role) async {
    final ok = await confirm(
      context,
      title: 'Change role to ${role.label}?',
      message: role.isAdmin
          ? 'Admins can see and manage every project, venue and employee.'
          : '${user.fullName} will only see the projects they are assigned to.',
      confirmLabel: 'Change role',
    );
    if (!ok || !context.mounted) return;

    final result = await _repository.setRole(user.id, role);
    if (!context.mounted) return;

    result.fold(
      context.showError,
      (_) => context.showSuccess('Role updated to ${role.label}.'),
    );
  }

  Future<void> _editProjects(BuildContext context) async {
    final projects = await sl<ProjectRepository>().watchAllProjects().first;
    if (!context.mounted) return;

    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProjectPickerSheet(
        projects: projects,
        initiallySelected: user.assignedProjectIds.toSet(),
      ),
    );
    if (selected == null || !context.mounted) return;

    final result = await _repository.setAssignedProjects(user.id, selected);
    if (!context.mounted) return;

    result.fold(
      context.showError,
      (_) => context.showSuccess('Project assignments updated.'),
    );
  }

  Future<void> _editDetails(BuildContext context) async {
    final updated = await showModalBottomSheet<AppUser>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditEmployeeSheet(user: user),
    );
    if (updated == null || !context.mounted) return;

    final result = await _repository.updateDetails(updated);
    if (!context.mounted) return;

    result.fold(
      context.showError,
      (_) => context.showSuccess('Details updated.'),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Delete ${user.fullName}?',
      message: 'Their login and profile are removed for good — this cannot be '
          'undone.\n\nTheir venues, contacts, activities, visits and notes are '
          'kept and handed to you, so nothing they recorded is lost.',
      confirmLabel: 'Delete account',
      isDestructive: true,
      icon: Icons.person_remove_outlined,
    );
    if (!ok || !context.mounted) return;

    // The stream this page listens to emits null the moment the profile is
    // gone, so pop first and let the list rebuild behind it.
    final result = await _repository.deleteEmployee(user.id);
    if (!context.mounted) return;

    result.fold(context.showError, (loginDeleted) {
      if (loginDeleted) {
        context.showSuccess('${user.fullName} was removed completely.');
      } else {
        // Their profile is gone either way, so the account can no longer read
        // anything or sign in — but the login row is still in Firebase Auth.
        context.showSnack(
          '${user.fullName} was removed. Their sign-in still exists because '
          'they changed their password — delete it in the Firebase console.',
          background: AppColors.warning,
          icon: Icons.info_outline,
        );
      }
      if (context.canPop()) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.select((AuthCubit cubit) => cubit.state);
    final isSelf = auth.uid == user.id;
    final isAdmin = auth.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(user.fullName, overflow: TextOverflow.ellipsis),
        actions: [
          // Everything here is an admin power. An employee viewing a
          // colleague — or themselves — gets a read-only screen.
          if (isAdmin && !isSelf)
            PopupMenuButton<String>(
              tooltip: 'Account options',
              position: PopupMenuPosition.under,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (value) => switch (value) {
                'edit' => _editDetails(context),
                'status' => _toggleStatus(context),
                'admin' => _changeRole(context, UserRole.admin),
                'employee' => _changeRole(context, UserRole.employee),
                'delete' => _delete(context),
                _ => null,
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: _MenuRow(icon: Icons.edit_outlined, label: 'Edit details'),
                ),
                PopupMenuItem(
                  value: 'status',
                  child: _MenuRow(
                    icon: user.isActive
                        ? Icons.block_outlined
                        : Icons.check_circle_outline,
                    label: user.isActive ? 'Disable account' : 'Enable account',
                  ),
                ),
                if (!user.isAdmin)
                  const PopupMenuItem(
                    value: 'admin',
                    child: _MenuRow(
                      icon: Icons.shield_outlined,
                      label: 'Make admin',
                    ),
                  ),
                if (user.isAdmin)
                  const PopupMenuItem(
                    value: 'employee',
                    child: _MenuRow(
                      icon: Icons.person_outline,
                      label: 'Make employee',
                    ),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: _MenuRow(
                    icon: Icons.delete_outline,
                    label: 'Delete account',
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: [
          SectionCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          StatusChip(
                            label: user.role.label,
                            color: user.isAdmin
                                ? AppColors.primary
                                : AppColors.secondary,
                            dense: true,
                          ),
                          StatusChip(
                            label: user.status.label,
                            color: user.isActive
                                ? AppColors.success
                                : AppColors.danger,
                            dense: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isSelf) ...[
            const SizedBox(height: 14),
            const InlineMessage(
              message: 'This is your own account. Role and status changes must be '
                  'made by another administrator.',
            ),
          ] else if (!isAdmin) ...[
            const SizedBox(height: 14),
            const InlineMessage(
              message: 'Only an administrator can edit or remove a team member.',
            ),
          ],
          const SizedBox(height: 14),
          SectionCard(
            title: 'Details',
            child: Column(
              children: [
                DetailRow(label: 'Phone', value: user.phone, icon: Icons.phone_outlined),
                DetailRow(label: 'Employee code', value: user.employeeCode),
                DetailRow(
                  label: 'Created',
                  value: AppDateUtils.formatDate(user.createdAt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Projects (${user.assignedProjectIds.length})',
            action: isAdmin && !isSelf
                ? TextButton(
                    onPressed: () => _editProjects(context),
                    child: const Text('Edit'),
                  )
                : null,
            child: user.assignedProjectIds.isEmpty
                ? const Text(
                    'Not assigned to any project. Until they are, they cannot '
                    'see or add venues.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  )
                : FutureBuilder(
                    future: projects,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(height: 50, child: LoadingView());
                      }
                      final projects = snapshot.data!.valueOrNull ?? <Project>[];

                      return Column(
                        children: [
                          for (final project in projects)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: const Icon(Icons.folder_outlined, size: 20),
                              title: Text(project.name),
                              trailing: StatusChip.project(project.status, dense: true),
                              onTap: () => context
                                  .push(AppRoutes.projectDetailFor(project.id)),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Recent venues',
            child: FutureBuilder(
              future: _recentVenues,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 60, child: LoadingView());
                }

                final result = snapshot.data!;
                if (result.isFailure) {
                  return ErrorView(failure: result.failureOrNull!);
                }

                final venues = result.valueOrNull?.venues ?? [];
                if (venues.isEmpty) {
                  return const Text(
                    'No venues assigned yet.',
                    style: TextStyle(fontSize: 13),
                  );
                }

                return Column(
                  children: [
                    for (final venue in venues)
                      VenueCard(
                        venue: venue,
                        onTap: () => context.push(AppRoutes.venueDetailFor(venue.id)),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectPickerSheet extends StatefulWidget {
  const _ProjectPickerSheet({
    required this.projects,
    required this.initiallySelected,
  });

  final List<Project> projects;
  final Set<String> initiallySelected;

  @override
  State<_ProjectPickerSheet> createState() => _ProjectPickerSheetState();
}

class _ProjectPickerSheetState extends State<_ProjectPickerSheet> {
  late final Set<String> _selected = {...widget.initiallySelected};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Assign projects',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final project in widget.projects)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _selected.contains(project.id),
                    title: Text(project.name),
                    subtitle: Text(
                      project.status.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onChanged: (checked) => setState(() {
                      if (checked ?? false) {
                        _selected.add(project.id);
                      } else {
                        _selected.remove(project.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_selected.toList()),
            child: const Text('Save assignments'),
          ),
        ],
      ),
    );
  }
}


/// A row in the account-options menu.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 18, color: tint),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 14, color: tint)),
      ],
    );
  }
}

/// Edits the fields an admin may change freely.
///
/// Email is not among them: it is the auth identity, so changing it means
/// changing the login itself, which the Admin SDK has to do. Role, status and
/// project assignments have their own guarded actions.
class _EditEmployeeSheet extends StatefulWidget {
  const _EditEmployeeSheet({required this.user});

  final AppUser user;

  @override
  State<_EditEmployeeSheet> createState() => _EditEmployeeSheetState();
}

class _EditEmployeeSheetState extends State<_EditEmployeeSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.fullName);
  late final _phone = TextEditingController(text: widget.user.phone);
  late final _code = TextEditingController(text: widget.user.employeeCode);

  @override
  void dispose() {
    for (final controller in [_name, _phone, _code]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    Navigator.of(context).pop(
      widget.user.copyWith(
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        employeeCode: _code.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Edit details',
                  style: TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.user.email,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _name,
                  label: 'Full name',
                  prefixIcon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      Validators.minLength(value, 2, 'Full name'),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _phone,
                  label: 'Phone',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: Validators.optionalPhone,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _code,
                  label: 'Employee code (optional)',
                  prefixIcon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Save changes'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
