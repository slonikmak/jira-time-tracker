import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/ui/edit_segment_dialog.dart';

void main() {
  testWidgets('редактор интервала помещается в узкое окно', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final segment = Segment(
      id: 'segment-1',
      draftId: 'draft-1',
      sourceLogId: 'log-1',
      issueId: 'issue-1',
      startUtc: DateTime.utc(2026, 9, 14, 9),
      durationSeconds: 3600,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => EditSegmentDialog(
                  segment: segment,
                  taskTitle: 'PROJ-1 · Задача',
                  onSave:
                      ({
                        required startUtc,
                        required durationSeconds,
                        required description,
                      }) {},
                ),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Изменить интервал'), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);
  });
}
