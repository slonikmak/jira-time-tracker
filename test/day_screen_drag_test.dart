import 'package:jira_time_tracker/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';
import 'package:jira_time_tracker/ui/day_screen.dart';

void main() {
  group('DayScreen Drag Handles Integration (Ticket 03)', () {
    late Database db;
    late LocalStore store;
    const testScope = 'https://test.atlassian.net#acc-123';

    setUp(() {
      db = sqlite3.openInMemory();
      store = LocalStore(db);
      store.init();
      store.setSetting('ui_language', 'ru');
    });

    tearDown(() {
      store.close();
    });

    testWidgets(
      'Перетаскивание правой ручки на DayScreen удлиняет задачу и сдвигает хвост дня',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final connectionStore = ConnectionStore(
          secureStorage: InMemorySecureStorage(),
        );
        final appState = AppState(
          store: store,
          connectionStore: connectionStore,
          jiraClient: JiraClient(),
          isReadOnly: false,
          initialConnection: const JiraConnection(
            baseUrl: 'https://test.atlassian.net',
            email: 'test@example.com',
            accountId: 'acc-123',
            displayName: 'Tester',
            route: JiraAuthRoute.direct,
            scope: testScope,
          ),
        );

        final now = DateTime.utc(2026, 9, 14, 8, 0);
        final issue1 = Issue(
          scope: testScope,
          issueId: '101',
          key: 'PROJ-1',
          summary: 'Задача 1',
          lastUsedAtUtc: now,
        );
        final log1 = LocalLog(
          id: 'log-1',
          scope: testScope,
          issueId: '101',
          titleSnapshot: 'PROJ-1',
          accumulatedSeconds: 3600,
          createdAtUtc: now,
        );
        store.saveLogsAndIssue(logs: [log1], issue: issue1);

        final issue2 = Issue(
          scope: testScope,
          issueId: '102',
          key: 'PROJ-2',
          summary: 'Задача 2',
          lastUsedAtUtc: now,
        );
        final log2 = LocalLog(
          id: 'log-2',
          scope: testScope,
          issueId: '102',
          titleSnapshot: 'PROJ-2',
          accumulatedSeconds: 3600,
          createdAtUtc: now,
        );
        store.saveLogsAndIssue(logs: [log2], issue: issue2);

        final draft = DayDraft(
          id: 'draft-1',
          scope: testScope,
          date: '2026-09-14',
          startUtc: DateTime.utc(2026, 9, 14, 9, 0),
          endUtc: DateTime.utc(2026, 9, 14, 14, 0),
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
          durationSeconds: 3600, // 09:00 - 10:00
          description: 'Задача 1',
          sendState: SendState.pending,
        );
        final seg2 = Segment(
          id: 'seg-2',
          draftId: 'draft-1',
          sourceLogId: 'log-2',
          issueId: '102',
          startUtc: DateTime.utc(2026, 9, 14, 10, 30),
          durationSeconds: 3600, // 10:30 - 11:30
          description: 'Задача 2',
          sendState: SendState.pending,
        );

        store.saveDayDraft(
          draft: draft,
          draftLogs: [
            const DraftLog(
              draftId: 'draft-1',
              sourceLogId: 'log-1',
              sourceDurationSeconds: 3600,
              descriptionSnapshot: '',
              durationLocked: false,
            ),
            const DraftLog(
              draftId: 'draft-1',
              sourceLogId: 'log-2',
              sourceDurationSeconds: 3600,
              descriptionSnapshot: '',
              durationLocked: false,
            ),
          ],
          segments: [seg1, seg2],
          breaks: [],
        );

        appState.setSelectedDate(DateTime(2026, 9, 14));

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DayScreen(appState: appState),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Шкала дня'), findsOneWidget);
        final firstBar = find.byKey(const Key('track_segment_seg-1'));
        final secondBar = find.byKey(const Key('track_segment_seg-2'));
        final gapBefore =
            tester.getTopLeft(secondBar).dx - tester.getTopRight(firstBar).dx;
        final secondWidthBefore = tester.getSize(secondBar).width;
        expect(gapBefore, greaterThan(10));

        // Форма сдвигает следующую запись, сохраняя её длительность.
        await tester.tap(find.byKey(const ValueKey('edit-segment-0')));
        await tester.pumpAndSettle();
        expect(find.text('Изменить интервал'), findsOneWidget);
        await tester.enterText(find.byType(TextField).at(0), '1');
        await tester.enterText(find.byType(TextField).at(1), '30');
        await tester.tap(find.text('Сохранить'));
        await tester.pumpAndSettle();
        final afterEdit = appState.currentSegments.firstWhere(
          (segment) => segment.id == 'seg-2',
        );
        expect(afterEdit.startUtc, DateTime.utc(2026, 9, 14, 11));
        expect(afterEdit.durationSeconds, 3600);
        final gapAfter =
            tester.getTopLeft(secondBar).dx - tester.getTopRight(firstBar).dx;
        expect((gapAfter - gapBefore).abs(), lessThan(1));
        expect(
          (tester.getSize(secondBar).width - secondWidthBefore).abs(),
          lessThan(1),
        );

        // Находим правую ручку seg-1 на таймлайне
        final rightHandle = find.byKey(const Key('drag_handle_right_seg-1'));
        expect(rightHandle, findsOneWidget);

        // Тащим правую ручку вправо на 60 пикселей
        await tester.drag(rightHandle, const Offset(60, 0));
        await tester.pumpAndSettle();

        // seg-1 удлинился
        final updatedSeg1 = appState.currentSegments.firstWhere(
          (s) => s.id == 'seg-1',
        );
        expect(updatedSeg1.durationSeconds, greaterThan(5400));

        // seg-2 сдвинулся вправо (начало позже 10:30)
        final updatedSeg2 = appState.currentSegments.firstWhere(
          (s) => s.id == 'seg-2',
        );
        expect(
          updatedSeg2.startUtc.isAfter(DateTime.utc(2026, 9, 14, 11, 0)),
          isTrue,
        );
        expect(updatedSeg2.durationSeconds, 3600);
      },
    );
  });
}
