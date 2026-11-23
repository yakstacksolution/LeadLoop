import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// An outreach campaign, e.g. "Kathmandu Venue Onboarding".
///
/// A project is the unit of access control: an employee sees exactly the
/// venues, contacts, activities and visits belonging to projects whose
/// `assignedEmployeeIds` contains them.
class Project extends Equatable {
  const Project({
    required this.id,
    required this.name,
    required this.status,
    this.priority = VenuePriority.medium,
    this.description = '',
    this.area = '',
    this.startDate,
    this.endDate,
    this.assignedEmployeeIds = const [],
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String area;
  final DateTime? startDate;
  final DateTime? endDate;
  final ProjectStatus status;

  /// How urgent this campaign is. Shares [VenuePriority] with venues rather
  /// than duplicating a three-value enum — same labels, same colours, one
  /// place to change them.
  final VenuePriority priority;

  final List<String> assignedEmployeeIds;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isArchived => status == ProjectStatus.archived;

  /// Employees may only add new venues to a project that is actually running.
  bool get acceptsNewVenues => status == ProjectStatus.active;

  bool hasEmployee(String uid) => assignedEmployeeIds.contains(uid);

  Project copyWith({
    String? name,
    String? description,
    String? area,
    DateTime? startDate,
    DateTime? endDate,
    ProjectStatus? status,
    VenuePriority? priority,
    List<String>? assignedEmployeeIds,
    bool clearEndDate = false,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      area: area ?? this.area,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedEmployeeIds: assignedEmployeeIds ?? this.assignedEmployeeIds,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        area,
        startDate,
        endDate,
        status,
        priority,
        assignedEmployeeIds,
        createdBy,
        createdAt,
        updatedAt,
      ];
}
