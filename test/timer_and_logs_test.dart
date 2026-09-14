import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/log_clock.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';

void main() {
  group('LogClock чистый модуль расчёта времени', () {
    final t0 = DateTime.utc(2026, 9, 14, 10, 0, 0);

    test('Остановленный лог возвращает accumulatedSeconds', () {
      final log = LocalLog(
        id: '1',
        scope: 'default',
        issueId: '100',
        titleSnapshot: 'Тест',
        accumulatedSeconds: 3600,
        runningSinceUtc: null,
        createdAtUtc: t0,
      );

      final res = LogClock.calculateElapsed(
        log: log,
        nowUtc: t0.add(const Duration(hours: 2)),
      );
      expect(res.elapsedSeconds, 3600);
      expect(res.hasClockRollback, isFalse);
    });

    test(
      'Работающий лог прибавляет разницу nowUtc - runningSinceUtc (A03)',
      () {
        final log = LocalLog(
          id: '1',
          scope: 'default',
          issueId: '100',
          titleSnapshot: 'Тест',
          accumulatedSeconds: 600,
          runningSinceUtc: t0,
          createdAtUtc: t0,
        );

        // Прошло 15 минут (900 секунд)
        final now = t0.add(const Duration(minutes: 15));
        final res = LogClock.calculateElapsed(log: log, nowUtc: now);
        expect(res.elapsedSeconds, 600 + 900);
        expect(res.hasClockRollback, isFalse);
      },
    );

    test(
      'Отрицательная разница при переводе системных часов назад распознается как ошибка',
      () {
        final log = LocalLog(
          id: '1',
          scope: 'default',
          issueId: '100',
          titleSnapshot: 'Тест',
          accumulatedSeconds: 600,
          runningSinceUtc: t0,
          createdAtUtc: t0,
        );

        // Часы переведены на 5 минут назад относительно старта
        final pastTime = t0.subtract(const Duration(minutes: 5));
        final res = LogClock.calculateElapsed(log: log, nowUtc: pastTime);
        expect(res.hasClockRollback, isTrue);
        expect(
          res.errorMessage,
          contains('системные часы были переведены назад'),
        );
        expect(res.elapsedSeconds, 600); // не уходит в минус
      },
    );

    test('start и pause переходы состояния', () {
      final log = LocalLog(
        id: '1',
        scope: 'default',
        issueId: '100',
        titleSnapshot: 'Тест',
        accumulatedSeconds: 0,
        runningSinceUtc: null,
        createdAtUtc: t0,
      );

      // Start
      final started = LogClock.start(log: log, nowUtc: t0);
      expect(started.isRunning, isTrue);
      expect(started.runningSinceUtc, t0);

      // Pause через 10 минут
      final t1 = t0.add(const Duration(minutes: 10));
      final (paused, result) = LogClock.pause(log: started, nowUtc: t1);
      expect(paused.isRunning, isFalse);
      expect(paused.runningSinceUtc, isNull);
      expect(paused.accumulatedSeconds, 600);
      expect(result.elapsedSeconds, 600);
      expect(result.hasClockRollback, isFalse);
    });

    test('Форматирование длительности formatHoursMinutes и formatDigital', () {
      expect(LogClock.formatHoursMinutes(10800), '3ч 00м');
      expect(LogClock.formatHoursMinutes(3720), '1ч 02м');
      expect(LogClock.formatHoursMinutes(900), '15м');
      expect(LogClock.formatHoursMinutes(0), '0м');

      expect(LogClock.formatDigital(0), '00:00:00');
      expect(LogClock.formatDigital(65), '00:01:05');
      expect(LogClock.formatDigital(3665), '01:01:05');
    });
  });

  group('Таймеры и ручной ввод (Сценарии A01, A02, A03, A04)', () {
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
      currentTime = DateTime.utc(2026, 9, 14, 9, 0, 0);

      // Добавим 2 тестовые задачи в SQLite
      store.upsertIssue(
        Issue(
          scope: 'default',
          issueId: '10001',
          key: 'PROJ-1',
          summary: 'Первая задача',
          lastUsedAtUtc: currentTime,
        ),
      );
      store.upsertIssue(
        Issue(
          scope: 'default',
          issueId: '10002',
          key: 'PROJ-2',
          summary: 'Вторая задача',
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

    test('A01: Ручной ввод 3 часов без описания и play', () async {
      final appState = createAppState();

      // Ручной ввод 3 часов = 10 800 секунд
      final log = await appState.addManualLog(
        issueId: '10001',
        durationSeconds: 10800,
        description: '',
      );

      expect(log.accumulatedSeconds, 10800);
      expect(log.isRunning, isFalse);
      expect(log.titleSnapshot, 'Первая задача');
      expect(log.description, '');

      // Проверяем сохранение в базе
      final reloadedLog = store.getLocalLog(log.id);
      expect(reloadedLog, isNotNull);
      expect(reloadedLog!.accumulatedSeconds, 10800);
      expect(reloadedLog.isRunning, isFalse);

      // Задача поднялась в активности
      expect(appState.issues.first.issueId, '10001');

      // Лог виден в неиспользованных
      expect(appState.unconsumedLogs.length, 1);
      expect(appState.totalUnconsumedSeconds, 10800);
    });

    test('A02: Параллельный запуск двух таймеров на разных задачах', () async {
      final appState = createAppState();

      // Запускаем таймер на PROJ-1
      final log1 = await appState.playTimer('10001');
      expect(log1.isRunning, isTrue);

      // Запускаем таймер на PROJ-2
      final log2 = await appState.playTimer('10002');
      expect(log2.isRunning, isTrue);

      // Оба таймера независимы
      expect(log1.id, isNot(log2.id));
      expect(appState.unconsumedLogs.length, 2);

      // Перематываем время на 15 минут вперёд (900 секунд)
      currentTime = currentTime.add(const Duration(minutes: 15));

      final elapsed1 = LogClock.calculateElapsed(
        log: appState.getCurrentLogForIssue('10001')!,
        nowUtc: currentTime,
      );
      final elapsed2 = LogClock.calculateElapsed(
        log: appState.getCurrentLogForIssue('10002')!,
        nowUtc: currentTime,
      );

      expect(elapsed1.elapsedSeconds, 900);
      expect(elapsed2.elapsedSeconds, 900);
      expect(appState.totalUnconsumedSeconds, 1800);
    });

    test(
      'A03: Start -> stop -> start создаёт отдельные логи; сохранение при рестарте и сне Windows',
      () async {
        final appState1 = createAppState();

        // Старт в T0 (создаёт лог 1)
        final log1 = await appState1.playTimer('10001');

        // Через 10 минут останавливаем (Stop)
        currentTime = currentTime.add(const Duration(minutes: 10));
        final stoppedLog1 = await appState1.pauseTimer('10001');
        expect(stoppedLog1!.isRunning, isFalse);
        expect(stoppedLog1.accumulatedSeconds, 600);
        expect(appState1.getCurrentLogForIssue('10001'), isNull);

        // Прошло 20 минут в паузе
        currentTime = currentTime.add(const Duration(minutes: 20));

        // Снова Play (создаёт отдельный лог 2 с нуля)
        final log2 = await appState1.playTimer('10001');
        expect(log2.id, isNot(log1.id));
        expect(log2.accumulatedSeconds, 0);
        expect(log2.isRunning, isTrue);

        // Работаем 15 минут (900 секунд)
        currentTime = currentTime.add(const Duration(minutes: 15));

        // Имитируем закрытие приложения / сон Windows на 2 часа (7200 секунд)
        // Данные сохраняются в SQLite с runningSinceUtc!
        currentTime = currentTime.add(const Duration(hours: 2));

        // Создаем новый экземпляр AppState (как при повторном открытии программы)
        final appState2 = createAppState();
        final restoredLog = appState2.getCurrentLogForIssue('10001')!;

        expect(restoredLog.id, log2.id);
        expect(restoredLog.isRunning, isTrue);
        final totalElapsed = LogClock.calculateElapsed(
          log: restoredLog,
          nowUtc: currentTime,
        );

        // Прошедшие 2 часа сна корректно учтены для активного лога: 900 + 7200 = 8100 секунд
        expect(totalElapsed.elapsedSeconds, 8100);

        // Останавливаем после открытия
        final finallyStopped = await appState2.pauseTimer('10001');
        expect(finallyStopped!.isRunning, isFalse);
        expect(finallyStopped.accumulatedSeconds, 8100);

        // В итоге в очереди два независимых лога: 600с и 8100с (всего 8700с)
        expect(appState2.unconsumedLogs.length, 2);
        expect(appState2.totalUnconsumedSeconds, 8700);
      },
    );

    test(
      'A04: Каждый старт создаёт новый лог, ручной ввод не затрагивает активный таймер',
      () async {
        final appState = createAppState();

        // Запускаем таймер на PROJ-1
        final log1 = await appState.playTimer('10001');
        currentTime = currentTime.add(
          const Duration(minutes: 10),
        ); // 600 секунд

        // Ручной ввод 1 часа (3600с) на той же задаче при работающем таймере
        final manualLog = await appState.addManualLog(
          issueId: '10001',
          durationSeconds: 3600,
          description: 'Ручная запись',
        );

        expect(manualLog.accumulatedSeconds, 3600);
        expect(manualLog.isRunning, isFalse);

        // Таймер log1 НЕ остановился, НЕ перезаписался и НЕ задвоился!
        final activeLog = appState.getCurrentLogForIssue('10001')!;
        expect(activeLog.id, log1.id);
        expect(activeLog.isRunning, isTrue);

        // Останавливаем таймер на PROJ-1
        currentTime = currentTime.add(
          const Duration(minutes: 5),
        ); // ещё 300 секунд, итого 900
        final stoppedLog1 = await appState.pauseTimer('10001');
        expect(stoppedLog1!.accumulatedSeconds, 900);
        expect(appState.getCurrentLogForIssue('10001'), isNull);

        // Следующий запуск таймера сразу создаёт новый отдельный лог
        final startedNewLog = await appState.playTimer('10001');
        expect(startedNewLog.id, isNot(log1.id));
        expect(startedNewLog.accumulatedSeconds, 0);
        expect(startedNewLog.isRunning, isTrue);
      },
    );

    test('Запуск выбранных задач пакетом (startSelectedIssues)', () async {
      final appState = createAppState();

      appState.toggleIssueSelection('10001');
      appState.toggleIssueSelection('10002');
      expect(appState.selectedIssueIds.length, 2);

      await appState.startSelectedIssues();
      expect(appState.selectedIssueIds.isEmpty, isTrue);

      expect(appState.getCurrentLogForIssue('10001')!.isRunning, isTrue);
      expect(appState.getCurrentLogForIssue('10002')!.isRunning, isTrue);
    });

    test('Редактирование и удаление остановленного лога', () async {
      final appState = createAppState();

      final log = await appState.addManualLog(
        issueId: '10001',
        durationSeconds: 1800,
        description: 'Старое описание',
      );

      // Редактирование
      await appState.editLog(
        logId: log.id,
        durationSeconds: 3600,
        description: 'Новое описание',
      );

      final edited = store.getLocalLog(log.id)!;
      expect(edited.accumulatedSeconds, 3600);
      expect(edited.description, 'Новое описание');

      // Удаление
      await appState.deleteLog(log.id);
      expect(store.getLocalLog(log.id), isNull);
      expect(appState.unconsumedLogs.isEmpty, isTrue);
    });
  });
}
