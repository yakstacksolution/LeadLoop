import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../contacts/domain/entities/venue_contact.dart';
import '../../../contacts/domain/repositories/contact_repository.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../../venues/domain/repositories/venue_repository.dart';
import '../../domain/entities/activity.dart';
import '../../domain/repositories/activity_repository.dart';

/// Schedules a call, meeting, visit or follow-up against a venue.
///
/// The app records the plan; it does not dial anyone. Nothing here implies a
/// call was placed — status stays "Scheduled" until the employee says
/// otherwise.
class ScheduleActivityPage extends StatefulWidget {
  const ScheduleActivityPage({super.key, required this.venueId});

  final String venueId;

  @override
  State<ScheduleActivityPage> createState() => _ScheduleActivityPageState();
}

class _ScheduleActivityPageState extends State<ScheduleActivityPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  ActivityType _type = ActivityType.phoneCall;
  DateTime? _scheduledAt = DateTime.now().add(const Duration(days: 1));
  DateTime? _endAt;
  DateTime? _reminderAt;
  String? _contactId;

  Venue? _venue;
  List<VenueContact> _contacts = const [];
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
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    final venueResult = await sl<VenueRepository>().getVenue(widget.venueId);
    if (!mounted) return;

    if (venueResult.isFailure) {
      setState(() {
        _loading = false;
        _loadError = venueResult.failureOrNull;
      });
      return;
    }

    final venue = venueResult.valueOrNull!;
    final contactsResult = await sl<ContactRepository>().getContactsForVenue(
      widget.venueId,
      assignedEmployeeId: venue.assignedEmployeeId,
    );
    if (!mounted) return;

    setState(() {
      _venue = venue;
      // A missing contact list is not fatal — the contact is optional.
      _contacts = contactsResult.valueOrNull ?? const [];
      _contactId = _contacts.where((c) => c.isPrimary).firstOrNull?.id;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_scheduledAt == null) {
      context.showError('Choose when this is scheduled for.');
      return;
    }
    if (_endAt != null && _endAt!.isBefore(_scheduledAt!)) {
      context.showError('The end time cannot be before the start time.');
      return;
    }

    final venue = _venue!;
    final auth = context.read<AuthCubit>().state;
    setState(() => _submitting = true);

    final result = await sl<ActivityRepository>().createActivity(
      Activity(
        id: '',
        venueId: venue.id,
        venueName: venue.name,
        contactId: _contactId,
        projectId: venue.projectId,
        assignedEmployeeId: venue.assignedEmployeeId,
        type: _type,
        title: _title.text.trim(),
        description: _description.text.trim(),
        scheduledAt: _scheduledAt!,
        endAt: _endAt,
        reminderAt: _reminderAt,
        status: ActivityStatus.scheduled,
      ),
      createdBy: auth.uid ?? '',
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(context.showError, (_) {
      context.showSuccess('Scheduled for ${AppDateUtils.formatDateTime(_scheduledAt)}.');
      context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingView());
    }
    if (_loadError != null || _venue == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Schedule')),
        body: ErrorView(
          failure: mapError(_loadError ?? 'Venue not found'),
          onRetry: _load,
        ),
      );
    }

    final venue = _venue!;

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule activity')),
      body: SafeArea(
        // Bottom only: the app bar already handles the top inset, and the
        // sides are padded by the list itself.
        top: false,
        left: false,
        right: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.stadium_outlined,
                    size: 17,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      venue.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: 'Activity',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppDropdownField<ActivityType>(
                      value: _type,
                      label: 'Type',
                      items: ActivityType.values,
                      itemLabel: (type) => type.label,
                      prefixIcon: Icons.event_note_outlined,
                      enabled: !_submitting,
                      onChanged: (value) => setState(() => _type = value ?? _type),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _title,
                      label: 'Title',
                      hint: 'e.g. Discuss partnership terms',
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) => Validators.minLength(value, 3, 'Title'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: 'Schedule',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppDateField(
                      value: _scheduledAt,
                      label: 'Scheduled for',
                      includeTime: true,
                      clearable: false,
                      enabled: !_submitting,
                      onChanged: (value) => setState(() => _scheduledAt = value),
                    ),
                    const SizedBox(height: 12),
                    AppDateField(
                      value: _endAt,
                      label: 'Ends at (optional)',
                      includeTime: true,
                      enabled: !_submitting,
                      // Flagged inline as well as on submit, so the mistake is
                      // visible where it was made.
                      validatorMessage:
                          _endAt != null &&
                              _scheduledAt != null &&
                              _endAt!.isBefore(_scheduledAt!)
                          ? 'The end time is before the start time.'
                          : null,
                      onChanged: (value) => setState(() => _endAt = value),
                    ),
                    if (_contacts.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      AppDropdownField<String?>(
                        value: _contactId,
                        label: 'Contact person (optional)',
                        items: [null, ..._contacts.map((c) => c.id)],
                        itemLabel: (id) => id == null
                            ? 'No specific contact'
                            : _contacts.firstWhere((c) => c.id == id).fullName,
                        prefixIcon: Icons.person_outline,
                        enabled: !_submitting,
                        onChanged: (value) => setState(() => _contactId = value),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: 'Notes and reminder',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: _description,
                      label: 'Notes (optional)',
                      maxLines: 3,
                      maxLength: 300,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !_submitting,
                    ),
                    const SizedBox(height: 12),
                    AppDateField(
                      value: _reminderAt,
                      label: 'Remind me at (optional)',
                      includeTime: true,
                      enabled: !_submitting,
                      onChanged: (value) => setState(() => _reminderAt = value),
                    ),
                    const SizedBox(height: 10),
                    const InlineMessage(
                      message:
                          'Reminders are stored with the activity and shown '
                          'in the app. Push notifications are not enabled yet.',
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
                    : const Text('Schedule'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
