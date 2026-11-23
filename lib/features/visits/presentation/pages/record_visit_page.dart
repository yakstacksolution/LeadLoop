import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../venues/domain/entities/venue.dart';
import '../../../venues/domain/repositories/venue_repository.dart';
import '../../domain/entities/visit.dart';
import '../../domain/repositories/visit_repository.dart';
import '../widgets/visit_tile.dart';

/// Start a visit, or finish the one already in progress.
///
/// Location is requested once, only when the employee taps "Start visit", and
/// only after they have seen what it is for. Declining is fine: the visit is
/// then recorded as self-reported, and labelled that way everywhere.
class RecordVisitPage extends StatefulWidget {
  const RecordVisitPage({super.key, required this.venueId});

  final String venueId;

  @override
  State<RecordVisitPage> createState() => _RecordVisitPageState();
}

class _RecordVisitPageState extends State<RecordVisitPage> {
  final _notes = TextEditingController();

  Venue? _venue;
  Visit? _openVisit;
  DateTime? _nextFollowUpAt;
  bool _loading = true;
  bool _busy = false;
  Object? _loadError;
  String? _locationNotice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    final auth = context.read<AuthCubit>().state;
    final venueResult = await sl<VenueRepository>().getVenue(widget.venueId);
    if (!mounted) return;

    if (venueResult.isFailure) {
      setState(() {
        _loading = false;
        _loadError = venueResult.failureOrNull;
      });
      return;
    }

    final openResult = await sl<VisitRepository>().findOpenVisit(auth.uid ?? '');
    if (!mounted) return;

    final open = openResult.valueOrNull;

    setState(() {
      _venue = venueResult.valueOrNull;
      // Only an open visit for *this* venue can be finished from here.
      _openVisit = (open != null && open.venueId == widget.venueId) ? open : null;
      _notes.text = _openVisit?.notes ?? '';
      _loading = false;
    });

    if (open != null && open.venueId != widget.venueId) {
      setState(() => _locationNotice =
          'You have another visit still open at ${open.venueName}. '
          'Finish it before starting a new one.');
    }
  }

  Future<void> _startVisit() async {
    final venue = _venue!;
    final auth = context.read<AuthCubit>().state;

    setState(() {
      _busy = true;
      _locationNotice = null;
    });

    final outcome = await sl<LocationService>().getCurrentPosition();
    if (!mounted) return;

    final fixed = outcome is LocationFixed ? outcome : null;
    if (outcome is LocationUnavailable) {
      setState(() => _locationNotice =
          '${outcome.reason} This visit will be recorded as self-reported.');
    }

    final result = await sl<VisitRepository>().startVisit(
      Visit(
        id: '',
        venueId: venue.id,
        venueName: venue.name,
        projectId: venue.projectId,
        assignedEmployeeId: venue.assignedEmployeeId,
        employeeId: auth.uid ?? '',
        status: VisitStatus.inProgress,
        startAt: DateTime.now(),
        latitude: fixed?.latitude,
        longitude: fixed?.longitude,
        locationAccuracy: fixed?.accuracy,
        // The flag is decided here, once, and the rules forbid changing it.
        isSelfReported: fixed == null,
      ),
    );

    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(context.showError, (_) {
      context.showSuccess('Visit started.');
      _load();
    });
  }

  Future<void> _finishVisit() async {
    final visit = _openVisit!;
    setState(() => _busy = true);

    final result = await sl<VisitRepository>().completeVisit(
      visit: visit,
      notes: _notes.text,
      nextFollowUpAt: _nextFollowUpAt,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(context.showError, (_) {
      context.showSuccess('Visit recorded.');
      context.pop();
    });
  }

  Future<void> _cancelVisit() async {
    final ok = await confirm(
      context,
      title: 'Cancel this visit?',
      message: 'It stays in the history, marked as cancelled.',
      confirmLabel: 'Cancel visit',
      cancelLabel: 'Keep it',
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    final result = await sl<VisitRepository>().cancelVisit(_openVisit!);
    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(context.showError, (_) {
      context.showSuccess('Visit cancelled.');
      context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingView());

    if (_loadError != null || _venue == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Visit')),
        body: ErrorView(failure: mapError(_loadError ?? 'Venue not found'), onRetry: _load),
      );
    }

    final venue = _venue!;
    final open = _openVisit;

    return Scaffold(
      appBar: AppBar(title: Text(open == null ? 'Record visit' : 'Finish visit')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: [
          SectionCard(
            title: venue.name,
            child: Column(
              children: [
                DetailRow(
                  label: 'Address',
                  value: venue.address,
                  icon: Icons.place_outlined,
                ),
                DetailRow(label: 'Area', value: venue.locationLabel),
                DetailRow(
                  label: 'Previous visits',
                  value: venue.hasBeenVisited
                      ? '${venue.visitCount} — last '
                          '${AppDateUtils.formatDate(venue.lastVisitedAt)}'
                      : 'None',
                ),
              ],
            ),
          ),
          if (_locationNotice != null) ...[
            const SizedBox(height: 14),
            InlineMessage.warning(
              message: _locationNotice!,
              onDismiss: () => setState(() => _locationNotice = null),
            ),
          ],
          const SizedBox(height: 14),
          if (open == null)
            SectionCard(
              title: 'Start the visit',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tapping start records the time you arrived. If you allow '
                    'location access, the visit is also stamped with your '
                    'coordinates so it counts as location-supported rather than '
                    'self-reported. You can decline and still record the visit.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _startVisit,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(_busy ? 'Starting…' : 'Start visit'),
                  ),
                ],
              ),
            )
          else ...[
            VisitTile(visit: open),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Finish the visit',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _notes,
                    label: 'Visit notes',
                    hint: 'What did you discuss? What happens next?',
                    maxLines: 4,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 12),
                  AppDateField(
                    value: _nextFollowUpAt,
                    label: 'Next follow-up (optional)',
                    includeTime: true,
                    enabled: !_busy,
                    onChanged: (value) => setState(() => _nextFollowUpAt = value),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _finishVisit,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Complete visit'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _cancelVisit,
                    child: const Text('Cancel this visit'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
