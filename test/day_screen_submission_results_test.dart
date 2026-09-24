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
  testWidgets(
    'показывает результат частичной отправки и ручную сверку unknown',
    (tester) async {
      final db = sqlite3.openInMemory();
      final store = LocalStore(db)..init();
      const scope = 'https://test.atlassian.net#acc-123';
      final date = DateTime.utc(2026, 9, 14);
      const statuses = [SendState.sent, SendState.failed, SendState.unknown];
      final logs = <LocalLog>[];
      final issues = <Issue>[];
      final segments = <Segment>[];
      final draftLogs = <DraftLog>[];

      for (var i = 0; i < statuses.length; i++) {
        final issueId = '${1001 + i}';
        final logId = 'log-$i';
        final issue = Issue(
          scope: scope,
          issueId: issueId,
          key: 'PROJ-${i + 1}',
          summary: 'Задача ${i + 1}',
          lastUsedAtUtc: date,
        );
        issues.add(issue);
        logs.add(
          LocalLog(
            id: logId,
            scope: scope,
            issueId: issueId,
            titleSnapshot: issue.key,
            accumulatedSeconds: 3600,
            createdAtUtc: date,
          ),
        );
        segments.add(
          Segment(
            id: 'segment-$i',
            draftId: 'draft-1',
            sourceLogId: logId,
            issueId: issueId,
            startUtc: date.add(Duration(hours: 9 + i)),
            durationSeconds: 3600,
            description: 'Описание ${i + 1}',
            sendState: statuses[i],
            lastError: statuses[i] == SendState.unknown
                ? 'Результат POST неизвестен'
                : null,
          ),
        );
        draftLogs.add(
          DraftLog(
            draftId: 'draft-1',
            sourceLogId: logId,
            sourceDurationSeconds: 3600,
            descriptionSnapshot: 'Описание ${i + 1}',
          ),
        );
        store.saveLogsAndIssue(logs: [logs.last], issue: issues.last);
      }

      store.saveDayDraft(
        draft: DayDraft(
          id: 'draft-1',
          scope: scope,
          date: '2026-09-14',
          startUtc: date.add(const Duration(hours: 9)),
          endUtc: date.add(const Duration(hours: 14)),
          seed: 1,
          settingsSnapshot: const DaySettings().toJson(),
          importedWorklogsSnapshot: '[]',
          status: DraftStatus.draft,
        ),
        draftLogs: draftLogs,
        segments: segments,
        breaks: const [],
      );

      final appState = AppState(
        store: store,
        connectionStore: ConnectionStore(
          secureStorage: InMemorySecureStorage(),
        ),
        jiraClient: JiraClient(),
        isReadOnly: false,
        initialConnection: const JiraConnection(
          baseUrl: 'https://test.atlassian.net',
          email: 'test@example.com',
          accountId: 'acc-123',
          displayName: 'Tester',
          route: JiraAuthRoute.direct,
          scope: scope,
        ),
      );
      appState.setSelectedDate(DateTime(2026, 9, 14));

      addTearDown(() {
        appState.dispose();
        store.close();
      });
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(home: DayScreen(appState: appState)));
      await tester.pumpAndSettle();

      expect(find.text('Шкала дня'), findsOneWidget);
      expect(find.text('Расписание'), findsOneWidget);
      expect(find.text('Источники'), findsOneWidget);
      expect(find.text('Отправлено'), findsWidgets);
      await tester.tap(find.text('Результаты отправки'));
      await tester.pumpAndSettle();
      expect(find.text('Записи этого дня'), findsOneWidget);
      expect(find.text('Не отправлено'), findsOneWidget);
      expect(find.text('Проверяем результат'), findsOneWidget);
      expect(find.text('Проверить в Jira'), findsOneWidget);
      expect(find.text('Описание 2'), findsWidgets);

      await tester.tap(
        find.byTooltip('Действия для неопределённого результата'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Сверить результат (A15)'), findsOneWidget);
      expect(find.text('Разрешить вручную (A15)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      final readOnlyState = AppState(
        store: store,
        connectionStore: ConnectionStore(
          secureStorage: InMemorySecureStorage(),
        ),
        jiraClient: JiraClient(),
        isReadOnly: true,
        initialConnection: const JiraConnection(
          baseUrl: 'https://test.atlassian.net',
          email: 'test@example.com',
          accountId: 'acc-123',
          displayName: 'Tester',
          route: JiraAuthRoute.direct,
          scope: scope,
        ),
      );
      addTearDown(readOnlyState.dispose);
      readOnlyState.setSelectedDate(DateTime(2026, 9, 14));
      await tester.pumpWidget(
        MaterialApp(home: DayScreen(appState: readOnlyState)),
      );
      await tester.pumpAndSettle();

      final reconcileButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Проверить в Jira'),
      );
      expect(reconcileButton.onPressed, isNull);
      await tester.tap(find.text('Результаты отправки'));
      await tester.pumpAndSettle();
      final resultMenu = tester.widget<PopupMenuButton<String>>(
        find.ancestor(
          of: find.byTooltip('Действия для неопределённого результата'),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      expect(resultMenu.enabled, isFalse);
    },
  );
}
