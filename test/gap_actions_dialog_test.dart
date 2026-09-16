import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/ui/gap_actions_dialog.dart';

void main() {
  group('GapActionsDialog Widget Tests (Ticket 02)', () {
    setUp(() {});

    testWidgets('Отображает целевые действия и вызывает onSnap', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final breakItem = Break(
        id: 'gap-1',
        draftId: 'draft-1',
        startUtc: DateTime.utc(2026, 9, 14, 10, 0),
        durationSeconds: 3600,
        kind: BreakKind.short,
      );

      bool snapped = false;
      bool filled = false;
      int? setDuration;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GapActionsDialog(
              breakItem: breakItem,
              neighbors: GapNeighbors(
                leftSegment: Segment(
                  id: 's1',
                  draftId: 'd1',
                  sourceLogId: 'l1',
                  issueId: '1',
                  startUtc: DateTime.utc(2026, 9, 14, 9, 0),
                  durationSeconds: 3600,
                  description: 'Task 1',
                  sendState: SendState.pending,
                ),
              ),
              onSnap: () => snapped = true,
              onFillLeft: () => filled = true,
              onSetDuration: (sec) => setDuration = sec,
            ),
          ),
        ),
      );

      expect(find.text('Схлопнуть паузу'), findsOneWidget);
      expect(find.text('Растянуть предыдущую задачу'), findsOneWidget);

      await tester.tap(find.text('Схлопнуть паузу'));
      await tester.pumpAndSettle();

      expect(snapped, isTrue);
      expect(filled, isFalse);
      expect(setDuration, isNull);
    });

    testWidgets('Быстрый чип длительности вызывает onSetDuration', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final breakItem = Break(
        id: 'gap-1',
        draftId: 'draft-1',
        startUtc: DateTime.utc(2026, 9, 14, 10, 0),
        durationSeconds: 3600,
        kind: BreakKind.short,
      );

      int? setDuration;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GapActionsDialog(
              breakItem: breakItem,
              neighbors: const GapNeighbors(),
              onSnap: () {},
              onFillLeft: () {},
              onSetDuration: (sec) => setDuration = sec,
            ),
          ),
        ),
      );

      expect(find.text('45 мин'), findsOneWidget);
      await tester.tap(find.text('45 мин'));
      await tester.pumpAndSettle();

      expect(setDuration, equals(45 * 60));
    });

    testWidgets('Отображает ошибку валидации при невозможности сдвига', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final breakItem = Break(
        id: 'gap-1',
        draftId: 'draft-1',
        startUtc: DateTime.utc(2026, 9, 14, 10, 0),
        durationSeconds: 3600,
        kind: BreakKind.short,
      );


      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GapActionsDialog(
              breakItem: breakItem,
              neighbors: const GapNeighbors(),
              onSnap: () {},
              onFillLeft: () {},
              onSetDuration: (_) {},
              onValidateDuration: (_) => 'Ошибка: зазор упирается в запись Jira',
            ),
          ),
        ),
      );

      await tester.tap(find.text('30 мин'));
      await tester.pumpAndSettle();

      expect(find.text('Ошибка: зазор упирается в запись Jira'), findsOneWidget);
    });
  });
}
