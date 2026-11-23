import 'package:equatable/equatable.dart';

import '../../../../core/constants/enums.dart';

/// A person at a venue: owner, manager, receptionist and so on.
///
/// Stored in its own top-level collection rather than inside the venue
/// document, so a venue with many contacts never grows an unbounded array and
/// each contact can be queried and secured on its own.
class VenueContact extends Equatable {
  const VenueContact({
    required this.id,
    required this.venueId,
    required this.projectId,
    required this.assignedEmployeeId,
    required this.fullName,
    required this.phone,
    this.designation = '',
    this.email = '',
    this.preferredContactMethod = ContactMethod.phone,
    this.notes = '',
    this.isPrimary = false,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String venueId;

  /// Denormalised so a security rule can authorise the contact without
  /// fetching its parent venue.
  final String projectId;

  /// The parent venue's assignee, copied here so employees can query
  /// `where assignedEmployeeId == <me>` — the only scoping predicate
  /// Firestore can match against a list query's filters.
  final String assignedEmployeeId;
  final String fullName;
  final String designation;
  final String phone;
  final String email;
  final ContactMethod preferredContactMethod;
  final String notes;
  final bool isPrimary;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayRole => designation.trim().isEmpty ? 'Contact' : designation.trim();

  VenueContact copyWith({
    String? fullName,
    String? designation,
    String? phone,
    String? email,
    ContactMethod? preferredContactMethod,
    String? notes,
    bool? isPrimary,
  }) {
    return VenueContact(
      id: id,
      venueId: venueId,
      projectId: projectId,
      assignedEmployeeId: assignedEmployeeId,
      fullName: fullName ?? this.fullName,
      designation: designation ?? this.designation,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      preferredContactMethod: preferredContactMethod ?? this.preferredContactMethod,
      notes: notes ?? this.notes,
      isPrimary: isPrimary ?? this.isPrimary,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        venueId,
        projectId,
        assignedEmployeeId,
        fullName,
        designation,
        phone,
        email,
        preferredContactMethod,
        notes,
        isPrimary,
        createdBy,
        createdAt,
        updatedAt,
      ];
}
