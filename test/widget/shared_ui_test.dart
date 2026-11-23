import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_lead/core/extensions/context_extensions.dart';
import 'package:futsal_lead/shared/widgets/state_views.dart';
import 'package:futsal_lead/shared/widgets/status_chip.dart';

void main() {
  testWidgets('prompt dialog closes cleanly and returns its text', (t) async {
    String? result;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await promptForText(context, title: 'Note'),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField), ' hello ');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(result, 'hello');
  });

  testWidgets('empty view and chip fit in cramped spaces', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 90,
                child: EmptyView(title: 'Empty', message: 'Nothing here'),
              ),
              SizedBox(
                width: 80,
                child: StatusChip(
                  label: 'A very long status label',
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
  });
}
