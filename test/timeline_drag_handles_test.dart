import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';

void main() {
  group('Timeline Drag Handles Math in AppState (Ticket 01)', () {
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

    AppState createTestAppState() {
      final connectionStore = ConnectionStore(
        secureStorage: InMemorySecureStorage(),
      );
      return AppState(
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
    }

    void seedIssuesAndLogs() {
      final now = DateTime.utc(2026, 9, 14, 8, 0);
      for (int i = 1; i <= 3; i++) {
        final issue = Issue(
          scope: testScope,
          issueId: '$i',
          key: 'PROJ-$i',
          summary: 'Задача $i',
          lastUsedAtUtc: now,
        );
        final log = LocalLog(
          id: 'log-$i',
          scope: testScope,
          issueId: '$i',
          titleSnapshot: 'PROJ-$i',
          accumulatedSeconds: 3600,
          createdAtUtc: now,
        );
        store.saveLogsAndIssue(logs: [log], issue: issue);
      }
    }

    test('resizeSegmentRight: удлинение задачи сдвигает весь правый хвост синхронно на ту же дельту', () {
      seedIssuesAndLogs();
      final appState = createTestAppState();

      // Задача 1: 09:00 - 10:00 (1 ч)
      // Пауза: 10:00 - 10:30 (30 мин)
      // Задача 2: 10:30 - 11:30 (1 ч)
      final draft = DayDraft(
        id: 'draft-1',
        scope: testScope,
        date: '2026-09-14',
        startUtc: DateTime.utc(2026, 9, 14, 9, 0),
        endUtc: DateTime.utc(2026, 9, 14, 18, 0),
        seed: 42,
        settingsSnapshot: '{}',
        importedWorklogsSnapshot: '[]',
        status: DraftStatus.draft,
      );

      final seg1 = Segment(
        id: 'seg-1',
        draftId: 'draft-1',
        sourceLogId: 'log-1',
        issueId: '1',
        startUtc: DateTime.utc(2026, 9, 14, 9, 0),
        durationSeconds: 3600,
        description: 'Задача 1',
        sendState: SendState.pending,
      );
      final seg2 = Segment(
        id: 'seg-2',
        draftId: 'draft-1',
        sourceLogId: 'log-2',
        issueId: '2',
        startUtc: DateTime.utc(2026, 9, 14, 10, 30),
        durationSeconds: 3600,
        description: 'Задача 2',
        sendState: SendState.pending,
      );

      store.saveDayDraft(
        draft: draft,
        draftLogs: [
          const DraftLog(draftId: 'draft-1', sourceLogId: 'log-1', sourceDurationSeconds: 3600, descriptionSnapshot: '', durationLocked: false),
          const DraftLog(draftId: 'draft-1', sourceLogId: 'log-2', sourceDurationSeconds: 3600, descriptionSnapshot: '', durationLocked: false),
        ],
        segments: [seg1, seg2],
        breaks: [],
      );

      appState.setSelectedDate(DateTime(2026, 9, 14));

      // Удлиняем Задачу 1 с 1 часа (3600) до 1.5 часов (5400) (+30 мин)
      appState.resizeSegmentRight(seg1, 5400);

      final res1 = appState.currentSegments.firstWhere((s) => s.id == 'seg-1');
      expect(res1.startUtc, equals(DateTime.utc(2026, 9, 14, 9, 0)));
      expect(res1.durationSeconds, equals(5400)); // 09:00 - 10:30

      // Задача 2 сдвинулась ровно на +30 мин: стала 11:00 - 12:00
      // Пауза 30 мин между ними сохранилась (10:30 - 11:00)!
      final res2 = appState.currentSegments.firstWhere((s) => s.id == 'seg-2');
      expect(res2.startUtc, equals(DateTime.utc(2026, 9, 14, 11, 0)));
      expect(res2.durationSeconds, equals(3600));
    });

    test('resizeSegmentRight: укорачивание задачи подтягивает весь правый хвост влево с ограничением мин. 10 минут', () {
      seedIssuesAndLogs();
      final appState = createTestAppState();

      final draft = DayDraft(
        id: 'draft-1',
        scope: testScope,
        date: '2026-09-14',
        startUtc: DateTime.utc(2026, 9, 14, 9, 0),
        endUtc: DateTime.utc(2026, 9, 14, 18, 0),
        seed: 42,
        settingsSnapshot: '{}',
        importedWorklogsSnapshot: '[]',
        status: DraftStatus.draft,
      );

      final seg1 = Segment(
        id: 'seg-1',
        draftId: 'draft-1',
        sourceLogId: 'log-1',
        issueId: '1',
        startUtc: DateTime.utc(2026, 9, 14, 9, 0),
        durationSeconds: 3600,
        description: 'Задача 1',
        sendState: SendState.pending,
      );
      final seg2 = Segment(
        id: 'seg-2',
        draftId: 'draft-1',
        sourceLogId: 'log-2',
        issueId: '2',
        startUtc: DateTime.utc(2026, 9, 14, 10, 0),
        durationSeconds: 3600,
        description: 'Задача 2',
        sendState: SendState.pending,
      );

      store.saveDayDraft(
        draft: draft,
        draftLogs: [
          const DraftLog(draftId: 'draft-1', sourceLogId: 'log-1', sourceDurationSeconds: 3600, descriptionSnapshot: '', durationLocked: false),
          const DraftLog(draftId: 'draft-1', sourceLogId: 'log-2', sourceDurationSeconds: 3600, descriptionSnapshot: '', durationLocked: false),
        ],
        segments: [seg1, seg2],
        breaks: [],
      );

      appState.setSelectedDate(DateTime(2026, 9, 14));

      // Укорачиваем Задачу 1 с 1 часа (3600) до 20 минут (1200) (-40 мин)
      appState.resizeSegmentRight(seg1, 1200);

      final res1 = appState.currentSegments.firstWhere((s) => s.id == 'seg-1');
      expect(res1.durationSeconds, equals(1200)); // 09:00 - 09:20

      // Задача 2 подтянулась влево на 40 мин: стала 09:20 - 10:20
      final res2 = appState.currentSegments.firstWhere((s) => s.id == 'seg-2');
      expect(res2.startUtc, equals(DateTime.utc(2026, 9, 14, 9, 20)));
      expect(res2.durationSeconds, equals(3600));

      // Попытка сжать меньше 10 минут (300 сек -> клампится до 600 сек / 10 мин)
      appState.resizeSegmentRight(res1, 300);
      final resClamped = appState.currentSegments.firstWhere((s) => s.id == 'seg-1');
      expect(resClamped.durationSeconds, equals(600)); // ровно 10 мин (09:00 - 09:10)
    });

    test('resizeSegmentLeft: движение вправо укорачивает задачу и создает паузу перед ней (сосед слева неподвижен)', () {
      seedIssuesAndLogs();
      final appState = createTestAppState();

      final draft = DayDraft(
        id: 'draft-1',
        scope: testScope,
        date: '2026-09-14',
        startUtc: DateTime.utc(2026, 9, 14, 9, 0),
        endUtc: DateTime.utc(2026, 9, 14, 18, 0),
        seed: 42,
        settingsSnapshot: '{}',
        importedWorklogsSnapshot: '[]',
        status: DraftStatus.draft,
      );

      // Задача 1: 09:00 - 10:00 (1 ч)
      // Задача 2: 10:00 - 11:00 (1 ч) - встык
      final seg1 = Segment(
        id: 'seg-1',
        draftId: 'draft-1',
        sourceLogId: 'log-1',
        issueId: '1',
        startUtc: DateTime.utc(2026, 9, 14, 9, 0),
        durationSeconds: 3600,
        description: 'Задача 1',
        sendState: SendState.pending,
      );
      final seg2 = Segment(
        id: 'seg-2',
        draftId: 'draft-1',
        sourceLogId: 'log-2',
        issueId: '2',
        startUtc: DateTime.utc(2026, 9, 14, 10, 0),
        durationSeconds: 3600,
        description: 'Задача 2',
        sendState: SendState.pending,
      );

      store.saveDayDraft(
        draft: draft,
        draftLogs: [
          const DraftLog(draftId: 'draft-1', sourceLogId: 'log-1', sourceDurationSeconds: 3600, descriptionSnapshot: '', durationLocked: false),
          const DraftLog(draftId: 'draft-1', sourceLogId: 'log-2', sourceDurationSeconds: 3600, descriptionSnapshot: '', durationLocked: false),
        ],
        segments: [seg1, seg2],
        breaks: [],
      );

      appState.setSelectedDate(DateTime(2026, 9, 14));

      // Двигаем левый край Задачи 2 вправо: с 10:00 на 10:20
      appState.resizeSegmentLeft(seg2, DateTime.utc(2026, 9, 14, 10, 20));

      // Сосед слева (Задача 1) остался ровно 09:00 - 10:00 (3600 сек), не удлинился!
      final res1 = appState.currentSegments.firstWhere((s) => s.id == 'seg-1');
      expect(res1.startUtc, equals(DateTime.utc(2026, 9, 14, 9, 0)));
      expect(res1.durationSeconds, equals(3600));

      // Задача 2 стала 10:20 - 11:00 (длительность 2400 с / 40 мин, окончание 11:00 зафиксировано)
      final res2 = appState.currentSegments.firstWhere((s) => s.id == 'seg-2');
      expect(res2.startUtc, equals(DateTime.utc(2026, 9, 14, 10, 20)));
      expect(res2.durationSeconds, equals(2400));
      expect(res2.endUtc, equals(DateTime.utc(2026, 9, 14, 11, 0)));
    });

    test('resizeSegmentLeft: движение влево поглощает паузу перед задачей и жестко упирается в соседа слева', () {
      seedIssuesAndLogs();
      final appState = createTestAppState();

      final draft = DayDraft(
        id: 'draft-1',
        scope: testScope,
        date: '2026-09-14',
        startUtc: DateTime.utc(2026, 9, 14, 9, 0),
        endUtc: DateTime.utc(2026, 9, 14, 18, 0),
        seed: 42,
        settingsSnapshot: '{}',
        importedWorklogsSnapshot: '[]',
        status: DraftStatus.draft,
      );

      // Задача 1: 09:00 - 10:00
      // Пауза: 10:00 - 11:00 (1 ч)
      // Задача 2: 11:00 - 12:00
      final seg1 = Segment(
        id: 'seg-1',
        draftId: 'draft-1',
        sourceLogId: 'log-1',
        issueId: '1',
        startUtc: DateTime.utc(2026, 9, 14, 9, 0),
        durationSeconds: 3600,
        description: 'Задача 1',
        sendState: SendState.pending,
      );
      final seg2 = Segment(
        id: 'seg-2',
        draftId: 'draft-1',
        sourceLogId: 'log-2',
        issueId: '2',
        startUtc: DateTime.utc(2026, 9, 14, 11, 0),
        durationSeconds: 3600,
        description: 'Задача 2',
        sendState: SendState.pending,
      );

      store.saveDayDraft(
        draft: draft,
        draftLogs: [
          const DraftLog(draftId: 'draft-1', sourceLogId: 'log-1', sourceDurationSeconds: 3600, descriptionSnapshot: '', durationLocked: false),
          const DraftLog(draftId: 'draft-1', sourceLogId: 'log-2', sourceDurationSeconds: 3600, descriptionSnapshot: '', durationLocked: false),
        ],
        segments: [seg1, seg2],
        breaks: [],
      );

      appState.setSelectedDate(DateTime(2026, 9, 14));

      // Пытаемся затянуть левый край Задачи 2 на 09:30 (что глубже соседа слева 10:00)
      appState.resizeSegmentLeft(seg2, DateTime.utc(2026, 9, 14, 9, 30));

      // Задача 1 не сжалась! Она осталась 09:00 - 10:00
      final res1 = appState.currentSegments.firstWhere((s) => s.id == 'seg-1');
      expect(res1.startUtc, equals(DateTime.utc(2026, 9, 14, 9, 0)));
      expect(res1.durationSeconds, equals(3600));

      // Задача 2 уперлась в 10:00: стала 10:00 - 12:00 (7200 с / 2 ч)
      final res2 = appState.currentSegments.firstWhere((s) => s.id == 'seg-2');
      expect(res2.startUtc, equals(DateTime.utc(2026, 9, 14, 10, 0)));
      expect(res2.durationSeconds, equals(7200));
    });

    test('resizeSegmentRight: при выталкивании волной в запись Jira выдает ошибку с указанием доступного времени', () {
      seedIssuesAndLogs();
      final appState = createTestAppState();

      // Задача 1: 09:00 - 10:00
      // Задача 2: 10:00 - 11:00
      // Jira Worklog: 11:30 - 12:30
      // Доступно свободного времени перед Jira: 30 минут (1800 с)
      final draft = DayDraft(
        id: 'draft-1',
        scope: testScope,
        date: '2026-09-14',
        startUtc: DateTime.utc(2026, 9, 14, 9, 0),
        endUtc: DateTime.utc(2026, 9, 14, 18, 0),
        seed: 42,
        settingsSnapshot: '{}',
        importedWorklogsSnapshot: '[{"worklogId":"wl-1","issueKey":"PROJ-1","startUtc":"2026-09-14T11:30:00.000Z","durationSeconds":3600,"authorDisplayName":"Tester"}]',
        status: DraftStatus.draft,
      );

      final seg1 = Segment(
        id: 'seg-1',
        draftId: 'draft-1',
        sourceLogId: 'log-1',
        issueId: '1',
        startUtc: DateTime.utc(2026, 9, 14, 9, 0),
        durationSeconds: 3600,
        description: 'Задача 1',
        sendState: SendState.pending,
      );
      final seg2 = Segment(
        id: 'seg-2',
        draftId: 'draft-1',
        sourceLogId: 'log-2',
        issueId: '2',
        startUtc: DateTime.utc(2026, 9, 14, 10, 0),
        durationSeconds: 3600,
        description: 'Задача 2',
        sendState: SendState.pending,
      );

      store.saveDayDraft(
        draft: draft,
        draftLogs: [
          const DraftLog(draftId: 'draft-1', sourceLogId: 'log-1', sourceDurationSeconds: 3600, descriptionSnapshot: '', durationLocked: false),
          const DraftLog(draftId: 'draft-1', sourceLogId: 'log-2', sourceDurationSeconds: 3600, descriptionSnapshot: '', durationLocked: false),
        ],
        segments: [seg1, seg2],
        breaks: [],
      );

      appState.setSelectedDate(DateTime(2026, 9, 14));
      appState.setImportedWorklogs([
        ImportedWorklog(
          id: 'wl-1',
          issueId: '1',
          issueKey: 'PROJ-1',
          startUtc: DateTime.utc(2026, 9, 14, 11, 30),
          durationSeconds: 3600,
          authorAccountId: 'acc-123',
        ),
      ]);

      // Пытаемся удлинить seg1 на 45 минут (до 10:45) -> seg2 сдвинется на 10:45-11:45, что налезет на Jira (11:30)
      expect(
        () => appState.resizeSegmentRight(seg1, 3600 + 45 * 60),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Недостаточно свободного времени перед записью Jira PROJ-1'),
        )),
      );
    });
  });
}

