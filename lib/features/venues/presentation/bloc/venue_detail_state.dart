part of 'venue_detail_cubit.dart';

enum VenueDetailStatus { initial, loading, success, notFound, failure }

class VenueDetailState extends Equatable {
  VenueDetailState({
    this.status = VenueDetailStatus.initial,
    this.venue,
    this.notes = const [],
    this.statusHistory = const [],
    this.activities = const [],
    this.visits = const [],
    this.contacts = const [],
    this.isSubmitting = false,
    this.failure,
  });

  final VenueDetailStatus status;
  final Venue? venue;
  final List<VenueNote> notes;
  final List<StatusChange> statusHistory;
  final List<Activity> activities;
  final List<Visit> visits;
  final List<VenueContact> contacts;
  final bool isSubmitting;
  final Failure? failure;

  bool get isLoading =>
      status == VenueDetailStatus.loading ||
      status == VenueDetailStatus.initial;

  late final List<TimelineEntry> timeline = TimelineEntry.merge(
    notes: notes,
    statusChanges: statusHistory,
    activities: activities,
    visits: visits,
  );

  late final List<Activity> openActivities = activities
      .where((a) => a.status.isOpen)
      .toList();

  /// The contact to call first, shown on the Overview tab.
  VenueContact? get primaryContact {
    for (final contact in contacts) {
      if (contact.isPrimary) return contact;
    }
    return contacts.isEmpty ? null : contacts.first;
  }

  Visit? get openVisit {
    for (final visit in visits) {
      if (visit.isOpen) return visit;
    }
    return null;
  }

  VenueDetailState copyWith({
    VenueDetailStatus? status,
    Venue? venue,
    List<VenueNote>? notes,
    List<StatusChange>? statusHistory,
    List<Activity>? activities,
    List<Visit>? visits,
    List<VenueContact>? contacts,
    bool? isSubmitting,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return VenueDetailState(
      status: status ?? this.status,
      venue: venue ?? this.venue,
      notes: notes ?? this.notes,
      statusHistory: statusHistory ?? this.statusHistory,
      activities: activities ?? this.activities,
      visits: visits ?? this.visits,
      contacts: contacts ?? this.contacts,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
    status,
    venue,
    notes,
    statusHistory,
    activities,
    visits,
    contacts,
    isSubmitting,
    failure,
  ];
}
