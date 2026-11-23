import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../activities/domain/entities/activity.dart';
import '../../../activities/domain/repositories/activity_repository.dart';
import '../../../contacts/domain/entities/venue_contact.dart';
import '../../../contacts/domain/repositories/contact_repository.dart';
import '../../../visits/domain/entities/visit.dart';
import '../../../visits/domain/repositories/visit_repository.dart';
import '../../domain/entities/timeline_entry.dart';
import '../../domain/entities/venue.dart';
import '../../domain/entities/venue_note.dart';
import '../../domain/repositories/venue_repository.dart';

part 'venue_detail_state.dart';

/// Streams everything a venue detail screen shows and owns its write actions.
///
/// Four live subscriptions are combined into one timeline. All of them are
/// cancelled in [close] — leaking a Firestore listener costs reads for as long
/// as the app stays open.
class VenueDetailCubit extends Cubit<VenueDetailState> {
  VenueDetailCubit({
    required this.venueRepository,
    required this.activityRepository,
    required this.visitRepository,
    required this.contactRepository,
    required this.venueId,
    required this.currentUserId,
    required this.currentUserName,
  }) : super(VenueDetailState());

  final VenueRepository venueRepository;
  final ActivityRepository activityRepository;
  final VisitRepository visitRepository;
  final ContactRepository contactRepository;
  final String venueId;
  final String currentUserId;
  final String currentUserName;

  StreamSubscription<Venue?>? _venueSub;
  StreamSubscription<List<VenueNote>>? _notesSub;
  StreamSubscription<List<StatusChange>>? _historySub;
  StreamSubscription<List<Activity>>? _activitySub;
  StreamSubscription<List<Visit>>? _visitSub;
  StreamSubscription<List<VenueContact>>? _contactSub;

  /// The assignee the child streams are currently scoped to, so a reassignment
  /// re-subscribes them instead of silently showing an empty timeline.
  String? _childScope;

  void watch() {
    emit(state.copyWith(status: VenueDetailStatus.loading, clearFailure: true));

    _venueSub = venueRepository.watchVenue(venueId).listen(
      (venue) {
        if (venue == null) {
          emit(state.copyWith(
            status: VenueDetailStatus.notFound,
            failure: const NotFoundFailure('That venue no longer exists.'),
          ));
          return;
        }

        emit(state.copyWith(
          status: VenueDetailStatus.success,
          venue: venue,
          clearFailure: true,
        ));

        // Child records are queried by the venue's assignee, which is what
        // makes them readable under the employee list rules. That value is
        // only known once the venue itself has loaded.
        if (_childScope != venue.assignedEmployeeId) {
          _childScope = venue.assignedEmployeeId;
          _watchChildren(venue.assignedEmployeeId);
        }
      },
      onError: _onError,
    );
  }

  void _watchChildren(String assignedEmployeeId) {
    _notesSub?.cancel();
    _historySub?.cancel();
    _activitySub?.cancel();
    _visitSub?.cancel();
    _contactSub?.cancel();

    _notesSub = venueRepository
        .watchNotes(venueId, assignedEmployeeId: assignedEmployeeId)
        .listen((notes) => emit(state.copyWith(notes: notes)), onError: _onError);

    _historySub = venueRepository
        .watchStatusHistory(venueId, assignedEmployeeId: assignedEmployeeId)
        .listen((history) => emit(state.copyWith(statusHistory: history)),
            onError: _onError);

    _activitySub = activityRepository
        .watchForVenue(venueId, assignedEmployeeId: assignedEmployeeId)
        .listen((activities) => emit(state.copyWith(activities: activities)),
            onError: _onError);

    _visitSub = visitRepository
        .watchForVenue(venueId, assignedEmployeeId: assignedEmployeeId)
        .listen((visits) => emit(state.copyWith(visits: visits)),
            onError: _onError);

    _contactSub = contactRepository
        .watchContactsForVenue(venueId, assignedEmployeeId: assignedEmployeeId)
        .listen((contacts) => emit(state.copyWith(contacts: contacts)),
            onError: _onError);
  }

  void _onError(Object error) {
    emit(state.copyWith(
      status: VenueDetailStatus.failure,
      failure: mapError(error),
    ));
  }

  Future<bool> changeStatus(LeadStatus newStatus, {String reason = ''}) async {
    final venue = state.venue;
    if (venue == null) return false;

    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final result = await venueRepository.changeStatus(
      venue: venue,
      newStatus: newStatus,
      changedBy: currentUserId,
      changedByName: currentUserName,
      reason: reason,
    );

    emit(state.copyWith(isSubmitting: false, failure: result.failureOrNull));
    return result.isSuccess;
  }

  Future<bool> addNote(String text) async {
    final venue = state.venue;
    if (venue == null || text.trim().isEmpty) return false;

    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final result = await venueRepository.addNote(
      VenueNote(
        id: '',
        venueId: venue.id,
        projectId: venue.projectId,
        assignedEmployeeId: venue.assignedEmployeeId,
        employeeId: currentUserId,
        employeeName: currentUserName,
        text: text,
      ),
    );

    emit(state.copyWith(isSubmitting: false, failure: result.failureOrNull));
    return result.isSuccess;
  }

  Future<bool> setArchived(bool archived) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));
    final result = await venueRepository.setArchived(venueId, archived);
    emit(state.copyWith(isSubmitting: false, failure: result.failureOrNull));
    return result.isSuccess;
  }

  Future<bool> reassign({required String employeeId}) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));
    final result = await venueRepository.reassign(
      venueId: venueId,
      employeeId: employeeId,
    );
    emit(state.copyWith(isSubmitting: false, failure: result.failureOrNull));
    return result.isSuccess;
  }

  void clearFailure() => emit(state.copyWith(clearFailure: true));

  @override
  Future<void> close() {
    _venueSub?.cancel();
    _notesSub?.cancel();
    _historySub?.cancel();
    _activitySub?.cancel();
    _visitSub?.cancel();
    _contactSub?.cancel();
    return super.close();
  }
}
