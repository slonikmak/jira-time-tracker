import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' hide Row;
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
        status: 'В работе',
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
      expect(find.text('В работе'), findsOneWidget);

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

  testWidgets(
    'Карточка задачи отображает статус и кнопки запуска таймера рядом с добавлением времени',
    (WidgetTester tester) async {
      final appState = createAppState();

      await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
      await tester.pumpAndSettle();

      // Статус задачи отображается у правого края карточки (правее ключа задачи)
      final statusFinder = find.text('В работе');
      final keyFinder = find.text('PROJ-1');
      expect(statusFinder, findsOneWidget);
      expect(keyFinder, findsOneWidget);

      final statusRect = tester.getRect(statusFinder);
      final keyRect = tester.getRect(keyFinder);
      final cardFinder = find.byType(Card).first;
      final cardRect = tester.getRect(cardFinder);

      expect(statusRect.left, greaterThan(keyRect.right));
      expect(cardRect.right - statusRect.right, lessThan(20));

      // Кнопка запуска таймера и кнопка добавления времени находятся рядом
      final playBtn = find.byTooltip('Запустить таймер');
      final addTimeBtn = find.byTooltip('Добавить время вручную');
      expect(playBtn, findsOneWidget);
      expect(addTimeBtn, findsOneWidget);

      // Обе кнопки находятся в одном родительском Row
      final playRow = tester.widget<Row>(find.ancestor(
        of: playBtn,
        matching: find.byType(Row),
      ).first);
      final addTimeRow = tester.widget<Row>(find.ancestor(
        of: addTimeBtn,
        matching: find.byType(Row),
      ).first);
      expect(playRow, equals(addTimeRow));
    },
  );

  testWidgets(
    'Недавние задачи сортируются по времени взаимодействия: включение/выключение лога поднимает задачу, неактивные уходят вниз',
    (WidgetTester tester) async {
      // Инициализируем ещё две задачи с разным lastUsedAtUtc:
      // PROJ-1: 10:00 (из setUp)
      // PROJ-2: 09:00
      // PROJ-3: 08:00
      store.upsertIssue(
        Issue(
          scope: 'default',
          issueId: '10002',
          key: 'PROJ-2',
          summary: 'Вторая задача',
          status: 'Открыта',
          lastUsedAtUtc: currentTime.subtract(const Duration(hours: 1)),
        ),
      );
      store.upsertIssue(
        Issue(
          scope: 'default',
          issueId: '10003',
          key: 'PROJ-3',
          summary: 'Третья задача',
          status: 'В ожидании',
          lastUsedAtUtc: currentTime.subtract(const Duration(hours: 2)),
        ),
      );

      final appState = createAppState();
      await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
      await tester.pumpAndSettle();

      // Начальный порядок в filteredIssues: PROJ-1, PROJ-2, PROJ-3
      expect(
        appState.filteredIssues.map((i) => i.key).toList(),
        ['PROJ-1', 'PROJ-2', 'PROJ-3'],
      );

      // 1. Включаем лог (таймер) на нижней задаче PROJ-3 в 10:30
      currentTime = DateTime.utc(2026, 9, 14, 10, 30, 0);
      await appState.playTimer('10003');
      await tester.pumpAndSettle();

      // PROJ-3 стала активной и переместилась на 1-е место!
      expect(
        appState.filteredIssues.map((i) => i.key).toList(),
        ['PROJ-3', 'PROJ-1', 'PROJ-2'],
      );

      // 2. Выключаем лог на PROJ-3 в 10:45
      currentTime = DateTime.utc(2026, 9, 14, 10, 45, 0);
      await appState.pauseTimer('10003');
      await tester.pumpAndSettle();

      // PROJ-3 остаётся вверху, так как с ней взаимодействовали только что (10:45)
      expect(
        appState.filteredIssues.map((i) => i.key).toList(),
        ['PROJ-3', 'PROJ-1', 'PROJ-2'],
      );

      // 3. Включаем лог на PROJ-2 в 11:00
      currentTime = DateTime.utc(2026, 9, 14, 11, 0, 0);
      await appState.playTimer('10002');
      await tester.pumpAndSettle();

      // PROJ-2 поднялась на 1-е место.
      // PROJ-1 (с которой не работали с 10:00) ушла в самый низ!
      expect(
        appState.filteredIssues.map((i) => i.key).toList(),
        ['PROJ-2', 'PROJ-3', 'PROJ-1'],
      );

      // 4. Выключаем лог на PROJ-2 в 11:15
      currentTime = DateTime.utc(2026, 9, 14, 11, 15, 0);
      await appState.pauseTimer('10002');
      await tester.pumpAndSettle();

      expect(
        appState.filteredIssues.map((i) => i.key).toList(),
        ['PROJ-2', 'PROJ-3', 'PROJ-1'],
      );

      // 5. Вносим ручной лог на PROJ-1 в 11:30
      currentTime = DateTime.utc(2026, 9, 14, 11, 30, 0);
      await appState.addManualLog(issueId: '10001', durationSeconds: 1800);
      await tester.pumpAndSettle();

      // PROJ-1 поднялась на 1-е место
      expect(
        appState.filteredIssues.map((i) => i.key).toList(),
        ['PROJ-1', 'PROJ-2', 'PROJ-3'],
      );
    },
  );

  testWidgets(
    'Кнопка «Собрать день» активна при выборе лога, пересобирает день и переключает во вкладку «День»',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      store.saveLogAndIssue(
        issue: store.getIssues(scope: 'default').single,
        log: LocalLog(
          id: 'log-rebuild-1',
          scope: 'default',
          issueId: '10001',
          titleSnapshot: 'Первый лог',
          accumulatedSeconds: 3600,
          createdAtUtc: currentTime,
        ),
      );
      store.saveLogAndIssue(
        issue: store.getIssues(scope: 'default').single,
        log: LocalLog(
          id: 'log-rebuild-2',
          scope: 'default',
          issueId: '10001',
          titleSnapshot: 'Второй лог',
          accumulatedSeconds: 3600,
          createdAtUtc: currentTime,
        ),
      );

      final appState = createAppState();
      await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
      await tester.pumpAndSettle();

      // 1. Сначала ничего не выбрано — кнопка неактивна
      final buildButtonFinder = find.widgetWithText(FilledButton, 'Собрать день');
      expect(tester.widget<FilledButton>(buildButtonFinder).onPressed, isNull);

      // 2. Выбираем первый лог — кнопка становится активной
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(buildButtonFinder).onPressed, isNotNull);

      // Нажимаем «Собрать день»
      await tester.tap(buildButtonFinder);
      await tester.pumpAndSettle();

      // Перешли во вкладку «День»
      expect(appState.selectedTabIndex, 1);
      expect(
        appState.currentDraftLogs.map((d) => d.sourceLogId).toList(),
        ['log-rebuild-1'],
      );

      // 3. Возвращаемся на вкладку «Работа»
      appState.selectTab(0);
      await tester.pumpAndSettle();

      // Чекбокс первого лога отмечен (он в черновике)
      expect(tester.widget<Checkbox>(checkboxes.first).value, isTrue);

      // Кнопка «Собрать день» ДОЛЖНА БЫТЬ АКТИВНА без необходимости сбрасывать чекбокс!
      expect(tester.widget<FilledButton>(buildButtonFinder).onPressed, isNotNull);

      // Нажимаем «Собрать день» повторно без изменения чекбоксов — день снова пересобирается и переходим на «День»
      await tester.tap(buildButtonFinder);
      await tester.pumpAndSettle();
      expect(appState.selectedTabIndex, 1);

      // 4. Снова возвращаемся на вкладку «Работа» и выбираем второй лог
      appState.selectTab(0);
      await tester.pumpAndSettle();

      // Выбираем второй лог (теперь выбраны оба)
      final secondCheckbox = find.byType(Checkbox).last;
      await tester.tap(secondCheckbox);
      await tester.pumpAndSettle();

      // Кнопка активна, нажимаем повторно
      expect(tester.widget<FilledButton>(buildButtonFinder).onPressed, isNotNull);
      await tester.tap(buildButtonFinder);
      await tester.pumpAndSettle();

      // Пересобрали день с обоими логами и снова перешли на «День»
      expect(appState.selectedTabIndex, 1);
      expect(
        appState.currentDraftLogs.map((d) => d.sourceLogId).toSet(),
        {'log-rebuild-1', 'log-rebuild-2'},
      );
      expect(appState.isLogInDraft('log-rebuild-1'), isTrue);
      expect(appState.isLogInDraft('log-rebuild-2'), isTrue);

      // 5. Возвращаемся на вкладку «Работа» и снимаем первый чекбокс
      appState.selectTab(0);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      // Кнопка остаётся активной, так как второй лог всё ещё выбран
      expect(tester.widget<FilledButton>(buildButtonFinder).onPressed, isNotNull);
      await tester.tap(buildButtonFinder);
      await tester.pumpAndSettle();

      expect(appState.selectedTabIndex, 1);
      expect(
        appState.currentDraftLogs.map((d) => d.sourceLogId).toList(),
        ['log-rebuild-2'],
      );
      expect(appState.isLogInDraft('log-rebuild-1'), isFalse);
      expect(appState.isLogInDraft('log-rebuild-2'), isTrue);

      // 6. Снимаем оставшийся чекбокс — кнопка становится неактивной
      appState.selectTab(0);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(buildButtonFinder).onPressed, isNull);
    },
  );
}
