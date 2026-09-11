import 'package:flutter_test/flutter_test.dart';
import 'package:leadloop/features/follow_up/data/repositories/in_memory_follow_up_repository.dart';
import 'package:leadloop/main.dart';

void main() {
  testWidgets('LeadLoop dashboard loads seeded follow-up workflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      LeadLoopApp(repository: InMemoryFollowUpRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('LeadLoop'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Due today'), findsOneWidget);
    expect(find.text('Arena Futsal Center'), findsOneWidget);
  });
}
