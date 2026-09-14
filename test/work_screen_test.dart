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

void main() {
  late Database db;
  late LocalStore store;
  late ConnectionStore connectionStore;
  late JiraClient jiraClient;
  late DateTime currentTime;

  DateTime testNow() => currentTime;

  setUp(() {
    db = sqlite3.openInMemory();
    store = LocalStore(db);
    store.init();
    connectionStore = ConnectionStore(
      secureStorage: InMemorySecureStorage(),
      environment: {},
    );
    jiraClient = JiraClient();
    currentTime = DateTime.utc(2026, 9, 14, 10, 0, 0);

    // Добавим задачу в SQLite
    store.upsertIssue(
      Issue(
        scope: 'default',
        issueId: '10001',
        key: 'PROJ-1',
        summary: 'Разработка фичи',
        lastUsedAtUtc: currentTime,
      ),
    );
  });

  tearDown(() {
    store.close();
    jiraClient.close();
  });

  AppState createAppState() {
    return AppState(
      store: store,
      connectionStore: connectionStore,
      jiraClient: jiraClient,
      isReadOnly: false,
      nowProvider: testNow,
    );
  }

  testWidgets(
    'AddTimeDialog открывается из карточки задачи и сохраняет 3 часа (A01)',
    (WidgetTester tester) async {
      final appState = createAppState();

      await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
      await tester.pumpAndSettle();

      expect(find.text('PROJ-1'), findsOneWidget);
      expect(find.text('Разработка фичи'), findsOneWidget);

      // Нажимаем иконку «Добавить время» на карточке задачи
      final addTimeBtn = find.byTooltip('Добавить время вручную').first;
      await tester.tap(addTimeBtn);
      await tester.pumpAndSettle();

      // Открылся диалог
      expect(find.text('Добавить время'), findsOneWidget);
      expect(find.text('Часы'), findsOneWidget);
      expect(find.text('Минуты'), findsOneWidget);

      // Вводим 3 часа
      final hoursField = find.widgetWithText(TextField, 'Часы');
      await tester.enterText(hoursField, '3');
      await tester.pumpAndSettle();

      // Сохраняем
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      // Диалог закрылся, лог появился в очереди справа
      expect(find.text('Добавить время'), findsNothing);
      expect(find.text('Логи к сборке (1)'), findsOneWidget);
      expect(find.text('Всего: 3ч 00м'), findsOneWidget);
      expect(find.text('3ч 00м'), findsOneWidget);

      // В SQLite 10 800 секунд
      expect(appState.unconsumedLogs.first.accumulatedSeconds, 10800);
      expect(appState.unconsumedLogs.first.isRunning, isFalse);
    },
  );

  testWidgets(
    'Запуск (Start) и остановка (Stop) таймера на карточке задачи в UI (A03)',
    (WidgetTester tester) async {
      final appState = createAppState();

      await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
      await tester.pumpAndSettle();

      // Кнопка «Новый лог на задаче» (playlist_add) убрана за ненадобностью
      expect(find.byIcon(Icons.playlist_add), findsNothing);

      // Кликаем Play (Запустить таймер)
      final playBtn = find.byTooltip('Запустить таймер').first;
      await tester.tap(playBtn);
      await tester.pumpAndSettle();

      // Таймер запустился: иконка сменилась на Stop
      expect(find.byTooltip('Остановить таймер'), findsWidgets);
      expect(appState.unconsumedLogs.first.isRunning, isTrue);

      // Перематываем время на 10 минут
      currentTime = currentTime.add(const Duration(minutes: 10));
      await tester.pump();

      // Кликаем Stop (Остановить таймер)
      final stopBtn = find.byTooltip('Остановить таймер').first;
      await tester.tap(stopBtn);
      await tester.pumpAndSettle();

      // Таймер остановлен, зафиксировано 10 минут, карточка сброшена на 00:00:00
      expect(find.byTooltip('Запустить таймер'), findsWidgets);
      expect(appState.unconsumedLogs.first.isRunning, isFalse);
      expect(appState.unconsumedLogs.first.accumulatedSeconds, 600);
      expect(find.text('Всего: 10м'), findsOneWidget);
    },
  );

  testWidgets('Чекбокс свободного лога меняет выбор для сборки', (
    WidgetTester tester,
  ) async {
    store.saveLogAndIssue(
      issue: store.getIssues(scope: 'default').single,
      log: LocalLog(
        id: 'log-checkbox',
        scope: 'default',
        issueId: '10001',
        titleSnapshot: 'Разработка фичи',
        accumulatedSeconds: 1800,
        createdAtUtc: currentTime,
      ),
    );
    final appState = createAppState();

    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();

    final checkbox = find.byType(Checkbox).first;
    await tester.tap(checkbox);
    await tester.pump();

    expect(appState.selectedLogIds, contains('log-checkbox'));
    expect(find.text('1 лог · 30м'), findsOneWidget);

    await tester.tap(checkbox);
    await tester.pump();
    expect(appState.selectedLogIds, isEmpty);
  });

  test(
    'Загрузка сохранённого подключения восстанавливает черновик его scope',
    () async {
      const scope = 'https://example.atlassian.net#account-1';
      const draftId = 'draft-scoped';
      const logId = 'log-scoped';
      final issue = Issue(
        scope: scope,
        issueId: '20002',
        key: 'PROJ-2',
        summary: 'Задача в Jira scope',
        lastUsedAtUtc: currentTime,
      );
      store.saveLogAndIssue(
        issue: issue,
        log: LocalLog(
          id: logId,
          scope: scope,
          issueId: issue.issueId,
          titleSnapshot: issue.summary,
          accumulatedSeconds: 1800,
          createdAtUtc: currentTime,
        ),
      );
      store.saveDayDraft(
        draft: DayDraft(
          id: draftId,
          scope: scope,
          date: '2026-09-14',
          startUtc: DateTime.utc(2026, 9, 14, 7),
          endUtc: DateTime.utc(2026, 9, 14, 15),
          seed: 42,
          settingsSnapshot: const DaySettings().toJson(),
        ),
        draftLogs: const [
          DraftLog(
            draftId: draftId,
            sourceLogId: logId,
            sourceDurationSeconds: 1800,
            descriptionSnapshot: '',
          ),
        ],
        segments: [
          Segment(
            id: 'segment-scoped',
            draftId: draftId,
            sourceLogId: logId,
            issueId: issue.issueId,
            startUtc: DateTime.utc(2026, 9, 14, 7),
            durationSeconds: 1800,
          ),
        ],
        breaks: const [],
      );
      await connectionStore.saveConnection(
        const JiraConnection(
          baseUrl: 'https://example.atlassian.net',
          email: 'user@example.com',
          accountId: 'account-1',
          displayName: 'Test User',
          route: JiraAuthRoute.direct,
          scope: scope,
        ),
        'test-token',
      );

      final appState = createAppState();
      await appState.loadSavedConnection();

      expect(appState.isLogInDraft(logId), isTrue);
      expect(appState.currentDraft?.id, draftId);
      expect(appState.currentSegments, hasLength(1));
    },
  );

  testWidgets('Галочка снимает лог из ещё не отправленного черновика', (
    WidgetTester tester,
  ) async {
    const logId = 'log-in-draft';
    const draftId = 'draft-checkbox';
    store.saveLogAndIssue(
      issue: store.getIssues(scope: 'default').single,
      log: LocalLog(
        id: logId,
        scope: 'default',
        issueId: '10001',
        titleSnapshot: 'Разработка фичи',
        accumulatedSeconds: 1800,
        createdAtUtc: currentTime,
      ),
    );
    store.saveDayDraft(
      draft: DayDraft(
        id: draftId,
        scope: 'default',
        date: '2026-09-14',
        startUtc: DateTime.utc(2026, 9, 14, 7),
        endUtc: DateTime.utc(2026, 9, 14, 15),
        seed: 42,
        settingsSnapshot: const DaySettings().toJson(),
      ),
      draftLogs: const [
        DraftLog(
          draftId: draftId,
          sourceLogId: logId,
          sourceDurationSeconds: 1800,
          descriptionSnapshot: '',
        ),
      ],
      segments: [
        Segment(
          id: 'segment-a',
          draftId: draftId,
          sourceLogId: logId,
          issueId: '10001',
          startUtc: DateTime.utc(2026, 9, 14, 7),
          durationSeconds: 900,
        ),
        Segment(
          id: 'segment-b',
          draftId: draftId,
          sourceLogId: logId,
          issueId: '10001',
          startUtc: DateTime.utc(2026, 9, 14, 7, 20),
          durationSeconds: 900,
        ),
      ],
      breaks: const [],
    );
    final appState = createAppState();

    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect(checkbox.value, isTrue);
    expect(checkbox.onChanged, isNotNull);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(appState.isLogInDraft(logId), isFalse);
    expect(appState.currentDraft, isNull);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isFalse);
  });
}
