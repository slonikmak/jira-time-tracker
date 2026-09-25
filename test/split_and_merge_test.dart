import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';

void main() {
  group('AppState Split, Merge, Fixed Anchors and Reorder', () {
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
      currentTime = DateTime.utc(2026, 9, 17, 9, 0, 0);

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

    test(
      'splitLog разделяет свободный лог на две части с заданными описаниями',
      () async {
        final appState = createAppState();
        final log = await appState.addManualLog(
          issueId: '10001',
          durationSeconds: 7200, // 2 часа
          description: 'Общая работа',
        );

        final (part1, part2) = await appState.splitLog(
          logId: log.id,
          part1DurationSeconds: 4500, // 1h 15m
          part1Description: 'Часть 1: Анализ',
          part2Description: 'Часть 2: Реализация',
        );

        expect(part1.accumulatedSeconds, equals(4500));
        expect(part1.description, equals('Часть 1: Анализ'));
        expect(part2.accumulatedSeconds, equals(2700)); // 45m
        expect(part2.description, equals('Часть 2: Реализация'));

        final allLogs = appState.logs;
        expect(allLogs.length, equals(2));
        expect(allLogs.any((l) => l.id == part1.id), isTrue);
        expect(allLogs.any((l) => l.id == part2.id), isTrue);
      },
    );

    test('splitLog выбрасывает ошибку при некорректной длительности', () async {
      final appState = createAppState();
      final log = await appState.addManualLog(
        issueId: '10001',
        durationSeconds: 3600,
      );

      expect(
        () => appState.splitLog(logId: log.id, part1DurationSeconds: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => appState.splitLog(logId: log.id, part1DurationSeconds: 3600),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('mergeLogs объединяет два лога одной задачи', () async {
      final appState = createAppState();
      final log1 = await appState.addManualLog(
        issueId: '10001',
        durationSeconds: 1800,
        description: 'Утренний блок',
      );
      final log2 = await appState.addManualLog(
        issueId: '10001',
        durationSeconds: 3600,
        description: 'Дневной блок',
      );

      final merged = await appState.mergeLogs(logIds: [log1.id, log2.id]);

      expect(merged.accumulatedSeconds, equals(5400));
      expect(merged.issueId, equals('10001'));
      expect(merged.description, contains('Утренний блок'));
      expect(merged.description, contains('Дневной блок'));

      final allLogs = appState.logs;
      expect(allLogs.length, equals(1));
      expect(allLogs.first.id, equals(merged.id));
    });

    test(
      'mergeLogs объединяет логи разных задач в выбранную целевую задачу',
      () async {
        final appState = createAppState();
        final log1 = await appState.addManualLog(
          issueId: '10001',
          durationSeconds: 1800,
          description: 'Задача 1',
        );
        final log2 = await appState.addManualLog(
          issueId: '10002',
          durationSeconds: 1800,
          description: 'Задача 2',
        );

        final merged = await appState.mergeLogs(
          logIds: [log1.id, log2.id],
          targetIssueId: '10002',
          description: 'Объединенный итог',
        );

        expect(merged.accumulatedSeconds, equals(3600));
        expect(merged.issueId, equals('10002'));
        expect(merged.titleSnapshot, equals('Вторая задача'));
        expect(merged.description, equals('Объединенный итог'));
      },
    );

    test(
      'toggleSegmentFixed переключает флаг isFixed у сегмента дня',
      () async {
        final appState = createAppState();
        final log = await appState.addManualLog(
          issueId: '10001',
          durationSeconds: 3600,
        );

        final draft = DayDraft(
          id: 'draft-1',
          scope: 'default',
          date: appState.selectedDateString,
          startUtc: currentTime,
          endUtc: currentTime.add(const Duration(hours: 4)),
          seed: 1,
          settingsSnapshot: '{}',
          status: DraftStatus.draft,
        );
        final seg = Segment(
          id: 'seg-1',
          draftId: 'draft-1',
          sourceLogId: log.id,
          issueId: '10001',
          startUtc: currentTime,
          durationSeconds: 3600,
          isFixed: false,
        );
        store.saveDayDraft(
          draft: draft,
          draftLogs: [],
          segments: [seg],
          breaks: [],
        );

        appState.loadDraftForSelectedDate();
        expect(appState.currentSegments.first.isFixed, isFalse);

        appState.toggleSegmentFixed('seg-1');
        expect(appState.currentSegments.first.isFixed, isTrue);

        appState.toggleSegmentFixed('seg-1');
        expect(appState.currentSegments.first.isFixed, isFalse);
      },
    );

    test(
      'splitSegment разделяет сегмент дня на два последовательных сегмента',
      () async {
        final appState = createAppState();
        final log = await appState.addManualLog(
          issueId: '10001',
          durationSeconds: 3600,
        );

        final draft = DayDraft(
          id: 'draft-1',
          scope: 'default',
          date: appState.selectedDateString,
          startUtc: currentTime,
          endUtc: currentTime.add(const Duration(hours: 4)),
          seed: 1,
          settingsSnapshot: '{}',
          status: DraftStatus.draft,
        );
        final seg = Segment(
          id: 'seg-1',
          draftId: 'draft-1',
          sourceLogId: log.id,
          issueId: '10001',
          startUtc: currentTime,
          durationSeconds: 3600,
          description: 'Полная задача',
        );
        store.saveDayDraft(
          draft: draft,
          draftLogs: [],
          segments: [seg],
          breaks: [],
        );

        appState.loadDraftForSelectedDate();

        appState.splitSegment(
          segmentId: 'seg-1',
          splitOffsetSeconds: 1800,
          part1Description: 'Часть A',
          part2Description: 'Часть B',
        );

        expect(appState.currentSegments.length, equals(2));
        final s1 = appState.currentSegments[0];
        final s2 = appState.currentSegments[1];

        expect(s1.durationSeconds, equals(1800));
        expect(s1.description, equals('Часть A'));
        expect(s1.startUtc, equals(currentTime));

        expect(s2.durationSeconds, equals(1800));
        expect(s2.description, equals('Часть B'));
        expect(
          s2.startUtc,
          equals(currentTime.add(const Duration(seconds: 1800))),
        );
      },
    );

    test(
      'пересборка после разделения сохраняет обе части и их суммарную длительность',
      () async {
        final appState = createAppState();
        final log = await appState.addManualLog(
          issueId: '10001',
          durationSeconds: 3600,
        );
        store.saveDayDraft(
          draft: DayDraft(
            id: 'draft-1',
            scope: 'default',
            date: appState.selectedDateString,
            startUtc: currentTime,
            endUtc: currentTime.add(const Duration(hours: 4)),
            seed: 1,
            settingsSnapshot: const DaySettings().toJson(),
          ),
          draftLogs: [
            DraftLog(
              draftId: 'draft-1',
              sourceLogId: log.id,
              sourceDurationSeconds: 3600,
              descriptionSnapshot: 'Полная задача',
            ),
          ],
          segments: [
            Segment(
              id: 'seg-1',
              draftId: 'draft-1',
              sourceLogId: log.id,
              issueId: '10001',
              startUtc: currentTime,
              durationSeconds: 3600,
              description: 'Полная задача',
            ),
          ],
          breaks: [],
        );

        appState.loadDraftForSelectedDate();
        appState.splitSegment(
          segmentId: 'seg-1',
          splitOffsetSeconds: 900,
          part1Description: 'Часть A',
          part2Description: 'Часть B',
        );
        appState.updateDaySettings(
          const DaySettings(shortBreakCountMin: 0, shortBreakCountMax: 0),
        );
        await appState.rebuildCurrentDay(customSeed: 2);

        expect(appState.currentSegments.length, 2);
        expect(
          appState.currentSegments.map((s) => s.durationSeconds).toList(),
          [900, 2700],
        );
        expect(appState.currentSegments.map((s) => s.description).toList(), [
          'Часть A',
          'Часть B',
        ]);
        expect(appState.currentSegments.map((s) => s.sourceLogId).toSet(), {
          log.id,
        });

        final partB = appState.currentSegments.last;
        appState.updateSegment(
          segmentId: partB.id,
          startUtc: partB.startUtc,
          durationSeconds: 3600,
          description: partB.description,
        );
        await appState.rebuildCurrentDay(customSeed: 3);
        expect(
          appState.currentSegments
              .where((s) => s.description == 'Часть B')
              .fold<int>(0, (sum, s) => sum + s.durationSeconds),
          3600,
        );
        expect(appState.currentDraftLogs.single.sourceDurationSeconds, 3600);
        expect(appState.currentDraft!.seed, 3);
      },
    );

    test('mergeSegments объединяет два сегмента дня в один', () async {
      final appState = createAppState();
      final log = await appState.addManualLog(
        issueId: '10001',
        durationSeconds: 3600,
      );

      final draft = DayDraft(
        id: 'draft-1',
        scope: 'default',
        date: appState.selectedDateString,
        startUtc: currentTime,
        endUtc: currentTime.add(const Duration(hours: 4)),
        seed: 1,
        settingsSnapshot: '{}',
        status: DraftStatus.draft,
      );
      final seg1 = Segment(
        id: 'seg-1',
        draftId: 'draft-1',
        sourceLogId: log.id,
        issueId: '10001',
        startUtc: currentTime,
        durationSeconds: 1800,
        description: 'Сегмент 1',
      );
      final seg2 = Segment(
        id: 'seg-2',
        draftId: 'draft-1',
        sourceLogId: log.id,
        issueId: '10001',
        startUtc: currentTime.add(const Duration(seconds: 1800)),
        durationSeconds: 1800,
        description: 'Сегмент 2',
      );
      store.saveDayDraft(
        draft: draft,
        draftLogs: [],
        segments: [seg1, seg2],
        breaks: [],
      );

      appState.loadDraftForSelectedDate();
      expect(appState.currentSegments.length, equals(2));

      appState.mergeSegments(segmentId1: 'seg-1', segmentId2: 'seg-2');

      expect(appState.currentSegments.length, equals(1));
      final merged = appState.currentSegments.first;
      expect(merged.durationSeconds, equals(3600));
      expect(merged.description, contains('Сегмент 1'));
      expect(merged.description, contains('Сегмент 2'));
    });

    test(
      'mergeSegments rejects different source logs without changing the draft',
      () async {
        final appState = createAppState();
        final log1 = await appState.addManualLog(
          issueId: '10001',
          durationSeconds: 1800,
        );
        final log2 = await appState.addManualLog(
          issueId: '10001',
          durationSeconds: 1800,
        );
        final draft = DayDraft(
          id: 'draft-merge-sources',
          scope: 'default',
          date: appState.selectedDateString,
          startUtc: currentTime,
          endUtc: currentTime.add(const Duration(hours: 1)),
          seed: 1,
          settingsSnapshot: '{}',
        );
        store.saveDayDraft(
          draft: draft,
          draftLogs: [],
          segments: [
            Segment(
              id: 'source-seg-1',
              draftId: draft.id,
              sourceLogId: log1.id,
              issueId: '10001',
              startUtc: currentTime,
              durationSeconds: 1800,
            ),
            Segment(
              id: 'source-seg-2',
              draftId: draft.id,
              sourceLogId: log2.id,
              issueId: '10001',
              startUtc: currentTime.add(const Duration(minutes: 30)),
              durationSeconds: 1800,
            ),
          ],
          breaks: [],
        );
        appState.loadDraftForSelectedDate();

        expect(
          () => appState.mergeSegments(
            segmentId1: 'source-seg-1',
            segmentId2: 'source-seg-2',
          ),
          throwsArgumentError,
        );
        expect(appState.currentSegments, hasLength(2));
        expect(store.getSegments(draftId: draft.id), hasLength(2));
      },
    );

    test(
      'reorderSegments, moveSegmentUp и moveSegmentDown меняют порядок сегментов',
      () async {
        final appState = createAppState();
        final log1 = await appState.addManualLog(
          issueId: '10001',
          durationSeconds: 3600,
        );
        final log2 = await appState.addManualLog(
          issueId: '10002',
          durationSeconds: 3600,
        );
        final log3 = await appState.addManualLog(
          issueId: '10001',
          durationSeconds: 3600,
        );

        final draft = DayDraft(
          id: 'draft-1',
          scope: 'default',
          date: appState.selectedDateString,
          startUtc: currentTime,
          endUtc: currentTime.add(const Duration(hours: 6)),
          seed: 1,
          settingsSnapshot: '{}',
          status: DraftStatus.draft,
        );
        final segA = Segment(
          id: 'seg-a',
          draftId: 'draft-1',
          sourceLogId: log1.id,
          issueId: '10001',
          startUtc: currentTime,
          durationSeconds: 3600,
        );
        final segB = Segment(
          id: 'seg-b',
          draftId: 'draft-1',
          sourceLogId: log2.id,
          issueId: '10002',
          startUtc: currentTime.add(const Duration(hours: 1)),
          durationSeconds: 3600,
        );
        final segC = Segment(
          id: 'seg-c',
          draftId: 'draft-1',
          sourceLogId: log3.id,
          issueId: '10001',
          startUtc: currentTime.add(const Duration(hours: 2)),
          durationSeconds: 3600,
        );
        store.saveDayDraft(
          draft: draft,
          draftLogs: [],
          segments: [segA, segB, segC],
          breaks: [],
        );

        appState.loadDraftForSelectedDate();
        expect(appState.currentSegments.map((s) => s.id).toList(), [
          'seg-a',
          'seg-b',
          'seg-c',
        ]);

        // Перемещаем seg-c на позицию 0 (вверх)
        appState.reorderSegments(2, 0);
        expect(appState.currentSegments.map((s) => s.id).toList(), [
          'seg-c',
          'seg-a',
          'seg-b',
        ]);

        // moveSegmentDown для seg-c
        appState.moveSegmentDown('seg-c');
        expect(appState.currentSegments.map((s) => s.id).toList(), [
          'seg-a',
          'seg-c',
          'seg-b',
        ]);

        // moveSegmentUp для seg-b
        appState.moveSegmentUp('seg-b');
        expect(appState.currentSegments.map((s) => s.id).toList(), [
          'seg-a',
          'seg-b',
          'seg-c',
        ]);

        appState.reorderSegments(2, 0);
        appState.updateSegment(
          segmentId: 'seg-c',
          startUtc: segC.startUtc,
          durationSeconds: segC.durationSeconds,
          description: 'Новая подпись',
        );
        expect(appState.currentSegments.map((s) => s.id).toList(), [
          'seg-c',
          'seg-a',
          'seg-b',
        ]);
        await appState.rebuildCurrentDay(customSeed: 7);
        final rebuiltSources = appState.currentSegments
            .map((s) => s.sourceLogId)
            .toList();
        expect(
          [
            for (var i = 0; i < rebuiltSources.length; i++)
              if (i == 0 || rebuiltSources[i] != rebuiltSources[i - 1])
                rebuiltSources[i],
          ],
          [log3.id, log1.id, log2.id],
        );
        expect(appState.currentSegments.first.description, 'Новая подпись');
      },
    );
  });
}
