import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../employees/domain/repositories/employee_repository.dart';
import '../../../projects/domain/entities/project.dart';
import '../../../projects/domain/repositories/project_repository.dart';
import '../../domain/entities/venue.dart';
import '../../domain/repositories/venue_repository.dart';

part 'venue_form_state.dart';

/// Backs both the create and the edit venue forms.
///
/// It owns two things the widget should not: the list of projects the current
/// user may file a venue under, and the submission lifecycle.
class VenueFormCubit extends Cubit<VenueFormState> {
  VenueFormCubit({
    required this.venueRepository,
    required this.projectRepository,
    required this.employeeRepository,
    required this.currentUserId,
    required this.isAdmin,
  }) : super(const VenueFormState());

  final VenueRepository venueRepository;
  final ProjectRepository projectRepository;
  final EmployeeRepository employeeRepository;
  final String currentUserId;
  final bool isAdmin;

  /// Loads the selectable projects and, when editing, the venue itself.
  Future<void> initialise({String? venueId}) async {
    emit(state.copyWith(status: VenueFormStatus.loading, clearFailure: true));

    try {
      final projects = isAdmin
          ? await projectRepository.watchAllProjects().first
          : await projectRepository.watchProjectsForEmployee(currentUserId).first;

      // A venue cannot be filed under a paused, completed or archived project.
      final selectable = projects.where((p) => p.acceptsNewVenues).toList();

      // Who the venue can belong to. Only an admin chooses: an employee's own
      // venues are the only ones they may create, and the rules say so too.
      final employees = isAdmin
          ? (await employeeRepository.watchEmployees().first)
              .where((employee) => employee.isActive)
              .toList()
          : const <AppUser>[];

      Venue? existing;
      if (venueId != null) {
        final result = await venueRepository.getVenue(venueId);
        if (result.isFailure) {
          emit(state.copyWith(
            status: VenueFormStatus.failure,
            failure: result.failureOrNull,
          ));
          return;
        }
        existing = result.valueOrNull;
      }

      emit(state.copyWith(
        status: VenueFormStatus.ready,
        projects: selectable,
        employees: employees,
        venue: existing,
        clearFailure: true,
      ));
    } catch (error) {
      emit(state.copyWith(
        status: VenueFormStatus.failure,
        failure: UnexpectedFailure(error.toString()),
      ));
    }
  }

  Future<String?> submit(Venue venue) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final isEdit = venue.id.isNotEmpty;
    final result = isEdit
        ? await venueRepository.updateVenue(venue)
        : await venueRepository.createVenue(venue, createdBy: currentUserId);

    if (result.isFailure) {
      emit(state.copyWith(isSubmitting: false, failure: result.failureOrNull));
      return null;
    }

    // `updateVenue` deliberately omits `assignedEmployeeId` — handing a venue
    // to someone else also has to move its contacts, activities and visits,
    // which is what `reassign` does.
    final previous = state.venue;
    if (isEdit &&
        previous != null &&
        previous.assignedEmployeeId != venue.assignedEmployeeId) {
      final moved = await venueRepository.reassign(
        venueId: venue.id,
        employeeId: venue.assignedEmployeeId,
      );
      if (moved.isFailure) {
        emit(state.copyWith(isSubmitting: false, failure: moved.failureOrNull));
        return null;
      }
    }

    emit(state.copyWith(isSubmitting: false, status: VenueFormStatus.saved));
    return isEdit ? venue.id : result.valueOrNull as String?;
  }
}
