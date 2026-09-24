import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';

void main() {
  group('Ripple Push & Gap Actions (Ticket 01)', () {
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
      for (int i = 1; i <= 4; i++) {
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

    test(
      'snapGap сдвигает правую цепочку влево встык к предыдущей задаче, сохраняя длительность задач',
      () {
        seedIssuesAndLogs();
        final appState = createTestAppState();

        // Задача 1: 09:00 - 10:00 (1 ч)
        // Зазор: 10:00 - 11:00 (1 ч)
        // Задача 2: 11:00 - 12:00 (1 ч)
        // Зазор: 12:00 - 12:30 (30 мин)
        // Задача 3: 12:30 - 13:30 (1 ч)
        final dStart = DateTime.utc(2026, 9, 14, 9, 0);
        final dEnd = DateTime.utc(2026, 9, 14, 18, 0);

        final draft = DayDraft(
          id: 'draft-1',
          scope: testScope,
          date: '2026-09-14',
          startUtc: dStart,
          endUtc: dEnd,
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
          startUtc: DateTime.utc(2026, 9, 14, 11, 0),
          durationSeconds: 3600,
          description: 'Задача 2',
          sendState: SendState.pending,
        );
        final seg3 = Segment(
          id: 'seg-3',
          draftId: 'draft-1',
          sourceLogId: 'log-3',
          issueId: '3',
          startUtc: DateTime.utc(2026, 9, 14, 12, 30),
          durationSeconds: 3600,
          description: 'Задача 3',
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
            const DraftLog(
              draftId: 'draft-1',
              sourceLogId: 'log-3',
              sourceDurationSeconds: 3600,
              descriptionSnapshot: '',
              durationLocked: false,
            ),
          ],
          segments: [seg1, seg2, seg3],
          breaks: [],
        );

        appState.setSelectedDate(DateTime(2026, 9, 14));

        // Находим зазор 10:00 - 11:00
        final gap = appState.currentBreaks.firstWhere(
          (b) => b.startUtc == DateTime.utc(2026, 9, 14, 10, 0),
        );

        // Схлопываем зазор
        appState.snapGap(gap);

        // Задача 1 осталась 09:00 - 10:00 (длительность 3600)
        final res1 = appState.currentSegments.firstWhere(
          (s) => s.id == 'seg-1',
        );
        expect(res1.startUtc, equals(DateTime.utc(2026, 9, 14, 9, 0)));
        expect(res1.durationSeconds, equals(3600));

        // Задача 2 придвинулась вплотную к Задаче 1: стала 10:00 - 11:00 (длительность 3600 сохранена!)
        final res2 = appState.currentSegments.firstWhere(
          (s) => s.id == 'seg-2',
        );
        expect(res2.startUtc, equals(DateTime.utc(2026, 9, 14, 10, 0)));
        expect(res2.durationSeconds, equals(3600));

        // Задача 3 тоже сдвинулась влево на 1 час (сохраняя 30-мин паузу после Задачи 2):
        // Стала 11:30 - 12:30 (длительность 3600 сохранена!)
        final res3 = appState.currentSegments.firstWhere(
          (s) => s.id == 'seg-3',
        );
        expect(res3.startUtc, equals(DateTime.utc(2026, 9, 14, 11, 30)));
        expect(res3.durationSeconds, equals(3600));
      },
    );

    test(
      'fillGapWithLeftSegment расширяет левую задачу, не сдвигая правые задачи',
      () {
        seedIssuesAndLogs();
        final appState = createTestAppState();

        // Задача 1: 09:00 - 10:00 (1 ч)
        // Зазор: 10:00 - 11:00 (1 ч)
        // Задача 2: 11:00 - 12:00 (1 ч)
        final dStart = DateTime.utc(2026, 9, 14, 9, 0);
        final dEnd = DateTime.utc(2026, 9, 14, 18, 0);

        final draft = DayDraft(
          id: 'draft-1',
          scope: testScope,
          date: '2026-09-14',
          startUtc: dStart,
          endUtc: dEnd,
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
          startUtc: DateTime.utc(2026, 9, 14, 11, 0),
          durationSeconds: 3600,
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

        final gap = appState.currentBreaks.firstWhere(
          (b) => b.startUtc == DateTime.utc(2026, 9, 14, 10, 0),
        );

        appState.fillGapWithLeftSegment(gap);

        // Задача 1 расширилась до 11:00 (2 часа = 7200 сек)
        final res1 = appState.currentSegments.firstWhere(
          (s) => s.id == 'seg-1',
        );
        expect(res1.startUtc, equals(DateTime.utc(2026, 9, 14, 9, 0)));
        expect(res1.durationSeconds, equals(7200));

        // Задача 2 осталась на месте 11:00 - 12:00
        final res2 = appState.currentSegments.firstWhere(
          (s) => s.id == 'seg-2',
        );
        expect(res2.startUtc, equals(DateTime.utc(2026, 9, 14, 11, 0)));
        expect(res2.durationSeconds, equals(3600));
      },
    );

    test(
      'setGapDuration выталкивает последующие задачи волной при увеличении паузы',
      () {
        seedIssuesAndLogs();
        final appState = createTestAppState();

        // Задача 1: 09:00 - 10:00 (1 ч)
        // Зазор: 10:00 - 10:15 (15 мин)
        // Задача 2: 10:15 - 11:15 (1 ч)
        final dStart = DateTime.utc(2026, 9, 14, 9, 0);
        final dEnd = DateTime.utc(2026, 9, 14, 18, 0);

        final draft = DayDraft(
          id: 'draft-1',
          scope: testScope,
          date: '2026-09-14',
          startUtc: dStart,
          endUtc: dEnd,
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
          startUtc: DateTime.utc(2026, 9, 14, 10, 15),
          durationSeconds: 3600,
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

        final gap = appState.currentBreaks.firstWhere(
          (b) => b.startUtc == DateTime.utc(2026, 9, 14, 10, 0),
        );

        // Увеличиваем перерыв до 1 часа (3600 сек, было 15 мин = 900 сек)
        appState.setGapDuration(gap: gap, newDurationSeconds: 3600);

        // Задача 1 осталась 09:00 - 10:00
        final res1 = appState.currentSegments.firstWhere(
          (s) => s.id == 'seg-1',
        );
        expect(res1.durationSeconds, equals(3600));

        // Задача 2 вытолкнута на 11:00 (10:00 + 1 час перерыва), длительность 3600 сохранена!
        final res2 = appState.currentSegments.firstWhere(
          (s) => s.id == 'seg-2',
        );
        expect(res2.startUtc, equals(DateTime.utc(2026, 9, 14, 11, 0)));
        expect(res2.durationSeconds, equals(3600));
        expect(res2.endUtc, equals(DateTime.utc(2026, 9, 14, 12, 0)));
      },
    );

    test(
      'updateSegment сдвигает хвост при правке времени без изменения длительности следующих задач',
      () {
        seedIssuesAndLogs();
        final appState = createTestAppState();

        // Задача 1: 09:00 - 10:00 (1 ч)
        // Пауза: 10:00 - 10:30 (30 мин)
        // Задача 2: 10:30 - 11:30 (1 ч)
        final dStart = DateTime.utc(2026, 9, 14, 9, 0);
        final dEnd = DateTime.utc(2026, 9, 14, 18, 0);

        final draft = DayDraft(
          id: 'draft-1',
          scope: testScope,
          date: '2026-09-14',
          startUtc: dStart,
          endUtc: dEnd,
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
          breaks: [
            Break(
              id: 'break-1',
              draftId: 'draft-1',
              startUtc: DateTime.utc(2026, 9, 14, 10),
              durationSeconds: 1800,
              kind: BreakKind.short,
            ),
          ],
        );

        appState.setSelectedDate(DateTime(2026, 9, 14));

        // Даже если до следующей задачи был промежуток, он сохраняет размер.
        appState.updateSegment(
          segmentId: 'seg-1',
          startUtc: DateTime.utc(2026, 9, 14, 9, 0),
          durationSeconds: 4500, // 1 ч 15 мин
          description: 'Задача 1 обновлена',
        );

        var checkSeg2 = appState.currentSegments.firstWhere(
          (s) => s.id == 'seg-2',
        );
        expect(checkSeg2.startUtc, equals(DateTime.utc(2026, 9, 14, 10, 45)));
        expect(checkSeg2.durationSeconds, equals(3600));
        expect(
          store.getBreaks(draftId: 'draft-1').single.startUtc,
          DateTime.utc(2026, 9, 14, 10, 15),
        );

        // Второе изменение отсчитывается от уже сдвинутого положения хвоста.
        appState.updateSegment(
          segmentId: 'seg-1',
          startUtc: DateTime.utc(2026, 9, 14, 9, 0),
          durationSeconds: 7200, // 2 часа
          description: 'Задача 1 2 часа',
        );

        checkSeg2 = appState.currentSegments.firstWhere((s) => s.id == 'seg-2');
        expect(checkSeg2.startUtc, equals(DateTime.utc(2026, 9, 14, 11, 30)));
        expect(checkSeg2.durationSeconds, equals(3600));
        expect(checkSeg2.endUtc, equals(DateTime.utc(2026, 9, 14, 12, 30)));

        // Перенос начала при той же длительности тоже двигает хвост.
        appState.updateSegment(
          segmentId: 'seg-1',
          startUtc: DateTime.utc(2026, 9, 14, 9, 20),
          durationSeconds: 7200,
          description: 'Задача 1 2 часа',
        );
        checkSeg2 = appState.currentSegments.firstWhere((s) => s.id == 'seg-2');
        expect(checkSeg2.startUtc, equals(DateTime.utc(2026, 9, 14, 11, 50)));
        expect(checkSeg2.durationSeconds, equals(3600));

        appState.updateSegment(
          segmentId: 'seg-1',
          startUtc: DateTime.utc(2026, 9, 14, 9, 20),
          durationSeconds: 3600,
          description: 'Задача 1 снова час',
        );
        checkSeg2 = appState.currentSegments.firstWhere((s) => s.id == 'seg-2');
        expect(checkSeg2.startUtc, DateTime.utc(2026, 9, 14, 10, 50));
        expect(checkSeg2.durationSeconds, 3600);

        store.updateSegment(checkSeg2.copyWith(sendState: SendState.sent));
        appState.loadDraftForSelectedDate();
        expect(
          () => appState.updateSegment(
            segmentId: 'seg-1',
            startUtc: DateTime.utc(2026, 9, 14, 9, 20),
            durationSeconds: 4500,
            description: 'Нельзя сдвинуть отправленную запись',
          ),
          throwsArgumentError,
        );
        expect(
          store.getSegments(draftId: 'draft-1').first.durationSeconds,
          3600,
        );
      },
    );
  });
}
