import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/choice_chips.dart';
import '../../../../shared/widgets/form_fields.dart';
import '../../domain/entities/venue_filter.dart';

/// Bottom sheet for narrowing the venue list.
///
/// Returns the new filter, or null if dismissed without applying.
Future<VenueFilter?> showVenueFilterSheet(
  BuildContext context, {
  required VenueFilter current,
}) {
  return showModalBottomSheet<VenueFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _VenueFilterSheet(current: current),
  );
}

class _VenueFilterSheet extends StatefulWidget {
  const _VenueFilterSheet({required this.current});

  final VenueFilter current;

  @override
  State<_VenueFilterSheet> createState() => _VenueFilterSheetState();
}

class _VenueFilterSheetState extends State<_VenueFilterSheet> {
  late VenueFilter _draft = widget.current;
  late final TextEditingController _areaController = TextEditingController(
    text: widget.current.area ?? '',
  );

  /// The four statuses worth one tap. The rest live behind "More", because
  /// eleven chips is a wall, not a choice.
  static const _commonStatuses = [
    LeadStatus.newLead,
    LeadStatus.contacted,
    LeadStatus.interested,
    LeadStatus.converted,
  ];

  bool _showAllStatuses = false;

  @override
  void initState() {
    super.initState();
    // An uncommon status was already chosen, so the full set has to be open
    // or the current selection would be invisible.
    _showAllStatuses = _draft.status != null &&
        !_commonStatuses.contains(_draft.status);
  }

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
  }

  /// What the Apply button would actually hand back.
  VenueFilter get _pending =>
      _draft.copyWith(area: _areaController.text.trim());

  /// How many narrowing choices are set, for the header count and to know
  /// whether "Clear" has anything to do.
  int get _activeCount {
    final filter = _pending;
    return [
      filter.status != null,
      filter.priority != null,
      (filter.area?.trim().isNotEmpty ?? false),
      filter.includeArchived,
      filter.sort != VenueSort.lastActivity,
    ].where((set) => set).length;
  }

  void _clear() {
    setState(() {
      _areaController.clear();
      // Scope — the project and the employee whose list this is — is not a
      // filter the user picked, so clearing must not drop it.
      _draft = VenueFilter(
        projectId: widget.current.projectId,
        assignedEmployeeId: widget.current.assignedEmployeeId,
        searchTerm: widget.current.searchTerm,
      );
      _showAllStatuses = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final statuses =
        _showAllStatuses ? LeadStatus.values : _commonStatuses;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filter venues',
                      style: TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_activeCount > 0)
                    TextButton.icon(
                      onPressed: _clear,
                      icon: const Icon(Icons.close, size: 16),
                      label: Text('Clear ($_activeCount)'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              const SectionHeading(title: 'Lead status'),
              AppChoiceChips<LeadStatus?>(
                values: [null, ...statuses],
                selected: _draft.status,
                labelOf: (status) => status?.label ?? 'Any',
                // Each status keeps its pipeline colour, so the chips read the
                // same as the chips on the venue cards.
                colorOf: (status) => status == null
                    ? AppColors.primary
                    : AppColors.forLeadStatus(status),
                onSelected: (status) => setState(() {
                  _draft = status == null
                      ? _draft.copyWith(clearStatus: true)
                      : _draft.copyWith(status: status);
                }),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(
                    () => _showAllStatuses = !_showAllStatuses,
                  ),
                  icon: Icon(
                    _showAllStatuses ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
                  label: Text(
                    _showAllStatuses
                        ? 'Fewer statuses'
                        : 'All ${LeadStatus.values.length} statuses',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              const SectionHeading(title: 'Priority'),
              AppChoiceChips<VenuePriority?>(
                values: const [null, ...VenuePriority.values],
                selected: _draft.priority,
                labelOf: (priority) => priority?.label ?? 'Any',
                iconOf: (priority) =>
                    priority == null ? null : Icons.flag_outlined,
                colorOf: (priority) => priority == null
                    ? AppColors.primary
                    : AppColors.forPriority(priority),
                onSelected: (priority) => setState(() {
                  _draft = priority == null
                      ? _draft.copyWith(clearPriority: true)
                      : _draft.copyWith(priority: priority);
                }),
              ),
              const SizedBox(height: 18),

              const SectionHeading(title: 'Area'),
              AppTextField(
                controller: _areaController,
                label: 'Area or city',
                hint: 'e.g. Baneshwor',
                prefixIcon: Icons.place_outlined,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),

              const SectionHeading(title: 'Sort by'),
              AppChoiceChips<VenueSort>(
                values: VenueSort.values,
                selected: _draft.sort,
                labelOf: (sort) => sort.label,
                pill: true,
                onSelected: (sort) =>
                    setState(() => _draft = _draft.copyWith(sort: sort)),
              ),
              const SizedBox(height: 14),

              _ArchivedToggle(
                value: _draft.includeArchived,
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(includeArchived: value),
                ),
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
                      onPressed: () => Navigator.of(context).pop(_pending),
                      icon: const Icon(Icons.filter_list, size: 18),
                      label: Text(
                        _activeCount == 0
                            ? 'Show all venues'
                            : 'Apply $_activeCount '
                                '${_activeCount == 1 ? 'filter' : 'filters'}',
                      ),
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

class _ArchivedToggle extends StatelessWidget {
  const _ArchivedToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: value
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.outline,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
      // ListTile paints its ink on the nearest Material; without this one the
      // container's background would hide it.
      child: Material(
        type: MaterialType.transparency,
        child: SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: value,
          activeThumbColor: AppColors.primary,
          title: const Text(
            'Include archived venues',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Archived venues are hidden by default.',
            style: TextStyle(fontSize: 11.5),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
