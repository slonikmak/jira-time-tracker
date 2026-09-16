import 'package:flutter_test/flutter_test.dart';
import 'package:jira_time_tracker/day_builder.dart';
import 'package:jira_time_tracker/models.dart';

void main() {
  group('DayBuilder.computeTimelineGaps (Ticket 01)', () {
    DateTime localToUtc(int hour, [int minute = 0]) {
      return DateTime(2026, 9, 16, hour, minute).toUtc();
    }

    test('Вычисляет естественный зазор между задачами (например 10:37 .. 14:32)', () {
      // Сегмент 1: 09:00 .. 10:37 (длительность 1 ч 37 мин = 5820 сек)
      final seg1Start = localToUtc(9, 0);
      final seg1 = Segment(
        id: 'seg-1',
        draftId: 'draft-1',
        sourceLogId: 'log-1',
        issueId: '101',
        startUtc: seg1Start,
        durationSeconds: 5820,
        description: 'Первая задача',
      );

      // Сегмент 2: 14:32 .. 15:32 (длительность 1 ч = 3600 сек)
      final seg2Start = localToUtc(14, 32);
      final seg2 = Segment(
        id: 'seg-2',
        draftId: 'draft-1',
        sourceLogId: 'log-2',
        issueId: '102',
        startUtc: seg2Start,
        durationSeconds: 3600,
        description: 'Вторая задача',
      );

      final gaps = DayBuilder.computeTimelineGaps(
        dayStartUtc: seg1Start,
        dayEndUtc: seg2.endUtc,
        segments: [seg1, seg2],
        existingWorklogs: [],
        draftId: 'draft-1',
      );

      expect(gaps.length, 1);
      final gap = gaps.first;
      expect(gap.startUtc, seg1.endUtc); // 10:37 local
      expect(gap.endUtc, seg2Start); // 14:32 local
      expect(gap.durationSeconds, (3 * 3600) + (55 * 60)); // 3 ч 55 мин
      expect(gap.kind, BreakKind.short); // Все зазоры трактуются как обычные перерывы
    });

    test('Вычисляет зазоры перед первой задачей и после последней задачи до границ дня', () {
      final dayStart = localToUtc(8, 0); // 08:00 local
      final dayEnd = localToUtc(17, 0); // 17:00 local

      // Единственная задача: 10:00 .. 12:00 local
      final taskStart = localToUtc(10, 0);
      final seg = Segment(
        id: 'seg-1',
        draftId: 'draft-1',
        sourceLogId: 'log-1',
        issueId: '101',
        startUtc: taskStart,
        durationSeconds: 2 * 3600,
        description: 'Работа',
      );

      final gaps = DayBuilder.computeTimelineGaps(
        dayStartUtc: dayStart,
        dayEndUtc: dayEnd,
        segments: [seg],
        existingWorklogs: [],
        draftId: 'draft-1',
      );

      expect(gaps.length, 2);
      // Первый зазор: 08:00 .. 10:00 (2 часа)
      expect(gaps[0].startUtc, dayStart);
      expect(gaps[0].endUtc, taskStart);
      expect(gaps[0].durationSeconds, 2 * 3600);
      expect(gaps[0].kind, BreakKind.short);

      // Второй зазор: 12:00 .. 17:00 (5 часов)
      expect(gaps[1].startUtc, seg.endUtc);
      expect(gaps[1].endUtc, dayEnd);
      expect(gaps[1].durationSeconds, 5 * 3600);
      expect(gaps[1].kind, BreakKind.short);
    });

    test('Не создаёт зазоров, если задачи и существующие записи идут встык', () {
      final start = localToUtc(9, 0);
      final seg1 = Segment(
        id: 'seg-1',
        draftId: 'draft-1',
        sourceLogId: 'log-1',
        issueId: '101',
        startUtc: start,
        durationSeconds: 3600, // 09:00 .. 10:00
        description: 'Задача 1',
      );

      // Существующая запись Jira: 10:00 .. 11:00
      final ew = ImportedWorklog(
        id: 'jw-1',
        issueId: '101',
        issueKey: 'PROJ-1',
        authorAccountId: 'acc-1',
        startUtc: localToUtc(10, 0),
        durationSeconds: 3600,
      );

      // Сегмент 2: 11:00 .. 12:00
      final seg2 = Segment(
        id: 'seg-2',
        draftId: 'draft-1',
        sourceLogId: 'log-2',
        issueId: '102',
        startUtc: localToUtc(11, 0),
        durationSeconds: 3600,
        description: 'Задача 2',
      );

      final gaps = DayBuilder.computeTimelineGaps(
        dayStartUtc: start,
        dayEndUtc: seg2.endUtc,
        segments: [seg1, seg2],
        existingWorklogs: [ew],
        draftId: 'draft-1',
      );

      expect(gaps, isEmpty);
    });

    test('Учитывает запланированный обед из plannedBreaks', () {
      final start = localToUtc(9, 0);
      final seg1 = Segment(
        id: 'seg-1',
        draftId: 'draft-1',
        sourceLogId: 'log-1',
        issueId: '101',
        startUtc: start,
        durationSeconds: 3600, // 09:00 .. 10:00
        description: 'Задача 1',
      );
      final seg2 = Segment(
        id: 'seg-2',
        draftId: 'draft-1',
        sourceLogId: 'log-2',
        issueId: '102',
        startUtc: localToUtc(11, 0), // 11:00 .. 12:00
        durationSeconds: 3600,
        description: 'Задача 2',
      );

      // Запланированный обед: 10:15 .. 10:45
      final plannedLunch = Break(
        id: 'lunch-1',
        draftId: 'draft-1',
        startUtc: localToUtc(10, 15),
        durationSeconds: 1800,
        kind: BreakKind.lunch,
      );

      final gaps = DayBuilder.computeTimelineGaps(
        dayStartUtc: start,
        dayEndUtc: seg2.endUtc,
        segments: [seg1, seg2],
        existingWorklogs: [],
        plannedBreaks: [plannedLunch],
        draftId: 'draft-1',
      );

      expect(gaps.length, 1);
      expect(gaps.first.kind, BreakKind.short);
    });
  });
}
