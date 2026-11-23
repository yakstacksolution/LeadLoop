import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_lead/core/constants/enums.dart';
import 'package:futsal_lead/features/venues/domain/entities/venue.dart';
import 'package:futsal_lead/features/visits/domain/entities/visit.dart';

Venue _venue({
  LeadStatus status = LeadStatus.newLead,
  DateTime? nextFollowUpAt,
  int visitCount = 0,
  DateTime? lastVisitedAt,
  String area = 'Baneshwor',
  String city = 'Kathmandu',
}) {
  return Venue(
    id: 'v1',
    name: 'XYZ Futsal',
    projectId: 'p1',
    assignedEmployeeId: 'e1',
    status: status,
    priority: VenuePriority.medium,
    area: area,
    city: city,
    nextFollowUpAt: nextFollowUpAt,
    visitCount: visitCount,
    lastVisitedAt: lastVisitedAt,
  );
}

void main() {
  group('follow-up state', () {
    test('an overdue follow-up on an open lead needs chasing', () {
      final venue = _venue(
        nextFollowUpAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(venue.needsFollowUp, isTrue);
      expect(venue.isFollowUpOverdue, isTrue);
    });

    test('a won lead never needs chasing, even with a stale date', () {
      final venue = _venue(
        status: LeadStatus.converted,
        nextFollowUpAt: DateTime.now().subtract(const Duration(days: 10)),
      );

      expect(venue.needsFollowUp, isFalse);
      expect(venue.isFollowUpOverdue, isFalse);
    });

    test('a lost lead is treated the same way', () {
      final venue = _venue(
        status: LeadStatus.notInterested,
        nextFollowUpAt: DateTime.now().subtract(const Duration(days: 10)),
      );

      expect(venue.needsFollowUp, isFalse);
    });

    test('no scheduled date means nothing to chase', () {
      expect(_venue().needsFollowUp, isFalse);
    });
  });

  group('visit state', () {
    test('a venue with visits reports as visited', () {
      expect(_venue(visitCount: 2).hasBeenVisited, isTrue);
    });

    test('a venue with no visits reports as not visited', () {
      expect(_venue().hasBeenVisited, isFalse);
    });
  });

  group('locationLabel', () {
    test('joins area and city', () {
      expect(_venue().locationLabel, 'Baneshwor, Kathmandu');
    });

    test('omits the blank part rather than leaving a dangling comma', () {
      expect(_venue(area: '').locationLabel, 'Kathmandu');
      expect(_venue(area: '', city: '').locationLabel, '');
    });
  });

  group('copyWith', () {
    test('clearNextFollowUp really clears it', () {
      final venue = _venue(nextFollowUpAt: DateTime.now());
      expect(venue.copyWith(clearNextFollowUp: true).nextFollowUpAt, isNull);
    });

    test('an untouched field keeps its value', () {
      final venue = _venue();
      expect(venue.copyWith(name: 'New name').projectId, 'p1');
    });
  });

  group('Visit evidence', () {
    Visit visit({required bool selfReported, double? lat}) => Visit(
          id: 'vs1',
          venueId: 'v1',
          projectId: 'p1',
          assignedEmployeeId: 'e1',
          employeeId: 'e1',
          status: VisitStatus.completed,
          startAt: DateTime(2026, 9, 17, 10),
          endAt: DateTime(2026, 9, 17, 11),
          latitude: lat,
          longitude: lat == null ? null : 85.3,
          isSelfReported: selfReported,
        );

    test('a self-reported visit is never called location-supported', () {
      expect(visit(selfReported: true, lat: 27.7).isLocationSupported, isFalse);
      expect(visit(selfReported: true, lat: 27.7).evidenceLabel, 'Self-reported');
    });

    test('a visit without coordinates cannot be location-supported', () {
      expect(visit(selfReported: false).isLocationSupported, isFalse);
    });

    test('coordinates plus the flag make it location-supported', () {
      final v = visit(selfReported: false, lat: 27.7);
      expect(v.isLocationSupported, isTrue);
      expect(v.evidenceLabel, 'Location-supported');
    });

    test('duration is computed from start and end', () {
      expect(visit(selfReported: true).duration, const Duration(hours: 1));
    });
  });
}
