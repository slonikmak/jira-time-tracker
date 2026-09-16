import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';

void main() {
  group('Timeline Gap Adjustment & Editing (Issue 01)', () {
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
      final issue1 = Issue(
        scope: testScope,
        issueId: '101',
        key: 'PROJ-1',
        summary: 'Задача 1',
        lastUsedAtUtc: now,
      );
      final log1 = LocalLog(
        id: 'log-1',
        scope: testScope,
        issueId: '101',
        titleSnapshot: 'PROJ-1',
        accumulatedSeconds: 3600,
        createdAtUtc: now,
      );
      store.saveLogsAndIssue(logs: [log1], issue: issue1);

      final issue2 = Issue(
        scope: testScope,
        issueId: '102',
        key: 'PROJ-2',
        summary: 'Задача 2',
        lastUsedAtUtc: now,
      );
      final log2 = LocalLog(
        id: 'log-2',
        scope: testScope,
        issueId: '102',
        titleSnapshot: 'PROJ-2',
        accumulatedSeconds: 3600,
        createdAtUtc: now,
      );
      store.saveLogsAndIssue(logs: [log2], issue: issue2);
    }

    test('findGapNeighbors корректно определяет соседей для зазоров', () {
      seedIssuesAndLogs();
      final appState = createTestAppState();

      final dStart = DateTime.utc(2026, 9, 14, 8, 0);
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
        issueId: '101',
        startUtc: DateTime.utc(2026, 9, 14, 9, 0),
        durationSeconds: 3600, // 09:00 - 10:00
        description: 'Задача 1',
        sendState: SendState.pending,
      );

      final seg2 = Segment(
        id: 'seg-2',
        draftId: 'draft-1',
        sourceLogId: 'log-2',
        issueId: '102',
        startUtc: DateTime.utc(2026, 9, 14, 12, 0),
        durationSeconds: 7200, // 12:00 - 14:00
        description: 'Задача 2',
        sendState: SendState.pending,
      );

      final draftLogs = [
        const DraftLog(
          draftId: 'draft-1',
          sourceLogId: 'log-1',
          sourceDurationSeconds: 3600,
          descriptionSnapshot: 'Задача 1',
          durationLocked: false,
        ),
        const DraftLog(
          draftId: 'draft-1',
          sourceLogId: 'log-2',
          sourceDurationSeconds: 7200,
          descriptionSnapshot: 'Задача 2',
          durationLocked: false,
        ),
      ];

      store.saveDayDraft(
        draft: draft,
        draftLogs: draftLogs,
        segments: [seg1, seg2],
        breaks: [],
      );

      appState.setSelectedDate(DateTime(2026, 9, 14));

      // 1. Зазор в начале дня: 08:00 - 09:00
      final gapStartOfDay = Break(
        id: 'gap-start',
        draftId: 'draft-1',
        startUtc: DateTime.utc(2026, 9, 14, 8, 0),
        durationSeconds: 3600,
        kind: BreakKind.short,
      );
      final n1 = appState.findGapNeighbors(gapStartOfDay);
      expect(n1.isStartOfDay, isTrue);
      expect(n1.leftSegment, isNull);
      expect(n1.rightSegment?.id, equals('seg-1'));

      // 2. Зазор между seg1 и seg2: 10:00 - 12:00
      final gapBetween = Break(
        id: 'gap-mid',
        draftId: 'draft-1',
        startUtc: DateTime.utc(2026, 9, 14, 10, 0),
        durationSeconds: 7200,
        kind: BreakKind.short,
      );
      final n2 = appState.findGapNeighbors(gapBetween);
      expect(n2.isStartOfDay, isFalse);
      expect(n2.isEndOfDay, isFalse);
      expect(n2.leftSegment?.id, equals('seg-1'));
      expect(n2.rightSegment?.id, equals('seg-2'));

      // 3. Зазор в конце дня: 14:00 - 18:00
      final gapEndOfDay = Break(
        id: 'gap-end',
        draftId: 'draft-1',
        startUtc: DateTime.utc(2026, 9, 14, 14, 0),
        durationSeconds: 14400,
        kind: BreakKind.short,
      );
      final n3 = appState.findGapNeighbors(gapEndOfDay);
      expect(n3.isEndOfDay, isTrue);
      expect(n3.leftSegment?.id, equals('seg-2'));
      expect(n3.rightSegment, isNull);
    });

    test('Валидация предотвращает схлопывание сегментов меньше 1 минуты и нарушение записей Jira', () {
      seedIssuesAndLogs();
      final appState = createTestAppState();

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
        issueId: '101',
        startUtc: DateTime.utc(2026, 9, 14, 9, 0),
        durationSeconds: 3600, // 09:00 - 10:00
        description: 'Задача 1',
        sendState: SendState.pending,
      );

      final seg2 = Segment(
        id: 'seg-2',
        draftId: 'draft-1',
        sourceLogId: 'log-2',
        issueId: '102',
        startUtc: DateTime.utc(2026, 9, 14, 11, 0),
        durationSeconds: 3600, // 11:00 - 12:00
        description: 'Задача 2',
        sendState: SendState.pending,
      );

      final draftLogs = [
        const DraftLog(
          draftId: 'draft-1',
          sourceLogId: 'log-1',
          sourceDurationSeconds: 3600,
          descriptionSnapshot: 'Задача 1',
          durationLocked: false,
        ),
        const DraftLog(
          draftId: 'draft-1',
          sourceLogId: 'log-2',
          sourceDurationSeconds: 3600,
          descriptionSnapshot: 'Задача 2',
          durationLocked: false,
        ),
      ];

      store.saveDayDraft(
        draft: draft,
        draftLogs: draftLogs,
        segments: [seg1, seg2],
        breaks: [],
      );

      appState.setSelectedDate(DateTime(2026, 9, 14));

      final gap = Break(
        id: 'gap-1',
        draftId: 'draft-1',
        startUtc: DateTime.utc(2026, 9, 14, 10, 0),
        durationSeconds: 3600, // 10:00 - 11:00
        kind: BreakKind.short,
      );

      // Валидная настройка: 09:45 - 11:15 (seg1 станет 45 мин, seg2 станет 45 мин)
      final errOk = appState.validateGapAdjustment(
        gap: gap,
        newStartUtc: DateTime.utc(2026, 9, 14, 9, 45),
        newEndUtc: DateTime.utc(2026, 9, 14, 11, 15),
      );
      expect(errOk, isNull);

      // Невалидно: сжатие левого сегмента до 0 (newStart = 09:00, seg1 start = 09:00)
      final errLeft = appState.validateGapAdjustment(
        gap: gap,
        newStartUtc: DateTime.utc(2026, 9, 14, 9, 0),
        newEndUtc: DateTime.utc(2026, 9, 14, 10, 30),
      );
      expect(errLeft, contains('не может быть меньше 1 минуты'));

      // Невалидно: сжатие правого сегмента до 0 (newEnd = 12:00, seg2 end = 12:00)
      final errRight = appState.validateGapAdjustment(
        gap: gap,
        newStartUtc: DateTime.utc(2026, 9, 14, 10, 0),
        newEndUtc: DateTime.utc(2026, 9, 14, 12, 0),
      );
      expect(errRight, contains('не может быть меньше 1 минуты'));

      // Невалидно: endUtc <= startUtc
      final errInverted = appState.validateGapAdjustment(
        gap: gap,
        newStartUtc: DateTime.utc(2026, 9, 14, 10, 30),
        newEndUtc: DateTime.utc(2026, 9, 14, 10, 15),
      );
      expect(errInverted, contains('позже времени начала'));
    });

    test('updateBreakGap сдвигает правую границу левой задачи и левую границу правой задачи', () {
      seedIssuesAndLogs();
      final appState = createTestAppState();

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
        issueId: '101',
        startUtc: DateTime.utc(2026, 9, 14, 9, 0),
        durationSeconds: 3600, // 09:00 - 10:00 (1 час)
        description: 'Задача 1',
        sendState: SendState.pending,
      );

      final seg2 = Segment(
        id: 'seg-2',
        draftId: 'draft-1',
        sourceLogId: 'log-2',
        issueId: '102',
        startUtc: DateTime.utc(2026, 9, 14, 11, 0),
        durationSeconds: 3600, // 11:00 - 12:00 (1 час)
        description: 'Задача 2',
        sendState: SendState.pending,
      );

      final draftLogs = [
        const DraftLog(
          draftId: 'draft-1',
          sourceLogId: 'log-1',
          sourceDurationSeconds: 3600,
          descriptionSnapshot: 'Задача 1',
          durationLocked: false,
        ),
        const DraftLog(
          draftId: 'draft-1',
          sourceLogId: 'log-2',
          sourceDurationSeconds: 3600,
          descriptionSnapshot: 'Задача 2',
          durationLocked: false,
        ),
      ];

      store.saveDayDraft(
        draft: draft,
        draftLogs: draftLogs,
        segments: [seg1, seg2],
        breaks: [],
      );

      appState.setSelectedDate(DateTime(2026, 9, 14));

      final gap = Break(
        id: 'gap-1',
        draftId: 'draft-1',
        startUtc: DateTime.utc(2026, 9, 14, 10, 0),
        durationSeconds: 3600, // 10:00 - 11:00
        kind: BreakKind.short,
      );

      // Сдвигаем промежуток: начало 10:30 (seg1 расширяется до 1.5 ч), конец 11:15 (seg2 сжимается до 45 мин), тип обед
      appState.updateBreakGap(
        gap: gap,
        newStartUtc: DateTime.utc(2026, 9, 14, 10, 30),
        newEndUtc: DateTime.utc(2026, 9, 14, 11, 15),
        newKind: BreakKind.lunch,
      );

      // Проверяем обновленный seg1
      final updatedSeg1 = appState.currentSegments.firstWhere((s) => s.id == 'seg-1');
      expect(updatedSeg1.startUtc, equals(DateTime.utc(2026, 9, 14, 9, 0)));
      expect(updatedSeg1.durationSeconds, equals(5400)); // 1.5 часа (до 10:30)
      expect(updatedSeg1.endUtc, equals(DateTime.utc(2026, 9, 14, 10, 30)));

      // Проверяем обновленный seg2
      final updatedSeg2 = appState.currentSegments.firstWhere((s) => s.id == 'seg-2');
      expect(updatedSeg2.startUtc, equals(DateTime.utc(2026, 9, 14, 11, 15)));
      expect(updatedSeg2.durationSeconds, equals(2700)); // 45 минут (до 12:00)
      expect(updatedSeg2.endUtc, equals(DateTime.utc(2026, 9, 14, 12, 0)));

      // Проверяем вычисленные зазоры: появился перерыв 10:30 - 11:15 (45 мин)
      final currentBreaks = appState.currentBreaks;
      final midBreak = currentBreaks.firstWhere(
        (b) => b.startUtc == DateTime.utc(2026, 9, 14, 10, 30),
      );
      expect(midBreak.durationSeconds, equals(2700)); // 45 минут
      expect(midBreak.kind, equals(BreakKind.short));
    });

    test('deleteBreakGap смыкает смежные задачи', () {
      seedIssuesAndLogs();
      final appState = createTestAppState();

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
        issueId: '101',
        startUtc: DateTime.utc(2026, 9, 14, 9, 0),
        durationSeconds: 3600, // 09:00 - 10:00
        description: 'Задача 1',
        sendState: SendState.pending,
      );

      final seg2 = Segment(
        id: 'seg-2',
        draftId: 'draft-1',
        sourceLogId: 'log-2',
        issueId: '102',
        startUtc: DateTime.utc(2026, 9, 14, 11, 0),
        durationSeconds: 3600, // 11:00 - 12:00
        description: 'Задача 2',
        sendState: SendState.pending,
      );

      final draftLogs = [
        const DraftLog(
          draftId: 'draft-1',
          sourceLogId: 'log-1',
          sourceDurationSeconds: 3600,
          descriptionSnapshot: 'Задача 1',
          durationLocked: false,
        ),
        const DraftLog(
          draftId: 'draft-1',
          sourceLogId: 'log-2',
          sourceDurationSeconds: 3600,
          descriptionSnapshot: 'Задача 2',
          durationLocked: false,
        ),
      ];

      store.saveDayDraft(
        draft: draft,
        draftLogs: draftLogs,
        segments: [seg1, seg2],
        breaks: [],
      );

      appState.setSelectedDate(DateTime(2026, 9, 14));

      final gap = Break(
        id: 'gap-1',
        draftId: 'draft-1',
        startUtc: DateTime.utc(2026, 9, 14, 10, 0),
        durationSeconds: 3600, // 10:00 - 11:00
        kind: BreakKind.short,
      );

      appState.deleteBreakGap(gap);

      // seg1 расширился до 11:00 (длительность стала 2 часа = 7200 сек)
      final updatedSeg1 = appState.currentSegments.firstWhere((s) => s.id == 'seg-1');
      expect(updatedSeg1.durationSeconds, equals(7200));
      expect(updatedSeg1.endUtc, equals(DateTime.utc(2026, 9, 14, 11, 0)));

      // Теперь seg1 и seg2 идут встык (10:00 - 11:00 зазора больше нет)
      final gapsBetween = appState.currentBreaks.where(
        (b) => b.startUtc.isAfter(DateTime.utc(2026, 9, 14, 9, 0)) &&
               b.startUtc.isBefore(DateTime.utc(2026, 9, 14, 11, 0)),
      );
      expect(gapsBetween, isEmpty);
    });
  });
}
