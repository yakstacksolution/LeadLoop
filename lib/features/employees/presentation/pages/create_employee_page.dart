import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_defaults.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../projects/domain/entities/project.dart';
import '../../../projects/domain/repositories/project_repository.dart';
import '../../domain/repositories/employee_repository.dart';

class CreateEmployeePage extends StatefulWidget {
  const CreateEmployeePage({super.key});

  @override
  State<CreateEmployeePage> createState() => _CreateEmployeePageState();
}

class _CreateEmployeePageState extends State<CreateEmployeePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  UserRole _role = UserRole.employee;
  final Set<String> _projects = {};
  List<Project> _available = const [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [_name, _email, _phone]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final projects = await sl<ProjectRepository>().watchAllProjects().first;
    if (!mounted) return;
    setState(() {
      _available = projects.where((p) => p.status.isOpen).toList();
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);

    final result = await sl<EmployeeRepository>().createEmployee(
      fullName: _name.text.trim(),
      email: _email.text.trim(),
      role: _role,
      phone: _phone.text.trim(),
      assignedProjectIds: _projects.toList(),
      // Every account starts on the same known password; the employee is
      // asked to change it at first sign-in.
      password: AppDefaults.initialEmployeePassword,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(context.showError, (created) async {
      await _showCredentials(created);
      if (!mounted) return;
      context.pop();
    });
  }

  /// Shows the sign-in details so the admin can hand them over in person.
  Future<void> _showCredentials(CreatedEmployee created) {
    // The account is provisioned with the shared starting password, so that
    // is what gets shown — the server only returns a generated one when no
    // password was supplied.
    final password =
        created.temporaryPassword ?? AppDefaults.initialEmployeePassword;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              size: 24, color: AppColors.success),
        ),
        title: const Text('Account created', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CredentialRow(
              label: 'Email',
              value: created.email,
              icon: Icons.mail_outline,
            ),
            const SizedBox(height: 10),
            _CredentialRow(
              label: 'Password',
              value: password,
              icon: Icons.key_outlined,
              monospace: true,
              highlight: true,
            ),
            const SizedBox(height: 12),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 15, color: AppColors.textMuted),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppDefaults.initialPasswordNotice,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: '${created.email}\n$password'),
                    );
                    context.showSuccess('Sign-in details copied.');
                  },
                  icon: const Icon(Icons.copy, size: 17),
                  label: const Text('Copy details'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(title: const Text('Add employee')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
          children: [
            SectionCard(
              title: 'Person',
              child: Column(
                children: [
                  AppTextField(
                    controller: _name,
                    label: 'Full name',
                    prefixIcon: Icons.person_outline,
                    enabled: !_submitting,
                    validator: (value) =>
                        Validators.minLength(value, 2, 'Full name'),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _email,
                    label: 'Email',
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_submitting,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _phone,
                    label: 'Phone (optional)',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    enabled: !_submitting,
                    validator: Validators.optionalPhone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Access',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppDropdownField<UserRole>(
                    value: _role,
                    label: 'Role',
                    items: UserRole.values,
                    itemLabel: (role) => role.label,
                    enabled: !_submitting,
                    onChanged: (value) =>
                        setState(() => _role = value ?? _role),
                  ),
                  if (_role.isAdmin) ...[
                    const SizedBox(height: 12),
                    const InlineMessage.warning(
                      message:
                          'Admins can see and manage every project, venue '
                          'and employee. Only grant this when it is needed.',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Projects',
              child: _available.isEmpty
                  ? const Text(
                      'No open projects yet. You can assign projects later from '
                      'the employee or project screen.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    )
                  : Column(
                      children: [
                        for (final project in _available)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: _projects.contains(project.id),
                            title: Text(project.name),
                            subtitle: Text(
                              project.status.label,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onChanged: _submitting
                                ? null
                                : (checked) => setState(() {
                                    if (checked ?? false) {
                                      _projects.add(project.id);
                                    } else {
                                      _projects.remove(project.id);
                                    }
                                  }),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create account'),
            ),
            const SizedBox(height: 10),
            const Text(
              'The account is created with the password '
              '${AppDefaults.initialEmployeePassword}. Hand it over, then ask '
              'them to change it from the sign-in screen\u2019s '
              '\u201cForgot password\u201d link.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// One labelled credential inside the "Account created" dialog.
class _CredentialRow extends StatelessWidget {
  const _CredentialRow({
    required this.label,
    required this.value,
    required this.icon,
    this.monospace = false,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool monospace;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final accent = highlight ? AppColors.primary : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.07)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.30)
              : AppColors.outline,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 1),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: monospace ? 14.5 : 13.5,
                    fontFamily: monospace ? 'monospace' : null,
                    fontWeight: FontWeight.w600,
                    color: highlight ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
