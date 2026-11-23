import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import 'venue.dart';

/// How a venue list is narrowed and ordered.
///
/// Firestore cannot combine arbitrary predicates, so the split is explicit:
/// [projectId] / [assignedEmployeeId] / [status] are pushed into the query
/// (they have composite indexes), while [priority], [area] and [searchTerm]
/// are applied in memory to the fetched page. That trade is documented in the
/// README's "search limitations" section.
class VenueFilter extends Equatable {
  const VenueFilter({
    this.projectId,
    this.assignedEmployeeId,
    this.status,
    this.priority,
    this.area,
    this.searchTerm = '',
    this.sort = VenueSort.lastActivity,
    this.includeArchived = false,
  });

  final String? projectId;
  final String? assignedEmployeeId;
  final LeadStatus? status;
  final VenuePriority? priority;
  final String? area;
  final String searchTerm;
  final VenueSort sort;
  final bool includeArchived;

  /// True when anything beyond the default scope is applied — drives the
  /// "clear filters" affordance.
  bool get hasClientFilters =>
      priority != null || (area?.trim().isNotEmpty ?? false) || searchTerm.trim().isNotEmpty;

  bool get isEmpty =>
      projectId == null &&
      assignedEmployeeId == null &&
      status == null &&
      !hasClientFilters &&
      !includeArchived;

  /// Whether [venue] belongs in a list built with this filter.
  ///
  /// Used two ways: the repository applies it to a fetched page, and the list
  /// cubit applies it to a single venue that changed under it — a lead moved
  /// to "Converted" drops out of a "Contacted" list without a re-query.
  bool matches(Venue venue) {
    if (!includeArchived && venue.isArchived) return false;
    if (status != null && venue.status != status) return false;
    if (priority != null && venue.priority != priority) return false;

    final areaTerm = area?.trim().toLowerCase();
    if (areaTerm != null && areaTerm.isNotEmpty) {
      if (!venue.area.toLowerCase().contains(areaTerm) &&
          !venue.city.toLowerCase().contains(areaTerm)) {
        return false;
      }
    }

    final term = searchTerm.trim().toLowerCase();
    if (term.isNotEmpty) {
      final haystack =
          '${venue.name} ${venue.address} ${venue.area} ${venue.city}'
              .toLowerCase();
      if (!haystack.contains(term)) return false;
    }

    return true;
  }

  VenueFilter copyWith({
    String? projectId,
    String? assignedEmployeeId,
    LeadStatus? status,
    VenuePriority? priority,
    String? area,
    String? searchTerm,
    VenueSort? sort,
    bool? includeArchived,
    bool clearProject = false,
    bool clearEmployee = false,
    bool clearStatus = false,
    bool clearPriority = false,
    bool clearArea = false,
  }) {
    return VenueFilter(
      projectId: clearProject ? null : (projectId ?? this.projectId),
      assignedEmployeeId:
          clearEmployee ? null : (assignedEmployeeId ?? this.assignedEmployeeId),
      status: clearStatus ? null : (status ?? this.status),
      priority: clearPriority ? null : (priority ?? this.priority),
      area: clearArea ? null : (area ?? this.area),
      searchTerm: searchTerm ?? this.searchTerm,
      sort: sort ?? this.sort,
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }

  @override
  List<Object?> get props => [
        projectId,
        assignedEmployeeId,
        status,
        priority,
        area,
        searchTerm,
        sort,
        includeArchived,
      ];
}

enum VenueSort {
  lastActivity('Last activity', 'lastActivityAt', true),
  newest('Newest first', 'createdAt', true),
  nextFollowUp('Next follow-up', 'nextFollowUpAt', false),
  name('Venue name', 'name', false);

  const VenueSort(this.label, this.field, this.descending);
  final String label;
  final String field;
  final bool descending;
}
