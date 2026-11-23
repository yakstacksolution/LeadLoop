import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/app_date_utils.dart';

/// A record that an employee went to a venue.
///
/// Honesty about evidence is deliberate. Marking a button does not prove a
/// visit, so every visit carries [isSelfReported]: false only when the device
/// actually returned coordinates at the moment the visit was opened. The UI
/// labels the two cases differently and the security rules forbid rewriting
/// the flag after the fact.
class Visit extends Equatable {
  const Visit({
    required this.id,
    required this.venueId,
    required this.projectId,
    required this.assignedEmployeeId,
    required this.employeeId,
    required this.status,
    required this.startAt,
    this.venueName = '',
    this.activityId,
    this.endAt,
    this.latitude,
    this.longitude,
    this.locationAccuracy,
    this.notes = '',
    this.isSelfReported = true,
    this.nextFollowUpAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String venueId;
  final String venueName;
  final String projectId;

  /// The parent venue's assignee, for query-matchable scoping. Usually the
  /// same person as [employeeId], but an admin may log a visit too.
  final String assignedEmployeeId;
  final String employeeId;
  final String? activityId;
  final DateTime startAt;
  final DateTime? endAt;
  final VisitStatus status;
  final double? latitude;
  final double? longitude;

  /// Metres of uncertainty reported by the device, kept so an admin can judge
  /// how much the coordinates are worth.
  final double? locationAccuracy;
  final String notes;

  /// True when no location backed the record — the default.
  final bool isSelfReported;
  final DateTime? nextFollowUpAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasLocation => latitude != null && longitude != null;

  /// Only a visit with coordinates counts as location-supported.
  bool get isLocationSupported => !isSelfReported && hasLocation;

  String get evidenceLabel =>
      isLocationSupported ? 'Location-supported' : 'Self-reported';

  bool get isOpen => status == VisitStatus.inProgress;
  bool get isFinished => status == VisitStatus.completed;

  Duration? get duration {
    if (endAt == null) return null;
    final span = endAt!.difference(startAt);
    return span.isNegative ? null : span;
  }

  String? get durationLabel => AppDateUtils.formatDuration(startAt, endAt);

  Visit copyWith({
    VisitStatus? status,
    DateTime? endAt,
    String? notes,
    DateTime? nextFollowUpAt,
    double? latitude,
    double? longitude,
    double? locationAccuracy,
    bool clearNextFollowUp = false,
  }) {
    return Visit(
      id: id,
      venueId: venueId,
      venueName: venueName,
      projectId: projectId,
      assignedEmployeeId: assignedEmployeeId,
      employeeId: employeeId,
      activityId: activityId,
      startAt: startAt,
      endAt: endAt ?? this.endAt,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      notes: notes ?? this.notes,
      isSelfReported: isSelfReported,
      nextFollowUpAt: clearNextFollowUp ? null : (nextFollowUpAt ?? this.nextFollowUpAt),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        venueId,
        venueName,
        projectId,
        assignedEmployeeId,
        employeeId,
        activityId,
        startAt,
        endAt,
        status,
        latitude,
        longitude,
        locationAccuracy,
        notes,
        isSelfReported,
        nextFollowUpAt,
        createdAt,
        updatedAt,
      ];
}
