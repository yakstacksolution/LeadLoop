import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _editing = false;
  bool _seeded = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cubit = context.read<AuthCubit>();
    final user = cubit.state.user;
    if (user == null) return;

    final ok = await cubit.updateOwnProfile(
      user.copyWith(
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        employeeCode: _code.text.trim(),
      ),
    );

    if (!mounted) return;
    if (ok) {
      setState(() => _editing = false);
      context.showSuccess('Profile updated.');
    } else {
      context.showError(cubit.state.failure ?? 'Could not save your profile.');
    }
  }

  Future<void> _signOut() async {
    final ok = await confirm(
      context,
      title: 'Sign out?',
      message: 'You will need your email and password to sign back in.',
      confirmLabel: 'Sign out',
    );
    if (!ok || !mounted) return;
    await context.read<AuthCubit>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final user = state.user;
        if (user == null) {
          return const Scaffold(body: LoadingView());
        }

        if (!_seeded) {
          _name.text = user.fullName;
          _phone.text = user.phone;
          _code.text = user.employeeCode;
          _seeded = true;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              if (!_editing)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                  onPressed: () => setState(() => _editing = true),
                ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
              children: [
                SectionCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 27,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                        child: Text(
                          user.initials,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
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
                                fontSize: 16.5,
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
                            StatusChip(
                              label: user.role.label,
                              color: user.isAdmin
                                  ? AppColors.primary
                                  : AppColors.secondary,
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'My details',
                  child: _editing
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              controller: _name,
                              label: 'Full name',
                              prefixIcon: Icons.person_outline,
                              enabled: !state.isSubmitting,
                              validator: (value) =>
                                  Validators.minLength(value, 2, 'Full name'),
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _phone,
                              label: 'Phone',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              enabled: !state.isSubmitting,
                              validator: Validators.optionalPhone,
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _code,
                              label: 'Employee code',
                              prefixIcon: Icons.badge_outlined,
                              enabled: !state.isSubmitting,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: state.isSubmitting
                                        ? null
                                        : () => setState(() {
                                              _editing = false;
                                              _seeded = false;
                                            }),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: state.isSubmitting ? null : _save,
                                    child: const Text('Save'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            DetailRow(
                              label: 'Phone',
                              value: user.phone,
                              icon: Icons.phone_outlined,
                            ),
                            DetailRow(
                              label: 'Employee code',
                              value: user.employeeCode,
                            ),
                            DetailRow(
                              label: 'Projects',
                              value: '${user.assignedProjectIds.length} assigned',
                            ),
                            DetailRow(
                              label: 'Member since',
                              value: AppDateUtils.formatDate(user.createdAt),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Account',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lock_reset_outlined),
                        title: const Text('Change password'),
                        subtitle: const Text(
                          'We will email you a reset link.',
                          style: TextStyle(fontSize: 12),
                        ),
                        onTap: () async {
                          final sent = await context
                              .read<AuthCubit>()
                              .sendPasswordReset(user.email);
                          if (!context.mounted) return;
                          if (sent) {
                            context.showSuccess('Reset link sent to ${user.email}.');
                          } else {
                            context.showError(
                              context.read<AuthCubit>().state.failure ??
                                  'Could not send the reset link.',
                            );
                          }
                        },
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.logout,
                          color: AppColors.danger,
                        ),
                        title: const Text(
                          'Sign out',
                          style: TextStyle(color: AppColors.danger),
                        ),
                        onTap: _signOut,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
