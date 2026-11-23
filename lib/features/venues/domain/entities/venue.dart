import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/app_date_utils.dart';

/// A futsal venue being worked as a lead.
class Venue extends Equatable {
  const Venue({
    required this.id,
    required this.name,
    required this.projectId,
    required this.assignedEmployeeId,
    required this.status,
    required this.priority,
    this.address = '',
    this.city = '',
    this.area = '',
    this.latitude,
    this.longitude,
    this.courtCount,
    this.venueType = VenueType.other,
    this.leadSource = LeadSource.other,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.lastActivityAt,
    this.nextFollowUpAt,
    this.nextFollowUpType,
    this.lastVisitedAt,
    this.visitCount = 0,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final String area;
  final double? latitude;
  final double? longitude;
  final int? courtCount;
  final VenueType venueType;
  final LeadSource leadSource;
  final VenuePriority priority;
  final LeadStatus status;
  final String assignedEmployeeId;
  final String projectId;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastActivityAt;
  final DateTime? nextFollowUpAt;
  final ActivityType? nextFollowUpType;

  /// Denormalised from the visits collection so the venue list can show
  /// "visited / not visited" without an extra query per row.
  final DateTime? lastVisitedAt;
  final int visitCount;
  final bool isArchived;

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasBeenVisited => visitCount > 0 || lastVisitedAt != null;

  /// A venue is chaseable unless the lead is already won or lost.
  bool get needsFollowUp => !status.isClosed && nextFollowUpAt != null;

  bool get isFollowUpOverdue =>
      needsFollowUp && AppDateUtils.isOverdue(nextFollowUpAt);

  bool get isFollowUpToday =>
      needsFollowUp && AppDateUtils.isToday(nextFollowUpAt);

  /// "Baneshwor, Kathmandu" — whichever parts exist.
  String get locationLabel =>
      [area, city].where((part) => part.trim().isNotEmpty).join(', ');

  Venue copyWith({
    String? name,
    String? address,
    String? city,
    String? area,
    double? latitude,
    double? longitude,
    int? courtCount,
    VenueType? venueType,
    LeadSource? leadSource,
    VenuePriority? priority,
    LeadStatus? status,
    String? assignedEmployeeId,
    String? projectId,
    DateTime? lastActivityAt,
    DateTime? nextFollowUpAt,
    ActivityType? nextFollowUpType,
    DateTime? lastVisitedAt,
    int? visitCount,
    bool? isArchived,
    bool clearNextFollowUp = false,
    bool clearLocation = false,
  }) {
    return Venue(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      area: area ?? this.area,
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      courtCount: courtCount ?? this.courtCount,
      venueType: venueType ?? this.venueType,
      leadSource: leadSource ?? this.leadSource,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assignedEmployeeId: assignedEmployeeId ?? this.assignedEmployeeId,
      projectId: projectId ?? this.projectId,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      nextFollowUpAt: clearNextFollowUp ? null : (nextFollowUpAt ?? this.nextFollowUpAt),
      nextFollowUpType:
          clearNextFollowUp ? null : (nextFollowUpType ?? this.nextFollowUpType),
      lastVisitedAt: lastVisitedAt ?? this.lastVisitedAt,
      visitCount: visitCount ?? this.visitCount,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        city,
        area,
        latitude,
        longitude,
        courtCount,
        venueType,
        leadSource,
        priority,
        status,
        assignedEmployeeId,
        projectId,
        createdBy,
        createdAt,
        updatedAt,
        lastActivityAt,
        nextFollowUpAt,
        nextFollowUpType,
        lastVisitedAt,
        visitCount,
        isArchived,
      ];
}
