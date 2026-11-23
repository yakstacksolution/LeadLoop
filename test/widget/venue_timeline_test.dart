import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_lead/core/theme/app_theme.dart';
import 'package:futsal_lead/features/venues/domain/entities/timeline_entry.dart';
import 'package:futsal_lead/features/venues/presentation/widgets/venue_timeline.dart';

TimelineEntry _entry(String id, TimelineKind kind, {bool? selfReported}) {
  return TimelineEntry(
    id: id,
    kind: kind,
    occurredAt: DateTime(2026, 9, 17, 10),
    title: 'Entry $id',
    body: 'Body $id',
    actorName: 'Dilli',
    isSelfReported: selfReported,
  );
}

void main() {
  Widget wrap(List<TimelineEntry> entries) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: VenueTimeline(entries: entries)),
      );

  testWidgets('renders every entry without a layout overflow', (tester) async {
    await tester.pumpWidget(wrap([
      _entry('1', TimelineKind.note),
      _entry('2', TimelineKind.statusChange),
      _entry('3', TimelineKind.activity),
      _entry('4', TimelineKind.visit, selfReported: true),
    ]));

    expect(find.text('Entry 1'), findsOneWidget);
    expect(find.text('Entry 4'), findsOneWidget);
    expect(find.text('Body 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not use IntrinsicHeight, which forces a second layout pass',
      (tester) async {
    await tester.pumpWidget(wrap([_entry('1', TimelineKind.note)]));
    expect(find.byType(IntrinsicHeight), findsNothing);
  });

  testWidgets('labels visit evidence honestly', (tester) async {
    await tester.pumpWidget(wrap([
      _entry('1', TimelineKind.visit, selfReported: true),
      _entry('2', TimelineKind.visit, selfReported: false),
    ]));

    expect(find.text('Self-reported'), findsOneWidget);
    expect(find.text('Location-supported'), findsOneWidget);
  });

  testWidgets('scrolls a long timeline without error', (tester) async {
    await tester.pumpWidget(wrap(
      List.generate(60, (i) => _entry('$i', TimelineKind.note)),
    ));

    await tester.drag(find.byType(VenueTimeline), const Offset(0, -2000));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an actor and timestamp for each entry', (tester) async {
    await tester.pumpWidget(wrap([_entry('1', TimelineKind.note)]));
    expect(find.textContaining('Dilli'), findsOneWidget);
    expect(find.textContaining('17 Sep 2026'), findsOneWidget);
  });
}
