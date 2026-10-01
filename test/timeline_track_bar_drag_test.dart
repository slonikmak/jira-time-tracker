import 'package:jira_time_tracker/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/ui/timeline_track_bar.dart';

void main() {
  group('TimelineTrackBar Interactive Drag Handles (Ticket 02)', () {
    final start = DateTime.utc(2026, 9, 14, 9, 0);
    final end = DateTime.utc(2026, 9, 14, 13, 0);

    final draft = DayDraft(
      id: 'draft-1',
      scope: 'test-scope',
      date: '2026-09-14',
      startUtc: start,
      endUtc: end,
      seed: 42,
      settingsSnapshot: '{}',
      importedWorklogsSnapshot: '[]',
      status: DraftStatus.draft,
    );

    final seg1 = Segment(
      id: 'seg-1',
      draftId: 'draft-1',
      sourceLogId: 'log-1',
      issueId: '101',
      startUtc: DateTime.utc(2026, 9, 14, 9, 0),
      durationSeconds: 3600, // 1 час: 09:00 - 10:00
      description: 'Задача 1',
      sendState: SendState.pending,
    );

    final seg2 = Segment(
      id: 'seg-2',
      draftId: 'draft-1',
      sourceLogId: 'log-2',
      issueId: '102',
      startUtc: DateTime.utc(2026, 9, 14, 11, 0),
      durationSeconds: 3600, // 1 час: 11:00 - 12:00
      description: 'Задача 2',
      sendState: SendState.pending,
    );

    testWidgets('Параллельные логи видны в разных дорожках', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: TimelineTrackBar(
                draft: draft,
                segments: [
                  seg1,
                  seg2.copyWith(startUtc: DateTime.utc(2026, 9, 14, 9, 30)),
                ],
                breaks: const [],
              ),
            ),
          ),
        ),
      );

      final first = find.byKey(const Key('track_segment_seg-1'));
      final second = find.byKey(const Key('track_segment_seg-2'));
      expect(first, findsOneWidget);
      expect(second, findsOneWidget);
      expect(tester.getTopLeft(first).dy, isNot(tester.getTopLeft(second).dy));
    });

    testWidgets(
      'Правая ручка вызывает onResizeSegmentRight с обновленной длительностью',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        int? resizedDuration;

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 800,
                child: TimelineTrackBar(
                  draft: draft,
                  segments: [seg1, seg2],
                  breaks: [
                    Break(
                      id: 'b-1',
                      draftId: 'draft-1',
                      startUtc: DateTime.utc(2026, 9, 14, 10, 0),
                      durationSeconds: 3600,
                      kind: BreakKind.short,
                    ),
                  ],
                  issueKeys: const {'101': 'PROJ-1', '102': 'PROJ-2'},
                  onResizeSegmentRight: (seg, newDur) {
                    resizedDuration = newDur;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Находим правую ручку для seg-1
        final rightHandle = find.byKey(const Key('drag_handle_right_seg-1'));
        expect(rightHandle, findsOneWidget);

        // Тянем правую ручку вправо на 50 пикселей
        await tester.drag(rightHandle, const Offset(50, 0));
        await tester.pumpAndSettle();

        // Проверяем, что был вызван коллбэк onResizeSegmentRight с длительностью больше 3600
        expect(resizedDuration, isNotNull);
        expect(resizedDuration!, greaterThan(3600));
      },
    );

    testWidgets(
      'Левая ручка вызывает onResizeSegmentLeft с обновленным startUtc',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        DateTime? resizedStart;

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 800,
                child: TimelineTrackBar(
                  draft: draft,
                  segments: [seg1, seg2],
                  breaks: [
                    Break(
                      id: 'b-1',
                      draftId: 'draft-1',
                      startUtc: DateTime.utc(2026, 9, 14, 10, 0),
                      durationSeconds: 3600,
                      kind: BreakKind.short,
                    ),
                  ],
                  issueKeys: const {'101': 'PROJ-1', '102': 'PROJ-2'},
                  onResizeSegmentLeft: (seg, newStart) {
                    resizedStart = newStart;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Находим левую ручку для seg-2
        final leftHandle = find.byKey(const Key('drag_handle_left_seg-2'));
        expect(leftHandle, findsOneWidget);

        // Тянем левую ручку seg-2 влево на 50 пикселей
        await tester.drag(leftHandle, const Offset(-50, 0));
        await tester.pumpAndSettle();

        // Проверяем, что был вызван коллбэк onResizeSegmentLeft со временем начала раньше 11:00
        expect(resizedStart, isNotNull);
        expect(
          resizedStart!.isBefore(DateTime.utc(2026, 9, 14, 11, 0)),
          isTrue,
        );
      },
    );
  });
}
