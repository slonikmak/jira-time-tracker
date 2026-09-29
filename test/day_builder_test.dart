import 'package:flutter_test/flutter_test.dart';
import 'package:jira_time_tracker/day_builder.dart';
import 'package:jira_time_tracker/models.dart';

void main() {
  group('DayBuilder - Чистый алгоритм сборки дня', () {
    final testDate = DateTime(2026, 9, 14);
    const testOffset = Duration(hours: 3); // UTC+3

    test(
      'A06: Детерминизм при фиксированном seed и неизменных входных данных',
      () {
        final input = DayBuilderInput(
          localDate: testDate,
          timeZoneOffset: testOffset,
          settings: const DaySettings(),
          logs: [
            const DayBuilderLogInput(
              sourceLogId: 'log-1',
              issueId: '10001',
              titleSnapshot: 'PROJ-1',
              description: 'Разработка фичи',
              sourceDurationSeconds: 7200, // 2 часа
            ),
            const DayBuilderLogInput(
              sourceLogId: 'log-2',
              issueId: '10002',
              titleSnapshot: 'PROJ-2',
              description: 'Код ревью',
              sourceDurationSeconds: 3600, // 1 час
            ),
            const DayBuilderLogInput(
              sourceLogId: 'log-3',
              issueId: '10003',
              titleSnapshot: 'PROJ-3',
              description: 'Багфикс',
              sourceDurationSeconds: 5400, // 1.5 часа
            ),
          ],
        );

        for (final seed in [42, 100, 9999]) {
          final plan1 = DayBuilder.build(input: input, seed: seed);
          final plan2 = DayBuilder.build(input: input, seed: seed);

          // Строгая идентичность всех параметров при одинаковом seed
          expect(plan1.dayStartUtc, plan2.dayStartUtc);
          expect(plan1.dayEndUtc, plan2.dayEndUtc);
          expect(plan1.totalDaySeconds, plan2.totalDaySeconds);
          expect(plan1.totalNewWorkSeconds, plan2.totalNewWorkSeconds);
          expect(plan1.totalBreaksSeconds, plan2.totalBreaksSeconds);
          expect(plan1.segments.length, plan2.segments.length);
          expect(plan1.breaks.length, plan2.breaks.length);

          for (var i = 0; i < plan1.segments.length; i++) {
            final s1 = plan1.segments[i];
            final s2 = plan2.segments[i];
            expect(s1.id, s2.id);
            expect(s1.sourceLogId, s2.sourceLogId);
            expect(s1.startUtc, s2.startUtc);
            expect(s1.durationSeconds, s2.durationSeconds);
            expect(s1.description, s2.description);
          }

          // Общая длительность дня не превышает 8 часов
          expect(plan1.totalDaySeconds, lessThanOrEqualTo(28800));

          // Все логи представлены
          final representedSources = plan1.segments
              .map((s) => s.sourceLogId)
              .toSet();
          expect(representedSources, containsAll(['log-1', 'log-2', 'log-3']));

          // Валидация проходит без ошибок (нет пересечений, день <= 8ч)
          final errors = DayBuilder.validate(plan: plan1);
          expect(errors, isEmpty);
        }
      },
    );

    test(
      'A07: арифметика дня учитывает обязательные паузы между интервалами',
      () {
        // 08:34 local = 8 * 60 + 34 = 514 минут
        const startMin = 8 * 60 + 34;
        const dayDurSec = 7 * 3600 + 48 * 60; // 28080 сек (7:48)
        const lunchDurSec = 35 * 60; // 2100 сек (35 мин)
        const shortBreakDurSec = 8 * 60; // 480 сек (8 мин)

        final customSettings = DaySettings(
          startMinutesMin: startMin,
          startMinutesMax: startMin,
          totalDurationSecondsMin: dayDurSec,
          totalDurationSecondsMax: dayDurSec,
          lunchStartMinutesMin: 12 * 60,
          lunchStartMinutesMax: 13 * 60,
          lunchDurationSecondsMin: lunchDurSec,
          lunchDurationSecondsMax: lunchDurSec,
          shortBreakCountMin: 2,
          shortBreakCountMax: 2,
          shortBreakDurationSecondsMin: shortBreakDurSec,
          shortBreakDurationSecondsMax: shortBreakDurSec,
        );

        // Существующая запись в Jira на 1 час (10:00 до 11:00 local = 07:00 до 08:00 UTC)
        final existingStartUtc = DateTime.utc(2026, 9, 14, 7, 0); // 10:00 local
        final existingWorklog = ImportedWorklog(
          id: 'jira-wl-1',
          issueId: '10099',
          issueKey: 'EXIST-1',
          startUtc: existingStartUtc,
          durationSeconds: 3600, // 1 час
          authorAccountId: 'acc-123',
        );

        final input = DayBuilderInput(
          localDate: testDate,
          timeZoneOffset: testOffset,
          settings: customSettings,
          existingWorklogs: [existingWorklog],
          logs: [
            const DayBuilderLogInput(
              sourceLogId: 'log-a',
              issueId: '10001',
              titleSnapshot: 'PROJ-1',
              description: 'Работа над проектом',
              sourceDurationSeconds: 10000,
            ),
          ],
        );

        final plan = DayBuilder.build(input: input, seed: 12345);

        // Проверка точных чисел из спецификации:
        // Полный день 7:48 = 28080 сек
        expect(plan.totalDaySeconds, 28080);

        // Базовые паузы: обед 35 мин + 2 паузы по 8 мин = 51 мин.
        // Сборщик может добавить паузы между соседними рабочими интервалами.
        expect(plan.totalBreaksSeconds, greaterThanOrEqualTo(3060));

        // Существующая работа: 1 час = 3600 сек
        expect(plan.totalExistingSeconds, 3600);

        // Обязательные паузы уменьшают верхний бюджет новых интервалов 5:57.
        expect(plan.totalNewWorkSeconds, lessThanOrEqualTo(21420));
        expect(
          plan.totalExistingSeconds +
              plan.totalNewWorkSeconds +
              plan.totalBreaksSeconds,
          lessThanOrEqualTo(plan.totalDaySeconds),
        );

        // Сегменты и паузы не пересекаются с существующим логом
        final errors = DayBuilder.validate(
          plan: plan,
          existingWorklogs: [existingWorklog],
        );
        expect(errors, isEmpty);
      },
    );

    test('Ноль дополнительных пауз сохраняет обязательную паузу между сегментами', () {
      final input = DayBuilderInput(
        localDate: testDate,
        timeZoneOffset: testOffset,
        settings: const DaySettings(
          shortBreakCountMin: 0,
          shortBreakCountMax: 0,
        ),
        logs: const [
          DayBuilderLogInput(
            sourceLogId: 'log-a',
            issueId: '10001',
            titleSnapshot: 'PROJ-1',
            description: 'Работа A',
            sourceDurationSeconds: 3600,
          ),
          DayBuilderLogInput(
            sourceLogId: 'log-b',
            issueId: '10002',
            titleSnapshot: 'PROJ-2',
            description: 'Работа B',
            sourceDurationSeconds: 3600,
          ),
        ],
      );

      final plan = DayBuilder.build(input: input, seed: 42);
      expect(plan.segments.length, greaterThanOrEqualTo(2));
      expect(plan.breaks, isNotEmpty);
      expect(DayBuilder.validate(plan: plan), isEmpty);
    });

    test('Длинная пауза не переносится за пределы выбранного диапазона', () {
      final input = DayBuilderInput(
        localDate: testDate,
        timeZoneOffset: testOffset,
        settings: const DaySettings(
          startMinutesMin: 8 * 60,
          startMinutesMax: 8 * 60,
          totalDurationSecondsMin: 8 * 3600,
          totalDurationSecondsMax: 8 * 3600,
          lunchStartMinutesMin: 23 * 60,
          lunchStartMinutesMax: 23 * 60,
          shortBreakCountMin: 0,
          shortBreakCountMax: 0,
        ),
        logs: const [
          DayBuilderLogInput(
            sourceLogId: 'log-a',
            issueId: '10001',
            titleSnapshot: 'PROJ-1',
            sourceDurationSeconds: 4 * 3600,
          ),
        ],
      );

      expect(
        () => DayBuilder.build(input: input, seed: 42),
        throwsA(isA<DayBuilderException>()),
      );
    });

    test('Число коротких пауз соблюдается и для короткого дня', () {
      final input = DayBuilderInput(
        localDate: testDate,
        timeZoneOffset: testOffset,
        settings: const DaySettings(
          startMinutesMin: 8 * 60,
          startMinutesMax: 8 * 60,
          totalDurationSecondsMin: 3 * 3600,
          totalDurationSecondsMax: 3 * 3600,
          lunchDurationSecondsMin: 0,
          lunchDurationSecondsMax: 0,
          shortBreakCountMin: 3,
          shortBreakCountMax: 3,
          shortBreakDurationSecondsMin: 5 * 60,
          shortBreakDurationSecondsMax: 10 * 60,
        ),
        logs: const [
          DayBuilderLogInput(
            sourceLogId: 'log-a',
            issueId: '10001',
            titleSnapshot: 'PROJ-1',
            sourceDurationSeconds: 2 * 3600,
          ),
        ],
      );

      final plan = DayBuilder.build(input: input, seed: 42);
      // Дополнительные паузы выбираются из диапазона, а обязательные
      // разделители рабочих частей используют ровно нижнюю границу.
      expect(plan.breaks.where((b) => b.durationSeconds > 5 * 60).length, 3);
      expect(DayBuilder.validate(plan: plan), isEmpty);
    });

    test('Невозможное число коротких пауз приводит к ошибке', () {
      final input = DayBuilderInput(
        localDate: testDate,
        timeZoneOffset: testOffset,
        settings: const DaySettings(
          startMinutesMin: 8 * 60,
          startMinutesMax: 8 * 60,
          totalDurationSecondsMin: 60 * 60,
          totalDurationSecondsMax: 60 * 60,
          lunchDurationSecondsMin: 0,
          lunchDurationSecondsMax: 0,
          shortBreakCountMin: 3,
          shortBreakCountMax: 3,
          shortBreakDurationSecondsMin: 20 * 60,
          shortBreakDurationSecondsMax: 20 * 60,
        ),
        logs: const [
          DayBuilderLogInput(
            sourceLogId: 'log-a',
            issueId: '10001',
            titleSnapshot: 'PROJ-1',
            sourceDurationSeconds: 15 * 60,
          ),
        ],
      );

      expect(
        () => DayBuilder.build(input: input, seed: 42),
        throwsA(isA<DayBuilderException>()),
      );
    });

    test('Короткие паузы размещаются после ранней длинной паузы', () {
      final input = DayBuilderInput(
        localDate: testDate,
        timeZoneOffset: testOffset,
        settings: const DaySettings(
          startMinutesMin: 8 * 60,
          startMinutesMax: 8 * 60,
          totalDurationSecondsMin: 8 * 3600,
          totalDurationSecondsMax: 8 * 3600,
          lunchStartMinutesMin: 8 * 60,
          lunchStartMinutesMax: 8 * 60,
          lunchDurationSecondsMin: 30 * 60,
          lunchDurationSecondsMax: 30 * 60,
          shortBreakCountMin: 2,
          shortBreakCountMax: 2,
          shortBreakDurationSecondsMin: 5 * 60,
          shortBreakDurationSecondsMax: 5 * 60,
        ),
        logs: const [
          DayBuilderLogInput(
            sourceLogId: 'log-a',
            issueId: '10001',
            titleSnapshot: 'PROJ-1',
            sourceDurationSeconds: 4 * 3600,
          ),
        ],
      );

      final plan = DayBuilder.build(input: input, seed: 42);
      final longBreak = plan.breaks.singleWhere((b) => b.durationSeconds == 30 * 60);
      expect(
        plan.breaks.where((b) => b.durationSeconds == 5 * 60).length,
        greaterThanOrEqualTo(2),
      );
      expect(
        plan.breaks
            .where((b) => b.id != longBreak.id)
            .every((b) => !b.startUtc.isBefore(longBreak.endUtc)),
        isTrue,
      );
    });

    test(
      'A08: Фиксация одного лога (durationLocked) сохраняет его длительность',
      () {
        final input = DayBuilderInput(
          localDate: testDate,
          timeZoneOffset: testOffset,
          settings: const DaySettings(),
          logs: [
            const DayBuilderLogInput(
              sourceLogId: 'locked-log',
              issueId: '10001',
              titleSnapshot: 'PROJ-1',
              description: 'Строго фиксированное время',
              sourceDurationSeconds: 7200, // 2 часа
              durationLocked: true,
            ),
            const DayBuilderLogInput(
              sourceLogId: 'flex-log',
              issueId: '10002',
              titleSnapshot: 'PROJ-2',
              description: 'Гибкое время',
              sourceDurationSeconds: 3600,
              durationLocked: false,
            ),
          ],
        );

        final plan = DayBuilder.build(input: input, seed: 777);

        // Зафиксированный лог получил ровно 7200 секунд
        expect(plan.allocatedSecondsBySourceLogId['locked-log'], 7200);

        final lockedSegmentsDuration = plan.segments
            .where((s) => s.sourceLogId == 'locked-log')
            .fold<int>(0, (sum, s) => sum + s.durationSeconds);
        expect(lockedSegmentsDuration, 7200);

        // Оставшийся бюджет ушёл гибкому логу
        expect(
          plan.allocatedSecondsBySourceLogId['flex-log'],
          plan.totalNewWorkSeconds - 7200,
        );
      },
    );

    test(
      'A08: Ошибка при невозможности вместить зафиксированное время без изменения входов',
      () {
        final originalLogs = [
          const DayBuilderLogInput(
            sourceLogId: 'locked-huge',
            issueId: '10001',
            titleSnapshot: 'PROJ-1',
            description: 'Слишком много фиксированного времени',
            sourceDurationSeconds: 28800, // 8 часов
            durationLocked: true,
          ),
        ];

        // Существующая запись в Jira на 3 часа
        final existingWorklog = ImportedWorklog(
          id: 'jira-wl-1',
          issueId: '10099',
          startUtc: DateTime.utc(2026, 9, 14, 7, 0),
          durationSeconds: 3 * 3600,
          authorAccountId: 'acc-123',
        );

        final input = DayBuilderInput(
          localDate: testDate,
          timeZoneOffset: testOffset,
          settings: const DaySettings(),
          existingWorklogs: [existingWorklog],
          logs: originalLogs,
        );

        // Должно выбросить DayBuilderException с понятным описанием доступных и требуемых часов
        expect(
          () => DayBuilder.build(input: input, seed: 42),
          throwsA(
            isA<DayBuilderException>().having(
              (e) => e.message,
              'message',
              contains('Фиксированные логи требуют'),
            ),
          ),
        );

        // Исходный список логов остался неизменным
        expect(originalLogs.first.sourceDurationSeconds, 28800);
        expect(originalLogs.first.durationLocked, isTrue);
      },
    );

    test(
      'A09: Большой лог (>120 минут) разбивается на части с сохранением источника и описания',
      () {
        const bigLogDuration = 3 * 3600 + 30 * 60; // 3.5 часа = 12600 сек

        final input = DayBuilderInput(
          localDate: testDate,
          timeZoneOffset: testOffset,
          settings: const DaySettings(),
          logs: [
            const DayBuilderLogInput(
              sourceLogId: 'big-log',
              issueId: '10001',
              titleSnapshot: 'PROJ-BIG',
              description: 'Большая комплексная задача',
              sourceDurationSeconds: bigLogDuration,
              durationLocked: true,
            ),
            const DayBuilderLogInput(
              sourceLogId: 'small-log',
              issueId: '10002',
              titleSnapshot: 'PROJ-SMALL',
              description: 'Маленькая задача',
              sourceDurationSeconds: 1800,
              durationLocked: false,
            ),
          ],
        );

        final plan = DayBuilder.build(input: input, seed: 54321);

        final bigSegments = plan.segments
            .where((s) => s.sourceLogId == 'big-log')
            .toList();

        // Лог должен быть разбит более чем на 1 сегмент
        expect(bigSegments.length, greaterThan(1));

        // Сумма всех частей строго равна выделенной длительности
        final sumBigSegments = bigSegments.fold<int>(
          0,
          (sum, s) => sum + s.durationSeconds,
        );
        expect(sumBigSegments, bigLogDuration);

        // Все части ссылаются на исходный sourceLogId и копируют описание
        for (final segment in bigSegments) {
          expect(segment.sourceLogId, 'big-log');
          expect(segment.issueId, '10001');
          expect(segment.description, 'Большая комплексная задача');
          expect(segment.durationSeconds, greaterThan(0));
          // Ни один интервал не должен превышать 120 минут (7200 сек)
          expect(segment.durationSeconds, lessThanOrEqualTo(7200));
        }
      },
    );

    test(
      'Сгенерированные интервалы не короче 15 минут и разделены паузами',
      () {
        final input = DayBuilderInput(
          localDate: testDate,
          timeZoneOffset: testOffset,
          settings: const DaySettings(),
          logs: const [
            DayBuilderLogInput(
              sourceLogId: 'log-short-a',
              issueId: '10001',
              titleSnapshot: 'PROJ-1',
              sourceDurationSeconds: 253,
            ),
            DayBuilderLogInput(
              sourceLogId: 'log-short-b',
              issueId: '10002',
              titleSnapshot: 'PROJ-2',
              sourceDurationSeconds: 15,
            ),
            DayBuilderLogInput(
              sourceLogId: 'log-long',
              issueId: '10003',
              titleSnapshot: 'PROJ-3',
              sourceDurationSeconds: 3600,
            ),
          ],
        );

        for (final seed in [42, 100, 243604981]) {
          final plan = DayBuilder.build(input: input, seed: seed);
          final segments = [...plan.segments]
            ..sort((a, b) => a.startUtc.compareTo(b.startUtc));

          for (final segment in segments) {
            expect(segment.durationSeconds, greaterThanOrEqualTo(15 * 60));
          }

          for (var i = 0; i < segments.length - 1; i++) {
            final current = segments[i];
            final next = segments[i + 1];
            final hasPause = plan.breaks.any(
              (pause) =>
                  !pause.startUtc.isBefore(current.endUtc) &&
                  !pause.endUtc.isAfter(next.startUtc),
            );
            expect(
              hasPause,
              isTrue,
              reason: 'Между ${current.id} и ${next.id} нет обязательной паузы',
            );
          }
        }
      },
    );

    test('Валидация полуоткрытых интервалов [start, end) и смежности', () {
      final now = DateTime.utc(2026, 9, 14, 8, 0);

      // Корректные интервалы с обязательной пятиминутной паузой.
      final validPlan = DayPlanResult(
        dayStartUtc: now,
        dayEndUtc: now.add(const Duration(hours: 8)),
        segments: [
          Segment(
            id: 'seg-1',
            draftId: 'd-1',
            sourceLogId: 'log-1',
            issueId: '1',
            startUtc: now,
            durationSeconds: 3600,
          ),
          Segment(
            id: 'seg-2',
            draftId: 'd-1',
            sourceLogId: 'log-2',
            issueId: '2',
            startUtc: now.add(const Duration(seconds: 3900)),
            durationSeconds: 3600,
          ),
        ],
        breaks: [
          Break(
            id: 'brk-1',
            draftId: 'd-1',
            startUtc: now.add(const Duration(seconds: 3600)),
            durationSeconds: 300,
            kind: BreakKind.short,
          ),
          Break(
            id: 'brk-2',
            draftId: 'd-1',
            startUtc: now.add(const Duration(seconds: 7500)),
            durationSeconds: 1800,
            kind: BreakKind.lunch,
          ),
        ],
        allocatedSecondsBySourceLogId: {'log-1': 3600, 'log-2': 3600},
        totalNewWorkSeconds: 7200,
        totalBreaksSeconds: 2100,
        totalExistingSeconds: 0,
        totalDaySeconds: 28800,
      );

      expect(DayBuilder.validate(plan: validPlan), isEmpty);

      // Пересекающиеся интервалы
      final overlappingPlan = DayPlanResult(
        dayStartUtc: now,
        dayEndUtc: now.add(const Duration(hours: 8)),
        segments: [
          Segment(
            id: 'seg-1',
            draftId: 'd-1',
            sourceLogId: 'log-1',
            issueId: '1',
            startUtc: now,
            durationSeconds: 3700, // перекрывает следующий на 100 сек
          ),
          Segment(
            id: 'seg-2',
            draftId: 'd-1',
            sourceLogId: 'log-2',
            issueId: '2',
            startUtc: now.add(const Duration(seconds: 3600)),
            durationSeconds: 3600,
          ),
        ],
        breaks: [],
        allocatedSecondsBySourceLogId: {},
        totalNewWorkSeconds: 7300,
        totalBreaksSeconds: 0,
        totalExistingSeconds: 0,
        totalDaySeconds: 28800,
      );

      final errors = DayBuilder.validate(plan: overlappingPlan);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('Обнаружено пересечение'));
      expect(
        DayBuilder.validate(
          plan: overlappingPlan,
          requirePauses: false,
          allowWorklogOverlaps: true,
        ),
        isEmpty,
      );

      final planWithBreak = DayPlanResult(
        dayStartUtc: overlappingPlan.dayStartUtc,
        dayEndUtc: overlappingPlan.dayEndUtc,
        segments: overlappingPlan.segments,
        breaks: [
          Break(
            id: 'nested-break',
            draftId: 'd-1',
            startUtc: now.add(const Duration(minutes: 30)),
            durationSeconds: 300,
            kind: BreakKind.short,
          ),
        ],
        allocatedSecondsBySourceLogId: {},
        totalNewWorkSeconds: 7300,
        totalBreaksSeconds: 300,
        totalExistingSeconds: 0,
        totalDaySeconds: 28800,
      );
      expect(
        DayBuilder.validate(
          plan: planWithBreak,
          requirePauses: false,
          allowWorklogOverlaps: true,
        ),
        contains(predicate<String>((error) => error.contains('Перерыв'))),
      );
    });

    test('День свыше 8 часов (например, 9 часов с обедом) валиден и не блокируется', () {
      final now = DateTime.utc(2026, 9, 14, 9, 0);
      final plan9h = DayPlanResult(
        dayStartUtc: now,
        dayEndUtc: now.add(const Duration(hours: 9)), // 09:00 - 18:00 (9 часов)
        segments: [
          Segment(
            id: 'seg-1',
            draftId: 'd-1',
            sourceLogId: 'log-1',
            issueId: '1',
            startUtc: now,
            durationSeconds: 4 * 3600, // 09:00 - 13:00 (4 часа)
          ),
          Segment(
            id: 'seg-2',
            draftId: 'd-1',
            sourceLogId: 'log-2',
            issueId: '2',
            startUtc: now.add(const Duration(hours: 5)), // 14:00 - 18:00 (4 часа)
            durationSeconds: 4 * 3600,
          ),
        ],
        breaks: [
          Break(
            id: 'lunch',
            draftId: 'd-1',
            startUtc: now.add(const Duration(hours: 4)), // 13:00 - 14:00 (обед 1 час)
            durationSeconds: 3600,
            kind: BreakKind.lunch,
          ),
        ],
        allocatedSecondsBySourceLogId: {'log-1': 14400, 'log-2': 14400},
        totalNewWorkSeconds: 8 * 3600,
        totalBreaksSeconds: 3600,
        totalExistingSeconds: 0,
        totalDaySeconds: 9 * 3600, // 32400 сек (9 часов)
      );

      final errors = DayBuilder.validate(plan: plan9h);
      expect(errors, isEmpty);
    });

    test('День свыше 24 часов блокируется валидатором', () {
      final now = DateTime.utc(2026, 9, 14, 9, 0);
      final plan25h = DayPlanResult(
        dayStartUtc: now,
        dayEndUtc: now.add(const Duration(hours: 25)),
        segments: [
          Segment(
            id: 'seg-1',
            draftId: 'd-1',
            sourceLogId: 'log-1',
            issueId: '1',
            startUtc: now,
            durationSeconds: 3600,
          ),
        ],
        breaks: [],
        allocatedSecondsBySourceLogId: {'log-1': 3600},
        totalNewWorkSeconds: 3600,
        totalBreaksSeconds: 0,
        totalExistingSeconds: 0,
        totalDaySeconds: 25 * 3600,
      );

      final errors = DayBuilder.validate(plan: plan25h);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('превышает 24 часа'));
    });
  });
}

