import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_lead/core/constants/enums.dart';
import 'package:futsal_lead/core/theme/app_theme.dart';
import 'package:futsal_lead/features/venues/domain/entities/venue.dart';
import 'package:futsal_lead/features/venues/presentation/widgets/venue_card.dart';
import 'package:futsal_lead/features/visits/domain/entities/visit.dart';
import 'package:futsal_lead/features/visits/presentation/widgets/visit_tile.dart';

Venue _venue({
  LeadStatus status = LeadStatus.newLead,
  int visitCount = 0,
  DateTime? lastVisitedAt,
  DateTime? nextFollowUpAt,
  bool isArchived = false,
}) {
  return Venue(
    id: 'v1',
    name: 'XYZ Futsal',
    address: 'Ring Road',
    city: 'Kathmandu',
    area: 'Baneshwor',
    projectId: 'p1',
    assignedEmployeeId: 'e1',
    status: status,
    priority: VenuePriority.high,
    visitCount: visitCount,
    lastVisitedAt: lastVisitedAt,
    nextFollowUpAt: nextFollowUpAt,
    isArchived: isArchived,
  );
}

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('VenueCard', () {
    testWidgets('shows the name, location and lead status', (tester) async {
      await tester.pumpWidget(_wrap(VenueCard(venue: _venue())));

      expect(find.text('XYZ Futsal'), findsOneWidget);
      expect(find.text('Baneshwor, Kathmandu'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('High priority'), findsOneWidget);
    });

    testWidgets('distinguishes visited from not visited', (tester) async {
      await tester.pumpWidget(_wrap(VenueCard(venue: _venue())));
      expect(find.text('Not visited'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          VenueCard(
            venue: _venue(visitCount: 1, lastVisitedAt: DateTime(2026, 9, 10)),
          ),
        ),
      );
      expect(find.text('Not visited'), findsNothing);
      expect(find.textContaining('Visited'), findsOneWidget);
    });

    testWidgets('flags an overdue follow-up', (tester) async {
      await tester.pumpWidget(
        _wrap(
          VenueCard(
            venue: _venue(
              nextFollowUpAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          ),
        ),
      );

      expect(find.textContaining('overdue'), findsOneWidget);
    });

    testWidgets('does not flag a won lead as overdue', (tester) async {
      await tester.pumpWidget(
        _wrap(
          VenueCard(
            venue: _venue(
              status: LeadStatus.converted,
              nextFollowUpAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          ),
        ),
      );

      expect(find.textContaining('overdue'), findsNothing);
      expect(find.text('Converted'), findsOneWidget);
    });

    testWidgets('shows an archived badge', (tester) async {
      await tester.pumpWidget(_wrap(VenueCard(venue: _venue(isArchived: true))));
      expect(find.text('Archived'), findsOneWidget);
    });

    testWidgets('is tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(VenueCard(venue: _venue(), onTap: () => tapped = true)),
      );

      await tester.tap(find.byType(VenueCard));
      expect(tapped, isTrue);
    });
  });

  group('VisitTile', () {
    Visit visit({required bool selfReported}) => Visit(
          id: 'vs1',
          venueId: 'v1',
          projectId: 'p1',
          assignedEmployeeId: 'e1',
          employeeId: 'e1',
          status: VisitStatus.completed,
          startAt: DateTime(2026, 9, 17, 10),
          endAt: DateTime(2026, 9, 17, 11),
          latitude: selfReported ? null : 27.7,
          longitude: selfReported ? null : 85.3,
          isSelfReported: selfReported,
        );

    testWidgets('labels a self-reported visit honestly', (tester) async {
      await tester.pumpWidget(_wrap(VisitTile(visit: visit(selfReported: true))));
      expect(find.text('Self-reported'), findsOneWidget);
      expect(find.text('Location-supported'), findsNothing);
    });

    testWidgets('labels a location-backed visit', (tester) async {
      await tester.pumpWidget(_wrap(VisitTile(visit: visit(selfReported: false))));
      expect(find.text('Location-supported'), findsOneWidget);
    });

    testWidgets('shows the visit duration', (tester) async {
      await tester.pumpWidget(_wrap(VisitTile(visit: visit(selfReported: true))));
      expect(find.text('1 hour'), findsOneWidget);
    });
  });
}
