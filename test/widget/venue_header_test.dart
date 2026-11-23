import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_lead/core/constants/enums.dart';
import 'package:futsal_lead/core/theme/app_theme.dart';
import 'package:futsal_lead/features/venues/domain/entities/venue.dart';
import 'package:futsal_lead/features/venues/presentation/widgets/venue_header.dart';
import 'package:futsal_lead/shared/widgets/action_tiles.dart';

Venue _venue({
  LeadStatus status = LeadStatus.contacted,
  DateTime? nextFollowUpAt,
  int visitCount = 0,
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
    nextFollowUpAt: nextFollowUpAt,
  );
}

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('VenueHeader', () {
    testWidgets('shows name, location, status and priority', (tester) async {
      await tester.pumpWidget(_wrap(VenueHeader(venue: _venue())));

      expect(find.text('XYZ Futsal'), findsOneWidget);
      expect(find.text('Baneshwor, Kathmandu'), findsOneWidget);
      expect(find.text('Contacted'), findsOneWidget);
      expect(find.text('High priority'), findsOneWidget);
    });

    testWidgets('places the lead on the pipeline track', (tester) async {
      await tester.pumpWidget(_wrap(VenueHeader(venue: _venue())));
      // Contacted is the second of the seven forward-path statuses.
      expect(find.text('Step 2 of 7'), findsOneWidget);
    });

    testWidgets('does not invent a track position for off-pipeline statuses',
        (tester) async {
      await tester.pumpWidget(
        _wrap(VenueHeader(venue: _venue(status: LeadStatus.unresponsive))),
      );

      expect(find.textContaining('Step'), findsNothing);
      expect(find.textContaining('off the main pipeline'), findsOneWidget);
    });

    testWidgets('warns when a follow-up is overdue', (tester) async {
      await tester.pumpWidget(_wrap(VenueHeader(
        venue: _venue(
          nextFollowUpAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      )));

      expect(find.textContaining('overdue'), findsWidgets);
    });

    testWidgets('does not warn for a won lead with a stale date', (tester) async {
      await tester.pumpWidget(_wrap(VenueHeader(
        venue: _venue(
          status: LeadStatus.converted,
          nextFollowUpAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      )));

      expect(find.textContaining('overdue'), findsNothing);
    });

    testWidgets('status bar is tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(VenueHeader(venue: _venue(), onStatusTap: () => tapped = true)),
      );

      await tester.tap(find.text('Contacted'));
      expect(tapped, isTrue);
    });

    testWidgets('distinguishes visited from never visited', (tester) async {
      await tester.pumpWidget(_wrap(VenueHeader(venue: _venue())));
      expect(find.text('None'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(VenueHeader(venue: _venue(visitCount: 3))),
      );
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('ActionTileGrid', () {
    testWidgets('renders every action with its badge', (tester) async {
      await tester.pumpWidget(_wrap(ActionTileGrid(actions: [
        AppAction(label: 'Change status', icon: Icons.swap_horiz, onTap: () {}),
        AppAction(
          label: 'Schedule',
          icon: Icons.event,
          badge: 'Nothing planned',
          onTap: () {},
        ),
      ])));

      expect(find.text('Change status'), findsOneWidget);
      expect(find.text('Nothing planned'), findsOneWidget);
    });

    testWidgets('fires the callback on tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(ActionTileGrid(actions: [
        AppAction(label: 'Add note', icon: Icons.note_add, onTap: () => tapped = true),
      ])));

      await tester.tap(find.text('Add note'));
      expect(tapped, isTrue);
    });

    testWidgets('a disabled action does not fire', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(ActionTileGrid(actions: [
        AppAction(
          label: 'Record visit',
          icon: Icons.place,
          enabled: false,
          onTap: () => tapped = true,
        ),
      ])));

      await tester.tap(find.text('Record visit'));
      expect(tapped, isFalse);
    });
  });
}
