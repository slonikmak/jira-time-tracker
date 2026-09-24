import 'package:flutter_test/flutter_test.dart';
import 'package:jira_time_tracker/day_builder.dart';
import 'package:jira_time_tracker/models.dart';

void main() {
  group('DayBuilder - Фиксированные якоря и сохранение последовательности (Issue 02)', () {
    final testDate = DateTime(2026, 9, 14);
    const testOffset = Duration(hours: 3); // UTC+3
    final localMidnightUtc = DateTime.utc(2026, 9, 14).subtract(testOffset);

    test('Корректное позиционирование фиксированного созвона на заданное время', () {
      final input = DayBuilderInput(
        localDate: testDate,
        timeZoneOffset: testOffset,
        settings: const DaySettings(
          startMinutesMin: 9 * 60,
          startMinutesMax: 9 * 60,
          lunchStartMinutesMin: 13 * 60,
          lunchStartMinutesMax: 13 * 60,
          lunchDurationSecondsMin: 3600,
          lunchDurationSecondsMax: 3600,
          shortBreakCountMin: 1,
          shortBreakCountMax: 1,
          shortBreakDurationSecondsMin: 600,
          shortBreakDurationSecondsMax: 600,
        ),
        logs: const [
          DayBuilderLogInput(
            sourceLogId: 'log-standup',
            issueId: 'MEET-1',
            titleSnapshot: 'Daily Standup',
            description: 'Ежедневный созвон',
            sourceDurationSeconds: 1800, // 30 минут
            isFixed: true,
            fixedStartTime: '11:00',
          ),
          DayBuilderLogInput(
            sourceLogId: 'log-dev',
            issueId: 'DEV-1',
            titleSnapshot: 'Feature dev',
            description: 'Разработка фичи',
            sourceDurationSeconds: 7200, // 2 часа
          ),
        ],
      );

      final plan = DayBuilder.build(input: input, seed: 42);

      final standupSegment = plan.segments.firstWhere((s) => s.sourceLogId == 'log-standup');
      final expectedStart = localMidnightUtc.add(const Duration(hours: 11));

      expect(standupSegment.isFixed, isTrue);
      expect(standupSegment.startUtc, expectedStart);
      expect(standupSegment.durationSeconds, 1800);

      final errors = DayBuilder.validate(plan: plan);
      expect(errors, isEmpty);
    });

    test('Ошибка при пересечении двух фиксированных созвонов', () {
      final input = DayBuilderInput(
        localDate: testDate,
        timeZoneOffset: testOffset,
        settings: const DaySettings(),
        logs: const [
          DayBuilderLogInput(
            sourceLogId: 'meet-1',
            issueId: 'MEET-1',
            titleSnapshot: 'Созвон 1',
            sourceDurationSeconds: 1800, // 30 мин: 11:00 - 11:30
            isFixed: true,
            fixedStartTime: '11:00',
          ),
          DayBuilderLogInput(
            sourceLogId: 'meet-2',
            issueId: 'MEET-2',
            titleSnapshot: 'Созвон 2',
            sourceDurationSeconds: 1800, // 30 мин: 11:15 - 11:45
            isFixed: true,
            fixedStartTime: '11:15',
          ),
        ],
      );

      expect(
        () => DayBuilder.build(input: input, seed: 42),
        throwsA(
          isA<DayBuilderException>().having(
            (e) => e.message,
            'message',
            contains('Обнаружен конфликт: фиксированная задача "Созвон 1" пересекается с задачей "Созвон 2"'),
          ),
        ),
      );
    });

    test('Ошибка при пересечении фиксированного созвона с существующей записью Jira', () {
      final jiraWorklogStart = localMidnightUtc.add(const Duration(hours: 10, minutes: 30));
      final input = DayBuilderInput(
        localDate: testDate,
        timeZoneOffset: testOffset,
        settings: const DaySettings(),
        existingWorklogs: [
          ImportedWorklog(
            id: 'jira-1',
            issueId: '10001',
            issueKey: 'PROJ-JIRA',
            startUtc: jiraWorklogStart,
            durationSeconds: 3600, // 10:30 - 11:30
            authorAccountId: 'author-1',
          ),
        ],
        logs: const [
          DayBuilderLogInput(
            sourceLogId: 'meet-1',
            issueId: 'MEET-1',
            titleSnapshot: 'Созвон команды',
            sourceDurationSeconds: 1800, // 11:00 - 11:30
            isFixed: true,
            fixedStartTime: '11:00',
          ),
        ],
      );

      expect(
        () => DayBuilder.build(input: input, seed: 42),
        throwsA(
          isA<DayBuilderException>().having(
            (e) => e.message,
            'message',
            contains('пересекается с существующей записью в Jira "PROJ-JIRA"'),
          ),
        ),
      );
    });

    test('Разрезание плавающей задачи при окне >= 15 минут перед созвоном', () {
      // День начинается ровно в 09:30, созвон в 10:00 (окно 30 мин >= 15 мин)
      final input = DayBuilderInput(
        localDate: testDate,
        timeZoneOffset: testOffset,
        settings: const DaySettings(
          startMinutesMin: 9 * 60 + 30, // 09:30
          startMinutesMax: 9 * 60 + 30,
          totalDurationSecondsMin: 4 * 3600,
          totalDurationSecondsMax: 4 * 3600,
          lunchDurationSecondsMin: 0,
          lunchDurationSecondsMax: 0,
          shortBreakCountMin: 0,
          shortBreakCountMax: 0,
        ),
        logs: const [
          DayBuilderLogInput(
            sourceLogId: 'task-dev',
            issueId: 'DEV-1',
            titleSnapshot: 'Большая разработка',
            sourceDurationSeconds: 3600, // 60 минут
            durationLocked: true,
          ),
          DayBuilderLogInput(
            sourceLogId: 'task-meet',
            issueId: 'MEET-1',
            titleSnapshot: 'Созвон',
            sourceDurationSeconds: 1800, // 30 минут (10:00 - 10:30)
            isFixed: true,
            fixedStartTime: '10:00',
          ),
        ],
      );

      final plan = DayBuilder.rebuildDayPlan(input: input, seed: 42);

      final devSegments = plan.segments.where((s) => s.sourceLogId == 'task-dev').toList();
      final meetSegment = plan.segments.firstWhere((s) => s.sourceLogId == 'task-meet');

      // Задача task-dev должна быть разрезана на 2 части: до созвона и после созвона
      expect(devSegments.length, 2);

      final part1 = devSegments[0];
      final part2 = devSegments[1];

      final expectedDayStart = localMidnightUtc.add(const Duration(hours: 9, minutes: 30));
      final expectedMeetStart = localMidnightUtc.add(const Duration(hours: 10));
      final expectedMeetEnd = localMidnightUtc.add(const Duration(hours: 10, minutes: 30));

      expect(part1.startUtc, expectedDayStart);
      expect(part1.endUtc, expectedMeetStart);
      expect(part1.durationSeconds, 1800); // 30 мин до созвона

      expect(meetSegment.startUtc, expectedMeetStart);
      expect(meetSegment.endUtc, expectedMeetEnd);

      // Нулевое число дополнительных пауз не отменяет обязательный разрыв
      // между сгенерированными рабочими интервалами.
      expect(part2.startUtc, expectedMeetEnd.add(const Duration(minutes: 5)));
      expect(part2.durationSeconds, 1800); // 30 мин после созвона

      // Суммарное время совпадает с исходным
      expect(part1.durationSeconds + part2.durationSeconds, 3600);

      final errors = DayBuilder.validate(plan: plan);
      expect(errors, isEmpty);
    });

    test('Перенос задачи целиком при окне < 15 минут перед созвоном', () {
      // День начинается в 09:50, созвон в 10:00 (окно 10 мин < 15 мин)
      final input = DayBuilderInput(
        localDate: testDate,
        timeZoneOffset: testOffset,
        settings: const DaySettings(
          startMinutesMin: 9 * 60 + 50, // 09:50
          startMinutesMax: 9 * 60 + 50,
          totalDurationSecondsMin: 4 * 3600,
          totalDurationSecondsMax: 4 * 3600,
          lunchDurationSecondsMin: 0,
          lunchDurationSecondsMax: 0,
          shortBreakCountMin: 0,
          shortBreakCountMax: 0,
        ),
        logs: const [
          DayBuilderLogInput(
            sourceLogId: 'task-dev',
            issueId: 'DEV-1',
            titleSnapshot: 'Разработка',
            sourceDurationSeconds: 3600, // 60 минут
            durationLocked: true,
          ),
          DayBuilderLogInput(
            sourceLogId: 'task-meet',
            issueId: 'MEET-1',
            titleSnapshot: 'Созвон',
            sourceDurationSeconds: 1800, // 30 минут (10:00 - 10:30)
            isFixed: true,
            fixedStartTime: '10:00',
          ),
        ],
      );

      final plan = DayBuilder.rebuildDayPlan(input: input, seed: 42);

      final devSegments = plan.segments.where((s) => s.sourceLogId == 'task-dev').toList();
      final meetSegment = plan.segments.firstWhere((s) => s.sourceLogId == 'task-meet');

      // Задача не должна быть порезана на кусочек < 15 минут перед созвоном!
      // Она должна быть перенесена целиком за созвон.
      expect(devSegments.length, 1);
      final dev = devSegments.first;

      final expectedMeetStart = localMidnightUtc.add(const Duration(hours: 10));
      final expectedMeetEnd = localMidnightUtc.add(const Duration(hours: 10, minutes: 30));

      expect(meetSegment.startUtc, expectedMeetStart);
      expect(meetSegment.endUtc, expectedMeetEnd);

      expect(dev.startUtc.isAtSameMomentAs(expectedMeetEnd) || dev.startUtc.isAfter(expectedMeetEnd), isTrue);
      expect(dev.durationSeconds, 3600);

      final errors = DayBuilder.validate(plan: plan);
      expect(errors, isEmpty);
    });

    test('Строгое сохранение порядка задач при вызове rebuildDayPlan', () {
      final input = DayBuilderInput(
        localDate: testDate,
        timeZoneOffset: testOffset,
        settings: const DaySettings(
          startMinutesMin: 9 * 60,
          startMinutesMax: 9 * 60,
          totalDurationSecondsMin: 6 * 3600,
          totalDurationSecondsMax: 6 * 3600,
          lunchDurationSecondsMin: 0,
          lunchDurationSecondsMax: 0,
          shortBreakCountMin: 2,
          shortBreakCountMax: 2,
          shortBreakDurationSecondsMin: 300,
          shortBreakDurationSecondsMax: 300,
        ),
        logs: const [
          DayBuilderLogInput(
            sourceLogId: 'task-C',
            issueId: 'TASK-C',
            titleSnapshot: 'Задача C',
            sourceDurationSeconds: 2700, // 45 мин
            durationLocked: true,
          ),
          DayBuilderLogInput(
            sourceLogId: 'task-A',
            issueId: 'TASK-A',
            titleSnapshot: 'Задача A',
            sourceDurationSeconds: 3600, // 60 мин
            durationLocked: true,
          ),
          DayBuilderLogInput(
            sourceLogId: 'task-B',
            issueId: 'TASK-B',
            titleSnapshot: 'Задача B',
            sourceDurationSeconds: 1800, // 30 мин
            durationLocked: true,
          ),
        ],
      );

      final plan = DayBuilder.rebuildDayPlan(input: input, seed: 999);

      // Проверяем последовательность появления задач в расписании
      // Схлопываем повторяющиеся последовательные сегменты одного лога
      final distinctSequence = <String>[];
      for (final s in plan.segments) {
        if (distinctSequence.isEmpty || distinctSequence.last != s.sourceLogId) {
          distinctSequence.add(s.sourceLogId);
        }
      }
      expect(distinctSequence, ['task-C', 'task-A', 'task-B']);

      // Проверяем, что интервалы идут друг за другом
      expect(plan.segments[0].endUtc.isBefore(plan.segments[1].startUtc) ||
          plan.segments[0].endUtc.isAtSameMomentAs(plan.segments[1].startUtc), isTrue);
      expect(plan.segments[1].endUtc.isBefore(plan.segments[2].startUtc) ||
          plan.segments[1].endUtc.isAtSameMomentAs(plan.segments[2].startUtc), isTrue);

      final errors = DayBuilder.validate(plan: plan);
      expect(errors, isEmpty);
    });
  });
}
