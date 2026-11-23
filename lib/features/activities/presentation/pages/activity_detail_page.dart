import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../domain/entities/activity.dart';
import '../../domain/repositories/activity_repository.dart';
import '../widgets/complete_activity_sheet.dart';

class ActivityDetailPage extends StatefulWidget {
  const ActivityDetailPage({super.key, required this.activityId});

  final String activityId;

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  /// Subscribed once. Creating this in build() would reopen the Firestore
  /// listener on every rebuild.
  late final Stream<Activity?> _activity =
      sl<ActivityRepository>().watchActivity(widget.activityId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Activity?>(
      stream: _activity,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Activity')),
            body: ErrorView(failure: mapError(snapshot.error!)),
          );
        }
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingView());
        }

        final activity = snapshot.data;
        if (activity == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Activity')),
            body: const EmptyView(
              icon: Icons.event_busy_outlined,
              title: 'Activity not found',
              message: 'It may have been removed.',
            ),
          );
        }

        return _ActivityDetailView(activity: activity);
      },
    );
  }
}

class _ActivityDetailView extends StatefulWidget {
  const _ActivityDetailView({required this.activity});

  final Activity activity;

  @override
  State<_ActivityDetailView> createState() => _ActivityDetailViewState();
}

class _ActivityDetailViewState extends State<_ActivityDetailView> {
  bool _busy = false;

  ActivityRepository get _repository => sl<ActivityRepository>();

  Future<void> _run(Future<void> Function() action, String successMessage) async {
    setState(() => _busy = true);
    await action();
    if (!mounted) return;
    setState(() => _busy = false);
    context.showSuccess(successMessage);
  }

  Future<void> _complete() async {
    final note = await showCompleteActivitySheet(
      context,
      activity: widget.activity,
    );
    if (note == null || !mounted) return;

    final auth = context.read<AuthCubit>().state;
    setState(() => _busy = true);

    final result = await _repository.complete(
      activity: widget.activity,
      outcomeNote: note,
      employeeName: auth.user?.fullName ?? '',
    );

    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(context.showError, (_) => context.showSuccess('Marked complete.'));
  }

  Future<void> _reschedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: widget.activity.scheduledAt.isAfter(now)
          ? widget.activity.scheduledAt
          : now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.activity.scheduledAt),
    );
    if (!mounted) return;

    final newSlot = AppDateUtils.combine(
      date,
      hour: time?.hour ?? 9,
      minute: time?.minute ?? 0,
    );

    final auth = context.read<AuthCubit>().state;
    setState(() => _busy = true);

    final result = await _repository.reschedule(
      activity: widget.activity,
      newScheduledAt: newSlot,
      createdBy: auth.uid ?? '',
    );

    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      context.showError,
      (_) => context.showSuccess(
        'Rescheduled to ${AppDateUtils.formatDateTime(newSlot)}.',
      ),
    );
  }

  Future<void> _cancel() async {
    final ok = await confirm(
      context,
      title: 'Cancel activity?',
      message: 'It stays in the venue history, marked as cancelled.',
      confirmLabel: 'Cancel activity',
      cancelLabel: 'Keep it',
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    await _run(
      () async {
        final result = await _repository.cancel(widget.activity);
        if (!mounted) return;
        result.fold(context.showError, (_) {});
      },
      'Activity cancelled.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final isOpen = activity.status.isOpen;

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        AppIcons.forActivityType(activity.type),
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.title.trim().isEmpty
                                ? activity.type.label
                                : activity.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activity.type.label,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    StatusChip.activity(activity.status),
                    if (activity.isOverdue)
                      StatusChip(
                        label: AppDateUtils.relativeLabel(activity.scheduledAt),
                        color: AppColors.danger,
                        icon: Icons.warning_amber_rounded,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Schedule',
            child: Column(
              children: [
                DetailRow(
                  label: 'Scheduled',
                  value: AppDateUtils.formatDateTime(activity.scheduledAt),
                  icon: Icons.schedule,
                ),
                if (activity.endAt != null)
                  DetailRow(
                    label: 'Ends',
                    value: AppDateUtils.formatDateTime(activity.endAt),
                  ),
                if (activity.reminderAt != null)
                  DetailRow(
                    label: 'Reminder',
                    value: AppDateUtils.formatDateTime(activity.reminderAt),
                  ),
                if (activity.rescheduledFrom != null)
                  DetailRow(
                    label: 'Moved from',
                    value: AppDateUtils.formatDateTime(activity.rescheduledFrom),
                  ),
                if (activity.completedAt != null)
                  DetailRow(
                    label: 'Completed',
                    value: AppDateUtils.formatDateTime(activity.completedAt),
                  ),
              ],
            ),
          ),
          if (activity.description.trim().isNotEmpty ||
              activity.outcomeNote.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            SectionCard(
              title: activity.outcomeNote.trim().isNotEmpty ? 'Outcome' : 'Notes',
              child: Text(
                activity.outcomeNote.trim().isNotEmpty
                    ? activity.outcomeNote
                    : activity.description,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SectionCard(
            title: 'Venue',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.stadium_outlined),
              title: Text(
                activity.venueName.isEmpty ? 'Open venue' : activity.venueName,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.venueDetailFor(activity.venueId)),
            ),
          ),
          if (isOpen) ...[
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _busy ? null : _complete,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Mark complete'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _reschedule,
                    icon: const Icon(Icons.update, size: 18),
                    label: const Text('Reschedule'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _cancel,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
