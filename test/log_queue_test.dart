import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
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
    currentTime = DateTime.utc(2026, 9, 14, 12, 0, 0);

    // Создадим задачу двухнедельной давности
    final twoWeeksAgo = currentTime.subtract(const Duration(days: 14));
    store.upsertIssue(
      Issue(
        scope: 'default',
        issueId: '20001',
        key: 'OLD-1',
        summary: 'Старая задача из Jira',
        lastUsedAtUtc: twoWeeksAgo,
      ),
    );

    // Создадим задачу текущей недели
    store.upsertIssue(
      Issue(
        scope: 'default',
        issueId: '20002',
        key: 'NEW-2',
        summary: 'Свежая задача из Jira',
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

  test(
    'A11: Невыбранный лог прошлой недели доступен в очереди и не удаляется фильтрами',
    () async {
      final appState = createAppState();

      // Перемещаемся на 10 дней назад, когда создавался лог
      currentTime = currentTime.subtract(const Duration(days: 10));
      final logLastWeek = await appState.addManualLog(
        issueId: '20001',
        durationSeconds: 7200,
        description: 'Работа прошлой недели',
      );

      // Возвращаемся в текущий день (сегодня)
      currentTime = currentTime.add(const Duration(days: 10));
      await appState.loadIssues();

      // Включаем фильтр каталога задач «7 дней»
      appState.setIssueFilterPeriod(IssueFilterPeriod.days7);

      // В левом списке задач OLD-1 скрыта из-за фильтра
      expect(appState.filteredIssues.any((i) => i.issueId == '20001'), isFalse);
      expect(appState.filteredIssues.any((i) => i.issueId == '20002'), isTrue);

      // НО в очереди логов запись прошлой недели видна, не удалена и доступна для выбора!
      expect(appState.unconsumedLogs.length, 1);
      expect(appState.unconsumedLogs.first.id, logLastWeek.id);

      // Лог можно выбрать для сборки любого дня
      appState.toggleLogSelection(logLastWeek.id);
      expect(appState.selectedLogIds.contains(logLastWeek.id), isTrue);
      expect(appState.totalSelectedSeconds, 7200);
    },
  );

  test(
    'Разделение summary задачи vs пользовательское описание (A04)',
    () async {
      final appState = createAppState();

      final log = await appState.addManualLog(
        issueId: '20002',
        durationSeconds: 3600,
        description: 'Первоначальное описание',
      );

      // Заголовок взят из задачи
      expect(log.titleSnapshot, 'Свежая задача из Jira');
      expect(log.description, 'Первоначальное описание');

      // Редактируем лог
      await appState.editLog(
        logId: log.id,
        durationSeconds: 5400,
        description: 'Исправленное описание сделанного',
      );

      final reloaded = store.getLocalLog(log.id)!;
      // Summary задачи не изменилось!
      expect(reloaded.titleSnapshot, 'Свежая задача из Jira');
      expect(reloaded.description, 'Исправленное описание сделанного');
      expect(reloaded.accumulatedSeconds, 5400);

      final issueInDb = store.getIssue('default', '20002')!;
      expect(issueInDb.summary, 'Свежая задача из Jira');
    },
  );

  test(
    'Работающий лог нельзя выбрать в сборку, отредактировать или удалить',
    () async {
      final appState = createAppState();

      final runningLog = await appState.playTimer('20002');
      expect(runningLog.isRunning, isTrue);

      // Попытка выбора в сборку
      appState.toggleLogSelection(runningLog.id);
      expect(appState.selectedLogIds.contains(runningLog.id), isFalse);

      // Попытка редактирования работающего лога вызывает исключение
      expect(
        () => appState.editLog(
          logId: runningLog.id,
          durationSeconds: 3600,
          description: 'Новое',
        ),
        throwsStateError,
      );

      // Попытка удаления работающего лога вызывает исключение
      expect(() => appState.deleteLog(runningLog.id), throwsStateError);

      // После паузы все операции разрешены
      await appState.pauseTimer('20002');
      appState.toggleLogSelection(runningLog.id);
      expect(appState.selectedLogIds.contains(runningLog.id), isTrue);
    },
  );

  test('Защита лога, включенного в черновик дня', () async {
    final appState = createAppState();

    final log = await appState.addManualLog(
      issueId: '20002',
      durationSeconds: 3600,
      description: 'Лог для черновика',
    );

    // Создадим в SQLite черновик дня и привяжем к нему лог
    final draftId = 'draft-101';
    db.execute(
      '''
      INSERT INTO day_drafts (id, scope, date, start_utc, end_utc, seed, settings_snapshot, imported_worklogs_snapshot, status)
      VALUES (?, 'default', '2026-09-15', '2026-09-15T08:00:00Z', '2026-09-15T16:00:00Z', 12345, '{}', '[]', 'draft');
    ''',
      [draftId],
    );

    db.execute(
      '''
      INSERT INTO draft_logs (draft_id, source_log_id, source_duration_seconds, description_snapshot, duration_locked)
      VALUES (?, ?, 3600, 'Лог для черновика', 0);
    ''',
      [draftId, log.id],
    );

    await appState.loadLogs();

    // Проверяем статус в черновике
    expect(appState.isLogInDraft(log.id), isTrue);
    expect(appState.getDraftDateForLog(log.id), '2026-09-15');

    // Нельзя выбрать повторно для другого дня
    appState.toggleLogSelection(log.id);
    expect(appState.selectedLogIds.contains(log.id), isFalse);

    // Нельзя редактировать или удалить напрямую
    expect(
      () => appState.editLog(
        logId: log.id,
        durationSeconds: 7200,
        description: 'Попытка изменения',
      ),
      throwsStateError,
    );

    expect(() => appState.deleteLog(log.id), throwsStateError);
  });
}
