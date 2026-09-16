import 'package:flutter_test/flutter_test.dart';
import 'package:jira_time_tracker/day_builder.dart';
import 'package:jira_time_tracker/models.dart';

void main() {
  group('DayBuilder.buildAsRecorded - Дефолтная прямая сборка дня', () {
    final targetDate = DateTime(2026, 9, 16);
    const testOffset = Duration(hours: 3); // UTC+3

    test('Проецирует время таймера и ручного лога на целевую дату', () {
      // 1. Таймер стартовал 14 сентября в 10:15 local (07:15 UTC) и длился 45 минут
      final timerStartUtc = DateTime.utc(2026, 9, 14, 7, 15);
      final timerLog = DayBuilderLogInput(
        sourceLogId: 'timer-1',
        issueId: '1001',
        titleSnapshot: 'Задача 1',
        sourceDurationSeconds: 45 * 60, // 2700 сек
        originalStartUtc: timerStartUtc,
        originalEndUtc: timerStartUtc.add(const Duration(minutes: 45)),
      );

      // 2. Ручной лог сохранён 15 сентября в 16:30 local (13:30 UTC) на 1.5 часа
      // Окончание работы = 16:30, начало = 15:00 local (12:00 UTC)
      final manualCreatedUtc = DateTime.utc(2026, 9, 15, 13, 30);
      final manualLog = DayBuilderLogInput(
        sourceLogId: 'manual-1',
        issueId: '1002',
        titleSnapshot: 'Задача 2',
        sourceDurationSeconds: 90 * 60, // 5400 сек
        originalStartUtc: manualCreatedUtc.subtract(const Duration(minutes: 90)),
        originalEndUtc: manualCreatedUtc,
      );

      final input = DayBuilderInput(
        localDate: targetDate,
        timeZoneOffset: testOffset,
        settings: const DaySettings(),
        logs: [timerLog, manualLog],
      );

      final plan = DayBuilder.buildAsRecorded(input: input);

      expect(plan.segments.length, 2);
      expect(plan.breaks, isEmpty); // Без искусственных пауз

      // Первый сегмент: 16 сентября 10:15 local (07:15 UTC) .. 11:00 local (08:00 UTC)
      final seg1 = plan.segments.firstWhere((s) => s.sourceLogId == 'timer-1');
      expect(seg1.startUtc, DateTime.utc(2026, 9, 16, 7, 15));
      expect(seg1.durationSeconds, 45 * 60);

      // Второй сегмент: 16 сентября 15:00 local (12:00 UTC) .. 16:30 local (13:30 UTC)
      final seg2 = plan.segments.firstWhere((s) => s.sourceLogId == 'manual-1');
      expect(seg2.startUtc, DateTime.utc(2026, 9, 16, 12, 0));
      expect(seg2.durationSeconds, 90 * 60);

      // Длительности строго равны исходным
      expect(plan.totalNewWorkSeconds, (45 + 90) * 60);
      expect(plan.totalBreaksSeconds, 0);

      final errors = DayBuilder.validate(plan: plan, requirePauses: false);
      expect(errors, isEmpty);
    });

    test('Каскадно сдвигает параллельные и пересекающиеся логи без потери времени', () {
      // Три лога, которые пересекаются:
      // Лог 1: 10:00..11:00 local (07:00..08:00 UTC), длительность 60 мин
      final log1Start = DateTime.utc(2026, 9, 16, 7, 0);
      final log1 = DayBuilderLogInput(
        sourceLogId: 'log-1',
        issueId: '1001',
        titleSnapshot: 'Задача 1',
        sourceDurationSeconds: 3600,
        originalStartUtc: log1Start,
        originalEndUtc: log1Start.add(const Duration(hours: 1)),
      );

      // Лог 2: 10:00..10:30 local (07:00..07:30 UTC), параллельный, длительность 30 мин
      final log2Start = DateTime.utc(2026, 9, 16, 7, 0);
      final log2 = DayBuilderLogInput(
        sourceLogId: 'log-2',
        issueId: '1002',
        titleSnapshot: 'Задача 2',
        sourceDurationSeconds: 1800,
        originalStartUtc: log2Start,
        originalEndUtc: log2Start.add(const Duration(minutes: 30)),
      );

      // Лог 3: 10:45..11:45 local (07:45..08:45 UTC), длительность 60 мин
      final log3Start = DateTime.utc(2026, 9, 16, 7, 45);
      final log3 = DayBuilderLogInput(
        sourceLogId: 'log-3',
        issueId: '1003',
        titleSnapshot: 'Задача 3',
        sourceDurationSeconds: 3600,
        originalStartUtc: log3Start,
        originalEndUtc: log3Start.add(const Duration(hours: 1)),
      );

      final input = DayBuilderInput(
        localDate: targetDate,
        timeZoneOffset: testOffset,
        settings: const DaySettings(),
        logs: [log1, log2, log3],
      );

      final plan = DayBuilder.buildAsRecorded(input: input);

      expect(plan.segments.length, 3);

      final seg1 = plan.segments.firstWhere((s) => s.sourceLogId == 'log-1');
      final seg2 = plan.segments.firstWhere((s) => s.sourceLogId == 'log-2');
      final seg3 = plan.segments.firstWhere((s) => s.sourceLogId == 'log-3');

      // Лог 1 остаётся в 07:00..08:00 UTC (10:00..11:00 local)
      expect(seg1.startUtc, DateTime.utc(2026, 9, 16, 7, 0));
      expect(seg1.endUtc, DateTime.utc(2026, 9, 16, 8, 0));

      // Лог 2 сдвигается на окончание лога 1: 08:00..08:30 UTC (11:00..11:30 local)
      expect(seg2.startUtc, DateTime.utc(2026, 9, 16, 8, 0));
      expect(seg2.endUtc, DateTime.utc(2026, 9, 16, 8, 30));

      // Лог 3 сдвигается на окончание лога 2: 08:30..09:30 UTC (11:30..12:30 local)
      expect(seg3.startUtc, DateTime.utc(2026, 9, 16, 8, 30));
      expect(seg3.endUtc, DateTime.utc(2026, 9, 16, 9, 30));

      // Никаких пересечений!
      final errors = DayBuilder.validate(plan: plan, requirePauses: false);
      expect(errors, isEmpty);
    });

    test('Сдвигает локальные логи вокруг существующих записей Jira', () {
      // Существующая запись в Jira: 10:00..11:00 local (07:00..08:00 UTC)
      final existingWorklog = ImportedWorklog(
        id: 'jira-1',
        issueId: '10099',
        startUtc: DateTime.utc(2026, 9, 16, 7, 0),
        durationSeconds: 3600,
        authorAccountId: 'acc-1',
      );

      // Локальный лог: 10:30..11:30 local (07:30..08:30 UTC)
      final localStart = DateTime.utc(2026, 9, 16, 7, 30);
      final localLog = DayBuilderLogInput(
        sourceLogId: 'local-1',
        issueId: '1001',
        titleSnapshot: 'Локальная задача',
        sourceDurationSeconds: 3600,
        originalStartUtc: localStart,
        originalEndUtc: localStart.add(const Duration(hours: 1)),
      );

      final input = DayBuilderInput(
        localDate: targetDate,
        timeZoneOffset: testOffset,
        settings: const DaySettings(),
        existingWorklogs: [existingWorklog],
        logs: [localLog],
      );

      final plan = DayBuilder.buildAsRecorded(input: input);

      final seg = plan.segments.single;
      // Сдвинулся на окончание существующей записи Jira: 08:00..09:00 UTC (11:00..12:00 local)
      expect(seg.startUtc, DateTime.utc(2026, 9, 16, 8, 0));
      expect(seg.endUtc, DateTime.utc(2026, 9, 16, 9, 0));
      expect(seg.durationSeconds, 3600);

      final errors = DayBuilder.validate(
        plan: plan,
        existingWorklogs: [existingWorklog],
        requirePauses: false,
      );
      expect(errors, isEmpty);
    });

    test('Не разбивает задачи свыше 1 часа в дефолтном режиме', () {
      // Задача длительностью 3.5 часа (12600 сек)
      final start = DateTime.utc(2026, 9, 16, 6, 0);
      final bigLog = DayBuilderLogInput(
        sourceLogId: 'big-1',
        issueId: '1001',
        titleSnapshot: 'Большая непрерывная задача',
        sourceDurationSeconds: 12600,
        originalStartUtc: start,
        originalEndUtc: start.add(const Duration(seconds: 12600)),
      );

      final input = DayBuilderInput(
        localDate: targetDate,
        timeZoneOffset: testOffset,
        settings: const DaySettings(),
        logs: [bigLog],
      );

      final plan = DayBuilder.buildAsRecorded(input: input);

      // В дефолтном режиме задача НЕ дробится — ровно один непрерывный сегмент
      expect(plan.segments.length, 1);
      expect(plan.segments.single.durationSeconds, 12600);
      expect(plan.totalNewWorkSeconds, 12600);
    });
  });
}
