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
import 'package:jira_time_tracker/ui/gap_actions_dialog.dart';

void main() {
  group('DayScreen Break Editing Integration (Ticket 03)', () {
    late Database db;
    late LocalStore store;
    const testScope = 'https://test.atlassian.net#acc-123';

    setUp(() {
      db = sqlite3.openInMemory();
      store = LocalStore(db);
      store.init();
    });

    tearDown(() {
      store.close();
    });

    testWidgets('Клик по карточке перерыва и по полосе на таймлайне открывает GapActionsDialog и схлопывает паузу', (tester) async {
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
        endUtc: DateTime.utc(2026, 9, 14, 13, 0),
        seed: 42,
        settingsSnapshot: '{}',
        importedWorklogsSnapshot: '[]',
        status: DraftStatus.draft,
      );

      // Задача 1: 09:00 - 10:00, Задача 2: 11:00 - 12:00.
      // Зазор: 10:00 - 11:00.
      final seg1 = Segment(
        id: 'seg-1',
        draftId: 'draft-1',
        sourceLogId: 'log-1',
        issueId: '101',
        startUtc: DateTime.utc(2026, 9, 14, 9, 0),
        durationSeconds: 3600,
        description: 'Задача 1',
        sendState: SendState.pending,
      );
      final seg2 = Segment(
        id: 'seg-2',
        draftId: 'draft-1',
        sourceLogId: 'log-2',
        issueId: '102',
        startUtc: DateTime.utc(2026, 9, 14, 11, 0),
        durationSeconds: 3600,
        description: 'Задача 2',
        sendState: SendState.pending,
      );

      final draftLogs = [
        const DraftLog(
          draftId: 'draft-1',
          sourceLogId: 'log-1',
          sourceDurationSeconds: 3600,
          descriptionSnapshot: 'Задача 1',
          durationLocked: false,
        ),
        const DraftLog(
          draftId: 'draft-1',
          sourceLogId: 'log-2',
          sourceDurationSeconds: 3600,
          descriptionSnapshot: 'Задача 2',
          durationLocked: false,
        ),
      ];

      store.saveDayDraft(
        draft: draft,
        draftLogs: draftLogs,
        segments: [seg1, seg2],
        breaks: [],
      );

      appState.setSelectedDate(DateTime(2026, 9, 14));

      await tester.pumpWidget(
        MaterialApp(
          home: DayScreen(appState: appState),
        ),
      );
      await tester.pumpAndSettle();

      // Проверяем наличие карточки перерыва
      expect(find.text('Перерыв'), findsAtLeastNWidgets(1));

      // 1. Клик по кнопке редактирования на карточке перерыва
      final editButtons = find.byTooltip('Редактировать интервал');
      expect(editButtons, findsAtLeastNWidgets(1));
      await tester.tap(editButtons.first);
      await tester.pumpAndSettle();

      // Открылся диалог GapActionsDialog
      expect(find.byType(GapActionsDialog), findsOneWidget);
      expect(find.text('Схлопнуть паузу'), findsOneWidget);

      // Закрываем диалог (кнопка «Закрыть»)
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      expect(find.byType(GapActionsDialog), findsNothing);

      // 2. Клик по блоку паузы между задачами на таймлайне (TimelineTrackBar)
      final breakTrackItems = find.byWidgetPredicate(
        (w) =>
            w is Tooltip &&
            w.message?.startsWith('Перерыв · ') == true,
      );
      expect(breakTrackItems, findsAtLeastNWidgets(1));

      await tester.tap(breakTrackItems.first);
      await tester.pumpAndSettle();

      // Снова открылся диалог GapActionsDialog
      expect(find.byType(GapActionsDialog), findsOneWidget);

      // Нажимаем «Схлопнуть паузу»
      await tester.tap(find.text('Схлопнуть паузу'));
      await tester.pumpAndSettle();

      // Диалог закрылся, пауза схлопнута:
      // Задача 1 осталась 09:00 - 10:00 (3600 сек)
      // Задача 2 придвинулась вплотную к 10:00 (сохранив свою длительность 3600 сек!)
      expect(find.byType(GapActionsDialog), findsNothing);
      final updatedSeg1 = appState.currentSegments.firstWhere((s) => s.id == 'seg-1');
      expect(updatedSeg1.startUtc, equals(DateTime.utc(2026, 9, 14, 9, 0)));
      expect(updatedSeg1.durationSeconds, equals(3600));

      final updatedSeg2 = appState.currentSegments.firstWhere((s) => s.id == 'seg-2');
      expect(updatedSeg2.startUtc, equals(DateTime.utc(2026, 9, 14, 10, 0)));
      expect(updatedSeg2.durationSeconds, equals(3600));
    });
  });
}
