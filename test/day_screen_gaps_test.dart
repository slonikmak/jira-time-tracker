import 'package:jira_time_tracker/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/main.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';
import 'package:jira_time_tracker/ui/day_screen.dart';

void main() {
  group('DayScreen Timeline Gaps Visualization (Ticket 02)', () {
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
      'Показывает паузу и очищает черновик только после подтверждения',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Локальное время дня 16 сентября 2026
        DateTime localTime(int hour, int minute) {
          return DateTime(2026, 9, 16, hour, minute).toUtc();
        }

        final start1 = localTime(9, 0); // 09:00
        final end1 = localTime(10, 37); // 10:37
        final dur1 = end1.difference(start1).inSeconds; // 1 ч 37 мин = 5820s

        final start2 = localTime(14, 32); // 14:32
        final end2 = localTime(15, 32); // 15:32
        final dur2 = end2.difference(start2).inSeconds; // 1 ч = 3600s

        final issue = Issue(
          scope: testScope,
          issueId: '1001',
          key: 'PROJ-1',
          summary: 'Главная задача',
          lastUsedAtUtc: start1,
        );
        final log1 = LocalLog(
          id: 'log-1',
          scope: testScope,
          issueId: '1001',
          titleSnapshot: 'Задача 1',
          accumulatedSeconds: dur1,
          createdAtUtc: end1,
        );
        final log2 = LocalLog(
          id: 'log-2',
          scope: testScope,
          issueId: '1001',
          titleSnapshot: 'Задача 2',
          accumulatedSeconds: dur2,
          createdAtUtc: end2,
        );
        store.saveLogsAndIssue(logs: [log1, log2], issue: issue);

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

        appState.setSelectedDate(DateTime(2026, 9, 16));

        // Сохраняем черновик с двумя сегментами (as-recorded)
        final draft = DayDraft(
          id: 'draft-1',
          scope: testScope,
          date: '2026-09-16',
          startUtc: start1,
          endUtc: end2,
          seed: 1,
          settingsSnapshot: const DaySettings().toJson(),
          status: DraftStatus.draft,
        );

        final seg1 = Segment(
          id: 'seg-1',
          draftId: 'draft-1',
          sourceLogId: 'log-1',
          issueId: '1001',
          startUtc: start1,
          durationSeconds: dur1,
          description: 'Утренняя часть',
        );
        final seg2 = Segment(
          id: 'seg-2',
          draftId: 'draft-1',
          sourceLogId: 'log-2',
          issueId: '1001',
          startUtc: start2,
          durationSeconds: dur2,
          description: 'Послеобеденная часть',
        );

        store.saveDayDraft(
          draft: draft,
          draftLogs: [
            DraftLog(
              draftId: 'draft-1',
              sourceLogId: 'log-1',
              sourceDurationSeconds: dur1,
              descriptionSnapshot: '',
            ),
            DraftLog(
              draftId: 'draft-1',
              sourceLogId: 'log-2',
              sourceDurationSeconds: dur2,
              descriptionSnapshot: '',
            ),
          ],
          segments: [seg1, seg2],
          breaks: const [], // в базе сохранён пустой список пауз
        );

        appState.loadDraftForSelectedDate();

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DayScreen(appState: appState),
          ),
        );
        await tester.pumpAndSettle();

        // Проверяем метрику "Паузы": 3ч 55м
        expect(find.text('3ч 55м'), findsWidgets);

        // Проверяем карточку паузы в расписании
        expect(find.textContaining('10:37 — 14:32'), findsOneWidget);
        expect(find.text('Пауза'), findsOneWidget);

        // Проверяем, что отображаются обе задачи
        expect(find.text('Утренняя часть'), findsOneWidget);
        expect(find.text('Послеобеденная часть'), findsOneWidget);

        tester.view.physicalSize = const Size(800, 600);
        await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
        await tester.pumpAndSettle();
        await tester.tap(find.text('День').first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.widgetWithText(OutlinedButton, 'Очистить'));
        await tester.pumpAndSettle();
        expect(find.text('Очистить день?'), findsOneWidget);
        expect(appState.currentDraft, isNotNull);
        await tester.tap(find.widgetWithText(FilledButton, 'Очистить'));
        await tester.pumpAndSettle();
        expect(appState.currentDraft, isNull);
        expect(store.getLocalLog('log-1')!.accumulatedSeconds, dur1);
        expect(store.getLocalLog('log-2')!.accumulatedSeconds, dur2);
      },
    );
  });
}
