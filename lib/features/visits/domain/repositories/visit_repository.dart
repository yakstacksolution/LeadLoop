import '../../../../core/errors/result.dart';
import '../entities/visit.dart';

abstract interface class VisitRepository {
  /// Visits to one venue. [assignedEmployeeId] is the venue's assignee —
  /// required so the query satisfies the employee `list` rule.
  Stream<List<Visit>> watchForVenue(
    String venueId, {
    required String assignedEmployeeId,
    int limit,
  });

  Stream<List<Visit>> watchForEmployee(String employeeId, {int limit});

  Stream<List<Visit>> watchForProject(String projectId, {int limit});

  /// The employee's currently open visit, if any. Used to stop them starting
  /// a second one and to offer "finish visit" from the dashboard.
  Future<Result<Visit?>> findOpenVisit(String employeeId);

  Stream<Visit?> watchVisit(String visitId);

  /// Opens a visit. [latitude]/[longitude] are null when the employee declined
  /// location or no fix was available; the record is then self-reported.
  Future<Result<String>> startVisit(Visit visit);

  Future<Result<void>> completeVisit({
    required Visit visit,
    required String notes,
    DateTime? nextFollowUpAt,
  });

  Future<Result<void>> cancelVisit(Visit visit, {String reason = ''});

  Future<Result<int>> countVisits({
    String? employeeId,
    String? projectId,
    String? venueId,
    DateTime? since,
  });
}
