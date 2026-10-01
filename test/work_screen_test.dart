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
    store.setSetting('ui_language', 'ru');
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

  Future<void> revealLogRow(WidgetTester tester, String id) async {
    final row = find.byKey(ValueKey('log-$id'));
    final pageScroll = find.byType(SingleChildScrollView);
    if (row.evaluate().isEmpty && pageScroll.evaluate().isNotEmpty) {
      await tester.drag(pageScroll.first, const Offset(0, -420));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'AddTimeDialog открывается из строки задачи и сохраняет 3 часа (A01)',
    (WidgetTester tester) async {
      final appState = createAppState();

      await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
      await tester.pumpAndSettle();

      expect(find.text('PROJ-1'), findsOneWidget);
      expect(find.text('Разработка фичи'), findsOneWidget);
      expect(find.text('В работе'), findsOneWidget);

      // Нажимаем «Добавить время» именно в строке задачи.
      final issueRow = find.byKey(const ValueKey('issue-10001'));
      final addTimeBtn = find.descendant(
        of: issueRow,
        matching: find.text('Добавить время'),
      );
      await tester.ensureVisible(addTimeBtn);
      await tester.pumpAndSettle();
      await tester.tap(addTimeBtn);
      await tester.pumpAndSettle();

      // Открылся диалог
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Добавить время'),
        ),
        findsOneWidget,
      );
      expect(find.text('Часы'), findsOneWidget);
      expect(find.text('Минуты'), findsOneWidget);

      // Вводим 3 часа
      final hoursField = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .first;
      await tester.enterText(hoursField, '3');
      await tester.pumpAndSettle();

      // Сохраняем
      await tester.tap(find.text('Сохранить запись'));
      await tester.pumpAndSettle();

      // Диалог закрылся, лог появился в очереди справа
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Очередь'), findsOneWidget);
      expect(find.text('Всего 3ч 00м'), findsOneWidget);
      expect(find.text('3ч 00м'), findsOneWidget);

      // В SQLite 10 800 секунд
      expect(appState.unconsumedLogs.first.accumulatedSeconds, 10800);
      expect(appState.unconsumedLogs.first.isRunning, isFalse);
    },
  );

  testWidgets('Запуск и остановка таймера в строке задачи в UI (A03)', (
    WidgetTester tester,
  ) async {
    final appState = createAppState();

    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();

    // Кнопка «Новый лог на задаче» (playlist_add) убрана за ненадобностью
    expect(find.byIcon(Icons.playlist_add), findsNothing);

    // Кликаем текстовое действие запуска в строке задачи.
    final issueRow = find.byKey(const ValueKey('issue-10001'));
    final playBtn = find.descendant(
      of: issueRow,
      matching: find.text('Начать'),
    );
    await tester.ensureVisible(playBtn);
    await tester.pumpAndSettle();
    await tester.tap(playBtn);
    await tester.pumpAndSettle();

    // Таймер запустился: действие стало «Остановить».
    final stopBtn = find.descendant(
      of: issueRow,
      matching: find.text('Остановить'),
    );
    expect(stopBtn, findsOneWidget);
    expect(appState.unconsumedLogs.first.isRunning, isTrue);

    // Перематываем время на 10 минут
    currentTime = currentTime.add(const Duration(minutes: 10));
    await tester.pump();

    // Кликаем Stop (Остановить таймер)
    await tester.ensureVisible(stopBtn);
    await tester.pumpAndSettle();
    await tester.tap(stopBtn);
    await tester.pumpAndSettle();

    // Таймер остановлен, зафиксировано 10 минут, строка сброшена на 00:00:00
    expect(
      find.descendant(of: issueRow, matching: find.text('Начать')),
      findsOneWidget,
    );
    expect(appState.unconsumedLogs.first.isRunning, isFalse);
    expect(appState.unconsumedLogs.first.accumulatedSeconds, 600);
    await revealLogRow(tester, appState.unconsumedLogs.first.id);
    expect(find.text('Всего 10м'), findsOneWidget);
  });

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

    await revealLogRow(tester, 'log-checkbox');
    final logRow = find.byKey(const ValueKey('log-log-checkbox'));
    final checkbox = find.descendant(
      of: logRow,
      matching: find.byType(Checkbox),
    );
    await tester.tap(checkbox);
    await tester.pump();

    expect(appState.selectedLogIds, contains('log-checkbox'));
    expect(find.text('Выбрано 1 запись'), findsOneWidget);
    expect(find.text('30м исходного времени'), findsOneWidget);

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

    await revealLogRow(tester, logId);
    final logRow = find.byKey(const ValueKey('log-log-in-draft'));
    final checkboxFinder = find.descendant(
      of: logRow,
      matching: find.byType(Checkbox),
    );
    final checkbox = tester.widget<Checkbox>(checkboxFinder);
    expect(checkbox.value, isTrue);
    expect(checkbox.onChanged, isNotNull);

    await tester.tap(checkboxFinder);
    await tester.pumpAndSettle();

    expect(appState.isLogInDraft(logId), isFalse);
    expect(appState.currentDraft, isNull);
    expect(tester.widget<Checkbox>(checkboxFinder).value, isFalse);
  });

  testWidgets(
    'Лог из другого дня показывает статус вместо выбора для текущей даты',
    (WidgetTester tester) async {
      final appState = createAppState();
      final log = await appState.addManualLog(
        issueId: '10001',
        durationSeconds: 1800,
      );
      appState.setSelectedDate(DateTime(2026, 9, 13));
      appState.toggleLogSelection(log.id);
      await appState.buildDay(customSeed: 42);
      appState.setSelectedDate(DateTime(2026, 9, 14));

      await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
      await tester.pumpAndSettle();

      await revealLogRow(tester, log.id);
      final logRow = find.byKey(ValueKey('log-${log.id}'));
      expect(
        find.descendant(of: logRow, matching: find.byType(Checkbox)),
        findsNothing,
      );
      expect(find.text('В дне 13.09.2026 · Открыть'), findsOneWidget);
      expect(find.text('Для 14 сентября записи не выбраны'), findsOneWidget);

      final buildButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Собрать день'),
      );
      expect(buildButton.onPressed, isNull);
    },
  );

  testWidgets('Лог можно явно убрать из черновика другого дня', (
    WidgetTester tester,
  ) async {
    final appState = createAppState();
    final log = await appState.addManualLog(
      issueId: '10001',
      durationSeconds: 1800,
    );
    appState.setSelectedDate(DateTime(2026, 9, 13));
    appState.toggleLogSelection(log.id);
    await appState.buildDay(customSeed: 42);
    appState.setSelectedDate(DateTime(2026, 9, 14));

    await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
    await tester.pumpAndSettle();

    await revealLogRow(tester, log.id);
    await tester.tap(find.byKey(ValueKey('draft-actions-${log.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Убрать из дня 13.09.2026'));
    await tester.pumpAndSettle();

    expect(appState.isLogInDraft(log.id), isFalse);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('log-${log.id}')),
        matching: find.byType(Checkbox),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Строка задачи показывает статус и соседние действия таймера и ручного времени',
    (WidgetTester tester) async {
      final appState = createAppState();

      await tester.pumpWidget(JiraTimeTrackerApp(appState: appState));
      await tester.pumpAndSettle();

      // Ключ и обычный текстовый статус расположены в верхней строке задачи.
      final statusFinder = find.text('В работе');
      final keyFinder = find.text('PROJ-1');
      expect(statusFinder, findsOneWidget);
      expect(keyFinder, findsOneWidget);

      final issueRow = find.byKey(const ValueKey('issue-10001'));
      await tester.ensureVisible(issueRow);
      await tester.pumpAndSettle();
      final statusRect = tester.getRect(statusFinder);
      final keyRect = tester.getRect(keyFinder);
      final rowRect = tester.getRect(issueRow);

      expect(statusRect.left, greaterThan(keyRect.right));
      expect(rowRect.right - statusRect.right, lessThan(30));

      // Кнопки «Начать» и «Добавить время» находятся в одной нижней строке.
      final playBtn = find.descendant(
        of: issueRow,
        matching: find.text('Начать'),
      );
      final addTimeBtn = find.descendant(
        of: issueRow,
        matching: find.text('Добавить время'),
      );
      expect(playBtn, findsOneWidget);
      expect(addTimeBtn, findsOneWidget);

      final playRect = tester.getRect(playBtn);
      final addTimeRect = tester.getRect(addTimeBtn);
      expect((playRect.center.dy - addTimeRect.center.dy).abs(), lessThan(2));
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
      expect(appState.filteredIssues.map((i) => i.key).toList(), [
        'PROJ-1',
        'PROJ-2',
        'PROJ-3',
      ]);

      // 1. Включаем лог (таймер) на нижней задаче PROJ-3 в 10:30
      currentTime = DateTime.utc(2026, 9, 14, 10, 30, 0);
      await appState.playTimer('10003');
      await tester.pumpAndSettle();

      // PROJ-3 стала активной и переместилась на 1-е место!
      expect(appState.filteredIssues.map((i) => i.key).toList(), [
        'PROJ-3',
        'PROJ-1',
        'PROJ-2',
      ]);

      // 2. Выключаем лог на PROJ-3 в 10:45
      currentTime = DateTime.utc(2026, 9, 14, 10, 45, 0);
      await appState.pauseTimer('10003');
      await tester.pumpAndSettle();

      // PROJ-3 остаётся вверху, так как с ней взаимодействовали только что (10:45)
      expect(appState.filteredIssues.map((i) => i.key).toList(), [
        'PROJ-3',
        'PROJ-1',
        'PROJ-2',
      ]);

      // 3. Включаем лог на PROJ-2 в 11:00
      currentTime = DateTime.utc(2026, 9, 14, 11, 0, 0);
      await appState.playTimer('10002');
      await tester.pumpAndSettle();

      // PROJ-2 поднялась на 1-е место.
      // PROJ-1 (с которой не работали с 10:00) ушла в самый низ!
      expect(appState.filteredIssues.map((i) => i.key).toList(), [
        'PROJ-2',
        'PROJ-3',
        'PROJ-1',
      ]);

      // 4. Выключаем лог на PROJ-2 в 11:15
      currentTime = DateTime.utc(2026, 9, 14, 11, 15, 0);
      await appState.pauseTimer('10002');
      await tester.pumpAndSettle();

      expect(appState.filteredIssues.map((i) => i.key).toList(), [
        'PROJ-2',
        'PROJ-3',
        'PROJ-1',
      ]);

      // 5. Вносим ручной лог на PROJ-1 в 11:30
      currentTime = DateTime.utc(2026, 9, 14, 11, 30, 0);
      await appState.addManualLog(issueId: '10001', durationSeconds: 1800);
      await tester.pumpAndSettle();

      // PROJ-1 поднялась на 1-е место
      expect(appState.filteredIssues.map((i) => i.key).toList(), [
        'PROJ-1',
        'PROJ-2',
        'PROJ-3',
      ]);
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
      final buildButtonFinder = find.widgetWithText(
        FilledButton,
        'Собрать день',
      );
      expect(tester.widget<FilledButton>(buildButtonFinder).onPressed, isNull);

      // 2. Выбираем первый лог — кнопка становится активной
      await revealLogRow(tester, 'log-rebuild-1');
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));
      final firstCheckbox = find.descendant(
        of: find.byKey(const ValueKey('log-log-rebuild-1')),
        matching: find.byType(Checkbox),
      );
      await tester.tap(firstCheckbox);
      await tester.pumpAndSettle();

      expect(
        tester.widget<FilledButton>(buildButtonFinder).onPressed,
        isNotNull,
      );

      // Нажимаем «Собрать день»
      await tester.tap(buildButtonFinder);
      await tester.pumpAndSettle();

      // Перешли во вкладку «День»
      expect(appState.selectedTabIndex, 1);
      expect(appState.currentDraftLogs.map((d) => d.sourceLogId).toList(), [
        'log-rebuild-1',
      ]);

      // 3. Возвращаемся на вкладку «Работа»
      appState.selectTab(0);
      await tester.pumpAndSettle();

      // Чекбокс первого лога отмечен (он в черновике)
      await revealLogRow(tester, 'log-rebuild-1');
      expect(tester.widget<Checkbox>(firstCheckbox).value, isTrue);

      // Кнопка «Собрать день» ДОЛЖНА БЫТЬ АКТИВНА без необходимости сбрасывать чекбокс!
      expect(
        tester.widget<FilledButton>(buildButtonFinder).onPressed,
        isNotNull,
      );

      // Нажимаем «Собрать день» повторно без изменения чекбоксов — день снова пересобирается и переходим на «День»
      await tester.tap(buildButtonFinder);
      await tester.pumpAndSettle();
      expect(appState.selectedTabIndex, 1);

      // 4. Снова возвращаемся на вкладку «Работа» и выбираем второй лог
      appState.selectTab(0);
      await tester.pumpAndSettle();

      // Выбираем второй лог (теперь выбраны оба)
      await revealLogRow(tester, 'log-rebuild-2');
      final secondCheckbox = find.descendant(
        of: find.byKey(const ValueKey('log-log-rebuild-2')),
        matching: find.byType(Checkbox),
      );
      await tester.tap(secondCheckbox);
      await tester.pumpAndSettle();

      // Кнопка активна, нажимаем повторно
      expect(
        tester.widget<FilledButton>(buildButtonFinder).onPressed,
        isNotNull,
      );
      await tester.tap(buildButtonFinder);
      await tester.pumpAndSettle();

      // Пересобрали день с обоими логами и снова перешли на «День»
      expect(appState.selectedTabIndex, 1);
      expect(appState.currentDraftLogs.map((d) => d.sourceLogId).toSet(), {
        'log-rebuild-1',
        'log-rebuild-2',
      });
      expect(appState.isLogInDraft('log-rebuild-1'), isTrue);
      expect(appState.isLogInDraft('log-rebuild-2'), isTrue);

      // 5. Возвращаемся на вкладку «Работа» и снимаем первый чекбокс
      appState.selectTab(0);
      await tester.pumpAndSettle();

      await revealLogRow(tester, 'log-rebuild-1');
      await tester.tap(firstCheckbox);
      await tester.pumpAndSettle();

      // Кнопка остаётся активной, так как второй лог всё ещё выбран
      expect(
        tester.widget<FilledButton>(buildButtonFinder).onPressed,
        isNotNull,
      );
      await tester.tap(buildButtonFinder);
      await tester.pumpAndSettle();

      expect(appState.selectedTabIndex, 1);
      expect(appState.currentDraftLogs.map((d) => d.sourceLogId).toList(), [
        'log-rebuild-2',
      ]);
      expect(appState.isLogInDraft('log-rebuild-1'), isFalse);
      expect(appState.isLogInDraft('log-rebuild-2'), isTrue);

      // 6. Снимаем оставшийся чекбокс — кнопка становится неактивной
      appState.selectTab(0);
      await tester.pumpAndSettle();

      await revealLogRow(tester, 'log-rebuild-2');
      await tester.tap(secondCheckbox);
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(buildButtonFinder).onPressed, isNull);
    },
  );
}
