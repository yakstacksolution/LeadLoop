import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../../../shared/widgets/map_tiles.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../employees/domain/repositories/employee_repository.dart';
import '../../../projects/domain/repositories/project_repository.dart';
import '../../domain/entities/venue.dart';
import '../../domain/repositories/venue_repository.dart';
import '../bloc/venue_form_cubit.dart';
import 'location_picker_page.dart';

class VenueFormPage extends StatelessWidget {
  const VenueFormPage({super.key, this.venueId});

  /// Null when creating a new venue.
  final String? venueId;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthCubit>().state;

    return BlocProvider(
      create: (_) => VenueFormCubit(
        venueRepository: sl<VenueRepository>(),
        projectRepository: sl<ProjectRepository>(),
        employeeRepository: sl<EmployeeRepository>(),
        currentUserId: auth.uid ?? '',
        isAdmin: auth.isAdmin,
      )..initialise(venueId: venueId),
      child: _VenueFormView(venueId: venueId),
    );
  }
}

class _VenueFormView extends StatefulWidget {
  const _VenueFormView({this.venueId});

  final String? venueId;

  @override
  State<_VenueFormView> createState() => _VenueFormViewState();
}

class _VenueFormViewState extends State<_VenueFormView> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _area = TextEditingController();
  final _courts = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();

  String? _projectId;
  String? _assigneeId;
  VenueType _venueType = VenueType.other;
  LeadSource _leadSource = LeadSource.fieldVisit;
  VenuePriority _priority = VenuePriority.medium;
  LeadStatus _status = LeadStatus.newLead;
  DateTime? _nextFollowUpAt;

  /// Guards against re-seeding the controllers on every rebuild once the
  /// venue being edited has loaded.
  bool _seeded = false;

  /// Typing coordinates by hand is the fallback, not the default, so the
  /// number fields stay collapsed until asked for.
  bool _manualCoords = false;
  bool _locating = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _city,
      _area,
      _courts,
      _latitude,
      _longitude,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _seed(VenueFormState state) {
    if (_seeded) return;

    final venue = state.venue;
    if (venue != null) {
      _name.text = venue.name;
      _address.text = venue.address;
      _city.text = venue.city;
      _area.text = venue.area;
      _courts.text = venue.courtCount?.toString() ?? '';
      _latitude.text = venue.latitude?.toString() ?? '';
      _longitude.text = venue.longitude?.toString() ?? '';
      _projectId = venue.projectId;
      _assigneeId = venue.assignedEmployeeId;
      _venueType = venue.venueType;
      _leadSource = venue.leadSource;
      _priority = venue.priority;
      _status = venue.status;
      _nextFollowUpAt = venue.nextFollowUpAt;
    } else if (state.projects.length == 1) {
      // With exactly one project there is nothing to choose, so preselect it.
      _projectId = state.projects.first.id;
    }

    _seeded = true;
  }

  /// Opens the map picker, seeded with whatever the form already knows.
  Future<void> _pickOnMap() async {
    FocusScope.of(context).unfocus();

    final query = [_name.text.trim(), _area.text.trim(), _city.text.trim()]
        .where((part) => part.isNotEmpty)
        .join(', ');

    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLatitude: double.tryParse(_latitude.text.trim()),
          initialLongitude: double.tryParse(_longitude.text.trim()),
          initialQuery: query.isEmpty ? null : query,
        ),
      ),
    );

    if (picked == null || !mounted) return;
    _applyCoordinates(picked.latitude, picked.longitude, address: picked.address);
  }

  /// Takes the device's own fix — the common case when the employee is
  /// standing at the venue.
  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final outcome = await sl<LocationService>().getCurrentPosition();
    if (!mounted) return;
    setState(() => _locating = false);

    switch (outcome) {
      case LocationFixed(:final latitude, :final longitude):
        _applyCoordinates(latitude, longitude);
      case LocationUnavailable(:final reason):
        context.showError(reason);
    }
  }

  void _applyCoordinates(double lat, double lng, {String? address}) {
    setState(() {
      _latitude.text = lat.toStringAsFixed(6);
      _longitude.text = lng.toStringAsFixed(6);
      // A blank address field is filled from the map, but anything the user
      // typed is left alone — their wording is usually better than the
      // geocoder's.
      if (address != null && _address.text.trim().isEmpty) {
        _address.text = address;
      }
    });
    context.showSuccess('Location set.');
  }

  Future<void> _submit(VenueFormState state) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_projectId == null) {
      context.showError('Choose a project for this venue.');
      return;
    }

    FocusScope.of(context).unfocus();
    final auth = context.read<AuthCubit>().state;
    final existing = state.venue;

    final venue = Venue(
      id: existing?.id ?? '',
      name: _name.text.trim(),
      address: _address.text.trim(),
      city: _city.text.trim(),
      area: _area.text.trim(),
      latitude: double.tryParse(_latitude.text.trim()),
      longitude: double.tryParse(_longitude.text.trim()),
      courtCount: int.tryParse(_courts.text.trim()),
      venueType: _venueType,
      leadSource: _leadSource,
      priority: _priority,
      // Status changes go through the guarded `changeStatus` path so history
      // is always written; the create form only sets the opening status.
      status: existing?.status ?? _status,
      // Whoever the admin picked; for an employee there is no choice, and
      // the rules only accept their own uid anyway.
      assignedEmployeeId:
          _assigneeId ?? existing?.assignedEmployeeId ?? auth.uid ?? '',
      projectId: _projectId!,
      nextFollowUpAt: _nextFollowUpAt,
      createdBy: existing?.createdBy,
    );

    final id = await context.read<VenueFormCubit>().submit(venue);
    if (!mounted) return;

    final failure = context.read<VenueFormCubit>().state.failure;
    if (failure != null) {
      context.showError(failure);
      return;
    }

    context.showSuccess(existing == null ? 'Venue created.' : 'Venue updated.');

    if (existing == null && id != null) {
      context.pushReplacement(AppRoutes.venueDetailFor(id));
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VenueFormCubit, VenueFormState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Scaffold(body: LoadingView());
        }

        if (state.status == VenueFormStatus.failure && state.venue == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Venue')),
            body: ErrorView(
              failure: state.failure!,
              onRetry: () => context
                  .read<VenueFormCubit>()
                  .initialise(venueId: widget.venueId),
            ),
          );
        }

        _seed(state);

        if (state.hasNoProjects) {
          return Scaffold(
            appBar: AppBar(title: const Text('Add venue')),
            body: const EmptyView(
              icon: Icons.folder_off_outlined,
              title: 'No active project',
              message: 'You need to be assigned to an active project before you '
                  'can add venues. Ask your administrator to assign you.',
            ),
          );
        }

        final busy = state.isSubmitting;

        return Scaffold(
          appBar: AppBar(
            title: Text(state.isEditing ? 'Edit venue' : 'Add venue'),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                SectionCard(
                  title: 'Venue details',
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _name,
                        label: 'Venue name',
                        prefixIcon: Icons.stadium_outlined,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            Validators.minLength(value, 2, 'Venue name'),
                        enabled: !busy,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _address,
                        label: 'Address',
                        prefixIcon: Icons.place_outlined,
                        maxLines: 2,
                        validator: (value) => Validators.required(value, 'Address'),
                        enabled: !busy,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _city,
                              label: 'City / municipality',
                              enabled: !busy,
                              validator: (value) =>
                                  Validators.required(value, 'City'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _area,
                              label: 'Area',
                              enabled: !busy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _courts,
                              label: 'Courts',
                              keyboardType: TextInputType.number,
                              validator: Validators.courtCount,
                              enabled: !busy,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppDropdownField<VenueType>(
                              value: _venueType,
                              label: 'Type',
                              items: VenueType.values,
                              itemLabel: (type) => type.label,
                              enabled: !busy,
                              onChanged: (value) =>
                                  setState(() => _venueType = value ?? _venueType),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Lead information',
                  child: Column(
                    children: [
                      AppDropdownField<String>(
                        value: _projectId,
                        label: 'Project',
                        items: state.projects.map((p) => p.id).toList(),
                        itemLabel: (id) => state.projects
                            .firstWhere((p) => p.id == id)
                            .name,
                        // Moving a venue between projects would change who can
                        // see it, so it is an admin reassignment, not an edit.
                        enabled: !busy && !state.isEditing,
                        validator: (value) =>
                            value == null ? 'Choose a project.' : null,
                        onChanged: (value) => setState(() => _projectId = value),
                      ),
                      if (state.employees.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        // Without this an admin's venues stay assigned to the
                        // admin, and every employee's "My venues" is empty.
                        AppDropdownField<String>(
                          value: _assigneeId ??
                              context.read<AuthCubit>().state.uid,
                          label: 'Assigned to',
                          items: state.employees.map((e) => e.id).toList(),
                          itemLabel: (id) => state.employees
                              .firstWhere(
                                (e) => e.id == id,
                                orElse: () => state.employees.first,
                              )
                              .fullName,
                          prefixIcon: Icons.person_outline,
                          enabled: !busy,
                          validator: (value) =>
                              value == null ? 'Choose who owns this venue.' : null,
                          onChanged: (value) =>
                              setState(() => _assigneeId = value),
                        ),
                      ],
                      const SizedBox(height: 12),
                      AppDropdownField<LeadSource>(
                        value: _leadSource,
                        label: 'Lead source',
                        items: LeadSource.values,
                        itemLabel: (source) => source.label,
                        enabled: !busy,
                        onChanged: (value) =>
                            setState(() => _leadSource = value ?? _leadSource),
                      ),
                      const SizedBox(height: 12),
                      AppDropdownField<VenuePriority>(
                        value: _priority,
                        label: 'Priority',
                        items: VenuePriority.values,
                        itemLabel: (priority) => priority.label,
                        enabled: !busy,
                        onChanged: (value) =>
                            setState(() => _priority = value ?? _priority),
                      ),
                      if (!state.isEditing) ...[
                        const SizedBox(height: 12),
                        AppDropdownField<LeadStatus>(
                          value: _status,
                          label: 'Starting status',
                          items: LeadStatus.values,
                          itemLabel: (status) => status.label,
                          enabled: !busy,
                          onChanged: (value) =>
                              setState(() => _status = value ?? _status),
                        ),
                      ],
                      const SizedBox(height: 12),
                      AppDateField(
                        value: _nextFollowUpAt,
                        label: 'Next follow-up (optional)',
                        includeTime: true,
                        enabled: !busy,
                        onChanged: (value) =>
                            setState(() => _nextFollowUpAt = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _LocationSection(
                  latitude: _latitude,
                  longitude: _longitude,
                  enabled: !busy,
                  showManualFields: _manualCoords,
                  onToggleManual: () =>
                      setState(() => _manualCoords = !_manualCoords),
                  onPickOnMap: _pickOnMap,
                  onUseCurrentLocation: _useCurrentLocation,
                  onClear: () => setState(() {
                    _latitude.clear();
                    _longitude.clear();
                  }),
                  locating: _locating,
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: busy ? null : () => _submit(state),
                  child: busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(state.isEditing ? 'Save changes' : 'Create venue'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


/// The "Location" card on the venue form.
///
/// Coordinates are set from the map first and typed by hand only as a
/// fallback: staff read venue locations off Google Maps, not off latitude
/// pairs, and a pin on a preview catches a wrong number at a glance.
class _LocationSection extends StatelessWidget {
  const _LocationSection({
    required this.latitude,
    required this.longitude,
    required this.enabled,
    required this.showManualFields,
    required this.onToggleManual,
    required this.onPickOnMap,
    required this.onUseCurrentLocation,
    required this.onClear,
    required this.locating,
  });

  final TextEditingController latitude;
  final TextEditingController longitude;
  final bool enabled;
  final bool showManualFields;
  final VoidCallback onToggleManual;
  final Future<void> Function() onPickOnMap;
  final Future<void> Function() onUseCurrentLocation;
  final VoidCallback onClear;
  final bool locating;

  @override
  Widget build(BuildContext context) {
    // Listens to both controllers so the preview tracks hand-typed edits too.
    return AnimatedBuilder(
      animation: Listenable.merge([latitude, longitude]),
      builder: (context, _) {
        final lat = double.tryParse(latitude.text.trim());
        final lng = double.tryParse(longitude.text.trim());
        final hasPoint =
            lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180;

        return SectionCard(
          title: 'Location (optional)',
          action: hasPoint
              ? TextButton.icon(
                  onPressed: enabled ? onClear : null,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    visualDensity: VisualDensity.compact,
                  ),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasPoint) ...[
                MapPreview(
                  latitude: lat,
                  longitude: lng,
                  onTap: enabled ? onPickOnMap : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ] else ...[
                const _LocationPlaceholder(),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: enabled ? onPickOnMap : null,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: Text(hasPoint ? 'Change on map' : 'Search on map'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _CurrentLocationButton(
                    busy: locating,
                    onPressed: enabled && !locating ? onUseCurrentLocation : null,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: enabled ? onToggleManual : null,
                  icon: Icon(
                    showManualFields ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(
                    showManualFields
                        ? 'Hide manual entry'
                        : 'Enter coordinates manually',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: showManualFields
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: latitude,
                                label: 'Latitude',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                                validator: Validators.latitude,
                                enabled: enabled,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppTextField(
                                controller: longitude,
                                label: 'Longitude',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                                validator: Validators.longitude,
                                enabled: enabled,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LocationPlaceholder extends StatelessWidget {
  const _LocationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 26, color: AppColors.textMuted),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'Search for the venue on the map, or drop a pin where it is.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentLocationButton extends StatelessWidget {
  const _CurrentLocationButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Use my current location',
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(52, 48),
          padding: EdgeInsets.zero,
        ),
        child: busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : const Icon(Icons.my_location, size: 20),
      ),
    );
  }
}
