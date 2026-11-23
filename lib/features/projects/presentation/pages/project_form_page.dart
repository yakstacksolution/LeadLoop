import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../employees/domain/repositories/employee_repository.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';

class ProjectFormPage extends StatefulWidget {
  const ProjectFormPage({super.key, this.projectId});

  /// Null when creating.
  final String? projectId;

  @override
  State<ProjectFormPage> createState() => _ProjectFormPageState();
}

class _ProjectFormPageState extends State<ProjectFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  ProjectStatus _status = ProjectStatus.active;
  VenuePriority _priority = VenuePriority.medium;
  Set<String> _assigned = {};

  Project? _existing;
  List<AppUser> _employees = const [];
  bool _loading = true;
  bool _submitting = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final employees = await sl<EmployeeRepository>().watchEmployees().first;

      Project? existing;
      if (widget.projectId != null) {
        final result = await sl<ProjectRepository>().getProject(widget.projectId!);
        if (result.isFailure) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _loadError = result.failureOrNull;
          });
          return;
        }
        existing = result.valueOrNull;
      }

      if (!mounted) return;
      setState(() {
        _employees = employees.where((e) => e.isActive).toList();
        _existing = existing;
        if (existing != null) {
          _name.text = existing.name;
          _status = existing.status;
          _priority = existing.priority;
          _assigned = existing.assignedEmployeeIds.toSet();
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    final repository = sl<ProjectRepository>();
    final auth = context.read<AuthCubit>().state;

    final project = Project(
      id: _existing?.id ?? '',
      name: _name.text.trim(),
      // A project is just a name and a status now. These fields stay on the
      // entity for records created before that change, so an edit carries
      // them through untouched rather than blanking them.
      description: _existing?.description ?? '',
      area: _existing?.area ?? '',
      startDate: _existing?.startDate,
      endDate: _existing?.endDate,
      status: _status,
      priority: _priority,
      assignedEmployeeIds: _assigned.toList(),
      createdBy: _existing?.createdBy ?? auth.uid,
    );

    if (_existing == null) {
      final result = await repository.createProject(project, createdBy: auth.uid ?? '');
      if (!mounted) return;
      setState(() => _submitting = false);
      result.fold(context.showError, (_) {
        context.showSuccess('Project created.');
        context.pop();
      });
      return;
    }

    final updateResult = await repository.updateProject(project);
    if (!mounted) return;

    if (updateResult.isFailure) {
      setState(() => _submitting = false);
      context.showError(updateResult.failureOrNull!);
      return;
    }

    // Membership is written separately because it has to touch both the
    // project and every affected user document.
    final assignResult = await repository.setAssignedEmployees(
      projectId: project.id,
      employeeIds: _assigned.toList(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    assignResult.fold(context.showError, (_) {
      context.showSuccess('Project updated.');
      context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingView());

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project')),
        body: ErrorView(failure: mapError(_loadError!), onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'New project' : 'Edit project'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
          children: [
            SectionCard(
              title: 'Project details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _name,
                    label: 'Project name',
                    hint: 'e.g. Kathmandu Venue Onboarding',
                    prefixIcon: Icons.folder_outlined,
                    enabled: !_submitting,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        Validators.minLength(value, 3, 'Project name'),
                  ),
                  const SizedBox(height: 12),
                  AppDropdownField<ProjectStatus>(
                    value: _status,
                    label: 'Status',
                    items: ProjectStatus.values,
                    itemLabel: (status) => status.label,
                    prefixIcon: Icons.flag_outlined,
                    enabled: !_submitting,
                    onChanged: (value) => setState(() => _status = value ?? _status),
                  ),
                  const SizedBox(height: 12),
                  AppDropdownField<VenuePriority>(
                    value: _priority,
                    label: 'Priority',
                    items: VenuePriority.values,
                    itemLabel: (priority) => priority.label,
                    prefixIcon: Icons.priority_high,
                    enabled: !_submitting,
                    onChanged: (value) =>
                        setState(() => _priority = value ?? _priority),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Assigned employees',
              child: _employees.isEmpty
                  ? const Text(
                      'No active employees yet. Create employee accounts first, '
                      'then assign them here.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    )
                  : Column(
                      children: [
                        for (final employee in _employees)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: _assigned.contains(employee.id),
                            title: Text(employee.fullName),
                            subtitle: Text(
                              '${employee.role.label} · ${employee.email}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onChanged: _submitting
                                ? null
                                : (checked) => setState(() {
                                      if (checked ?? false) {
                                        _assigned.add(employee.id);
                                      } else {
                                        _assigned.remove(employee.id);
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
                  : Text(_existing == null ? 'Create project' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
