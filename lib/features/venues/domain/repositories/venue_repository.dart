import '../../../../core/constants/enums.dart';
import '../../../../core/errors/result.dart';
import '../entities/venue.dart';
import '../entities/venue_filter.dart';
import '../entities/venue_note.dart';

/// One page of venues plus the cursor needed to ask for the next.
class VenuePage {
  const VenuePage({required this.venues, required this.cursor, required this.hasMore});

  final List<Venue> venues;

  /// Opaque to the domain; the data layer knows it is a Firestore snapshot.
  final Object? cursor;
  final bool hasMore;

  static const empty = VenuePage(venues: [], cursor: null, hasMore: false);
}

abstract interface class VenueRepository {
  /// A page of venues matching [filter]. Pass [cursor] from the previous page
  /// to continue; pass null to start over.
  Future<Result<VenuePage>> fetchVenues({
    required VenueFilter filter,
    Object? cursor,
    int limit,
  });

  Stream<Venue?> watchVenue(String venueId);

  Future<Result<Venue>> getVenue(String venueId);

  Future<Result<String>> createVenue(Venue venue, {required String createdBy});

  Future<Result<void>> updateVenue(Venue venue);

  /// Changes the lead status and appends an immutable history entry in the
  /// same batch, so the two can never disagree.
  Future<Result<void>> changeStatus({
    required Venue venue,
    required LeadStatus newStatus,
    required String changedBy,
    required String changedByName,
    String reason = '',
  });

  /// Admin-only reassignment to another employee, optionally another project.
  Future<Result<void>> reassign({
    required String venueId,
    required String employeeId,
    String? projectId,
  });

  Future<Result<void>> setArchived(String venueId, bool archived);

  /// Sets or clears the venue's next planned follow-up.
  Future<Result<void>> setNextFollowUp({
    required String venueId,
    DateTime? at,
    ActivityType? type,
  });

  /// Both take the venue's [assignedEmployeeId]: employee `list` rules are
  /// matched against query filters, so the scoping must be in the query.
  Stream<List<StatusChange>> watchStatusHistory(
    String venueId, {
    required String assignedEmployeeId,
  });

  Stream<List<VenueNote>> watchNotes(
    String venueId, {
    required String assignedEmployeeId,
    int limit,
  });

  Future<Result<String>> addNote(VenueNote note);

  Future<Result<void>> editNote(VenueNote note, {required String previousText});

  /// Counts venues per lead status within a scope, for the dashboards.
  ///
  /// Uses Firestore's server-side `count()` aggregation, so it never downloads
  /// the documents themselves. Each status costs one round trip, so callers
  /// pass only the statuses they actually display — an empty list means all.
  Future<Result<Map<LeadStatus, int>>> countByStatus({
    String? projectId,
    String? assignedEmployeeId,
    List<LeadStatus> statuses = const [],
  });

  Future<Result<int>> countVenues({String? projectId, String? assignedEmployeeId});

  /// Venues with a follow-up due before [before] that are still open.
  Future<Result<List<Venue>>> fetchDueFollowUps({
    required String assignedEmployeeId,
    required DateTime before,
    int limit,
  });
}
