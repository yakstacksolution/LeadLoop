import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_fab.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/repositories/employee_repository.dart';

class EmployeeListPage extends StatefulWidget {
  const EmployeeListPage({super.key});

  @override
  State<EmployeeListPage> createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage> {
  UserStatus? _statusFilter;

  /// Opened once. Building this inside `build()` would cancel and reopen the
  /// Firestore listener every time the filter changes, since that calls
  /// setState.
  late final Stream<List<AppUser>> _employees =
      sl<EmployeeRepository>().watchEmployees();

  List<AppUser> _filter(List<AppUser> users) {
    return users
        .where((user) => _statusFilter == null || user.status == _statusFilter)
        .toList()
      // Active people first, then alphabetical: a disabled account is
      // history, not someone you are about to assign work to.
      ..sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      });
  }

  /// Removing someone straight from the list. Same guarded path as the
  /// detail screen: admins only, never yourself.
  Future<void> _delete(BuildContext context, AppUser user) async {
    final ok = await confirm(
      context,
      title: 'Remove ${user.fullName}?',
      message: 'Their login and profile are deleted and they lose access for '
          'good — this cannot be undone.\n\nTheir venues, contacts, activities, '
          'visits and notes are kept and handed to you.',
      confirmLabel: 'Remove from team',
      isDestructive: true,
      icon: Icons.person_remove_outlined,
    );
    if (!ok || !context.mounted) return;

    final result = await sl<EmployeeRepository>().deleteEmployee(user.id);
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.select((AuthCubit cubit) => cubit.state);

    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      floatingActionButton: AppFab(
        heroTag: 'fab-employee-list',
        icon: Icons.person_add_alt,
        label: 'Add employee',
        onPressed: () => context.push(AppRoutes.createEmployee),
      ),
      body: Column(
        children: [
          // The filter used to hide behind an app-bar menu, where nobody knew
          // a list was filtered. A segmented control states it.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<UserStatus?>(
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
                  ButtonSegment(value: UserStatus.active, label: Text('Active')),
                  ButtonSegment(
                    value: UserStatus.disabled,
                    label: Text('Disabled'),
                  ),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (selection) =>
                    setState(() => _statusFilter = selection.first),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: _employees,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorView(failure: mapError(snapshot.error!));
                }
                if (!snapshot.hasData) return const SkeletonList();

                final users = _filter(snapshot.data!);
                if (users.isEmpty) {
                  return EmptyView(
                    icon: Icons.groups_outlined,
                    title: snapshot.data!.isEmpty
                        ? 'No employees yet'
                        : 'No one matches this filter',
                    message: snapshot.data!.isEmpty
                        ? 'Create accounts so your team can start adding venues.'
                        : 'Try clearing the filter.',
                    actionLabel:
                        snapshot.data!.isEmpty ? 'Add employee' : null,
                    onAction: snapshot.data!.isEmpty
                        ? () => context.push(AppRoutes.createEmployee)
                        : null,
                  );
                }

                final activeCount = users.where((u) => u.isActive).length;

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: users.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 2),
                        child: Text(
                          '${users.length} '
                          '${users.length == 1 ? 'person' : 'people'} · '
                          '$activeCount active',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      );
                    }

                    final user = users[index - 1];
                    return _EmployeeCard(
                      user: user,
                      onTap: () =>
                          context.push(AppRoutes.employeeDetailFor(user.id)),
                      // You cannot remove yourself, and only an admin can
                      // remove anyone.
                      onDelete: auth.isAdmin && auth.uid != user.id
                          ? () => _delete(context, user)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


/// One team member in the list.
///
/// A card rather than a divided row: the status chips and the employee code
/// need more room than a `ListTile` gives them, and the cards match the venue
/// and contact lists elsewhere in the app.
class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.user,
    required this.onTap,
    this.onDelete,
  });

  final AppUser user;
  final VoidCallback onTap;

  /// Null hides the menu entirely — for your own row, and for non-admins.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tint = user.isActive ? AppColors.primary : AppColors.neutral;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.fromLTRB(13, 13, onDelete == null ? 13 : 4, 13),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: 0.13),
                  border: Border.all(color: tint.withValues(alpha: 0.30)),
                ),
                alignment: Alignment.center,
                child: Text(
                  user.initials,
                  style: TextStyle(
                    color: tint,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (user.isAdmin) ...[
                          const SizedBox(width: 6),
                          const StatusChip(
                            label: 'Admin',
                            color: AppColors.primary,
                            dense: true,
                          ),
                        ],
                        if (!user.isActive) ...[
                          const SizedBox(width: 6),
                          const StatusChip(
                            label: 'Disabled',
                            color: AppColors.danger,
                            dense: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (user.employeeCode.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        user.employeeCode,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (onDelete == null)
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textMuted)
              else
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 20, color: AppColors.textMuted),
                  tooltip: 'Team member options',
                  position: PopupMenuPosition.under,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) => switch (value) {
                    'open' => onTap(),
                    'delete' => onDelete!(),
                    _ => null,
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new, size: 18),
                          SizedBox(width: 10),
                          Text('Open profile', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.person_remove_outlined,
                              size: 18, color: AppColors.danger),
                          SizedBox(width: 10),
                          Text(
                            'Remove from team',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
