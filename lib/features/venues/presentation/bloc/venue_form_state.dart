part of 'venue_form_cubit.dart';

enum VenueFormStatus { initial, loading, ready, saved, failure }

class VenueFormState extends Equatable {
  const VenueFormState({
    this.status = VenueFormStatus.initial,
    this.projects = const [],
    this.employees = const [],
    this.venue,
    this.isSubmitting = false,
    this.failure,
  });

  final VenueFormStatus status;

  /// Projects the current user may file a venue under.
  final List<Project> projects;

  /// Active employees a venue can be assigned to. Empty for a non-admin: an
  /// employee's venues are always their own.
  final List<AppUser> employees;

  /// The venue being edited, or null when creating.
  final Venue? venue;
  final bool isSubmitting;
  final Failure? failure;

  bool get isLoading =>
      status == VenueFormStatus.loading || status == VenueFormStatus.initial;

  bool get isEditing => venue != null;

  /// Nothing can be filed without a project, so the form says so rather than
  /// presenting an empty dropdown.
  bool get hasNoProjects => status == VenueFormStatus.ready && projects.isEmpty;

  VenueFormState copyWith({
    VenueFormStatus? status,
    List<Project>? projects,
    List<AppUser>? employees,
    Venue? venue,
    bool? isSubmitting,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return VenueFormState(
      status: status ?? this.status,
      projects: projects ?? this.projects,
      employees: employees ?? this.employees,
      venue: venue ?? this.venue,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props =>
      [status, projects, employees, venue, isSubmitting, failure];
}
