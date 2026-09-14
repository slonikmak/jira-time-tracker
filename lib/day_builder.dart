import 'dart:math';

import 'models.dart';

/// Входные данные для одного лога в сборщике дня.
class DayBuilderLogInput {
  final String sourceLogId;
  final String issueId;
  final String titleSnapshot;
  final String description;
  final int sourceDurationSeconds;
  final bool durationLocked;

  const DayBuilderLogInput({
    required this.sourceLogId,
    required this.issueId,
    required this.titleSnapshot,
    this.description = '',
    required this.sourceDurationSeconds,
    this.durationLocked = false,
  });

  DayBuilderLogInput copyWith({
    String? sourceLogId,
    String? issueId,
    String? titleSnapshot,
    String? description,
    int? sourceDurationSeconds,
    bool? durationLocked,
  }) {
    return DayBuilderLogInput(
      sourceLogId: sourceLogId ?? this.sourceLogId,
      issueId: issueId ?? this.issueId,
      titleSnapshot: titleSnapshot ?? this.titleSnapshot,
      description: description ?? this.description,
      sourceDurationSeconds:
          sourceDurationSeconds ?? this.sourceDurationSeconds,
      durationLocked: durationLocked ?? this.durationLocked,
    );
  }
}

/// Полный набор входных параметров для сборщика дня.
class DayBuilderInput {
  final DateTime localDate;
  final Duration timeZoneOffset;
  final DaySettings settings;
  final List<DayBuilderLogInput> logs;
  final List<ImportedWorklog> existingWorklogs;
  final String draftId;

  const DayBuilderInput({
    required this.localDate,
    required this.timeZoneOffset,
    required this.settings,
    required this.logs,
    this.existingWorklogs = const [],
    this.draftId = '',
  });
}

/// Результат успешной сборки плана дня.
class DayPlanResult {
  final DateTime dayStartUtc;
  final DateTime dayEndUtc;
  final List<Segment> segments;
  final List<Break> breaks;
  final Map<String, int> allocatedSecondsBySourceLogId;
  final int totalNewWorkSeconds;
  final int totalBreaksSeconds;
  final int totalExistingSeconds;
  final int totalDaySeconds;

  const DayPlanResult({
    required this.dayStartUtc,
    required this.dayEndUtc,
    required this.segments,
    required this.breaks,
    required this.allocatedSecondsBySourceLogId,
    required this.totalNewWorkSeconds,
    required this.totalBreaksSeconds,
    required this.totalExistingSeconds,
    required this.totalDaySeconds,
  });
}

/// Ошибка при сборке или валидации дня.
class DayBuilderException implements Exception {
  final String message;
  const DayBuilderException(this.message);

  @override
  String toString() => message;
}

/// Вспомогательный класс для проверки полуоткрытых интервалов.
class _TimeInterval {
  final DateTime start;
  final DateTime end;
  final String type;
  final String id;

  const _TimeInterval({
    required this.start,
    required this.end,
    required this.type,
    required this.id,
  });

  bool overlaps(_TimeInterval other) {
    // Полуоткрытые интервалы [start, end) пересекаются, если
    // max(start, other.start) < min(end, other.end)
    final latestStart = start.isAfter(other.start) ? start : other.start;
    final earliestEnd = end.isBefore(other.end) ? end : other.end;
    return latestStart.isBefore(earliestEnd);
  }
}

/// Чистый алгоритмический модуль сборки и валидации рабочего дня.
class DayBuilder {
  DayBuilder._();

  /// Генерация детерминированного RFC 4122 v4 UUID на основе переданного Random.
  static String generateDeterministicUuid(Random rnd) {
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC 4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Выбор псевдослучайного количества секунд в диапазоне [minSec, maxSec].
  /// Если границы кратны минутам, выбираются целые минуты.
  static int pickSecondsInRange(
    Random rnd,
    int minSec,
    int maxSec, {
    bool preferMinutes = true,
  }) {
    if (minSec >= maxSec) return minSec;
    if (preferMinutes && minSec % 60 == 0 && maxSec % 60 == 0) {
      final minM = minSec ~/ 60;
      final maxM = maxSec ~/ 60;
      final chosenM = minM + rnd.nextInt(maxM - minM + 1);
      return chosenM * 60;
    }
    return minSec + rnd.nextInt(maxSec - minSec + 1);
  }

  /// Разбиение длительности свыше 120 минут на части по 45–120 минут.
  static List<int> splitLargeDuration(int totalSeconds, Random rnd) {
    const int maxChunk = 120 * 60; // 7200 сек
    const int minChunk = 45 * 60; // 2700 сек

    if (totalSeconds <= maxChunk) {
      return [totalSeconds];
    }

    final chunks = <int>[];
    var remaining = totalSeconds;

    while (remaining > maxChunk) {
      final maxPossible = min(maxChunk, remaining - minChunk);
      int chunk;
      if (maxPossible >= minChunk) {
        // Выбираем в минутах, если кратно
        chunk = pickSecondsInRange(rnd, minChunk, maxPossible);
      } else {
        chunk = remaining ~/ 2;
      }
      chunks.add(chunk);
      remaining -= chunk;
    }

    if (remaining > 0) {
      chunks.add(remaining);
    }

    return chunks;
  }

  /// Построение плана дня по входным данным и seed.
  static DayPlanResult build({
    required DayBuilderInput input,
    required int seed,
  }) {
    final logs = input.logs;
    if (logs.isEmpty) {
      throw const DayBuilderException(
        'Не выбрано ни одного лога для сборки дня.',
      );
    }

    for (final log in logs) {
      if (log.sourceDurationSeconds <= 0) {
        throw const DayBuilderException(
          'Лог содержит нулевую или отрицательную длительность.',
        );
      }
    }

    final settings = input.settings;
    if (settings.startMinutesMin > settings.startMinutesMax ||
        settings.totalDurationSecondsMin > settings.totalDurationSecondsMax ||
        settings.totalDurationSecondsMax > 8 * 3600 ||
        settings.lunchStartMinutesMin > settings.lunchStartMinutesMax ||
        settings.lunchDurationSecondsMin > settings.lunchDurationSecondsMax ||
        settings.shortBreakCountMin > settings.shortBreakCountMax ||
        settings.shortBreakDurationSecondsMin >
            settings.shortBreakDurationSecondsMax) {
      throw const DayBuilderException('Некорректные настройки рабочего дня.');
    }

    final rnd = Random(seed);

    // Сортировка существующих записей Jira
    final existingSorted = List<ImportedWorklog>.from(input.existingWorklogs)
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));

    // Проверка пересечений среди существующих записей
    for (var i = 0; i < existingSorted.length - 1; i++) {
      if (existingSorted[i].endUtc.isAfter(existingSorted[i + 1].startUtc)) {
        throw const DayBuilderException(
          'Обнаружен конфликт: существующие записи в Jira пересекаются друг с другом.',
        );
      }
    }

    final totalExistingSeconds = existingSorted.fold<int>(
      0,
      (sum, e) => sum + e.durationSeconds,
    );

    if (totalExistingSeconds >= 8 * 3600) {
      throw const DayBuilderException(
        'Существующие записи в Jira уже занимают 8 или более часов.',
      );
    }

    // Вычисление локальной полуночи в UTC
    final localMidnightUtc = DateTime.utc(
      input.localDate.year,
      input.localDate.month,
      input.localDate.day,
    ).subtract(input.timeZoneOffset);

    // Выбор номинального начала дня
    final startOffsetMin = settings.startMinutesMax > settings.startMinutesMin
        ? rnd.nextInt(settings.startMinutesMax - settings.startMinutesMin + 1)
        : 0;
    final nominalStartMinutes = settings.startMinutesMin + startOffsetMin;
    var dayStartUtc = localMidnightUtc.add(
      Duration(minutes: nominalStartMinutes),
    );

    // Выбор номинальной продолжительности дня
    var nominalDurationSeconds = pickSecondsInRange(
      rnd,
      settings.totalDurationSecondsMin,
      settings.totalDurationSecondsMax,
    );
    if (nominalDurationSeconds > 8 * 3600) {
      nominalDurationSeconds = 8 * 3600;
    }
    var dayEndUtc = dayStartUtc.add(Duration(seconds: nominalDurationSeconds));

    // Корректировка окна дня под существующие записи Jira
    if (existingSorted.isNotEmpty) {
      final earliestExisting = existingSorted.first.startUtc;
      final latestExisting = existingSorted.last.endUtc;
      final existingSpanSeconds = latestExisting
          .difference(earliestExisting)
          .inSeconds;

      if (existingSpanSeconds > 8 * 3600) {
        throw const DayBuilderException(
          'Существующие записи в Jira выходят за допустимое 8-часовое окно рабочего дня.',
        );
      }

      if (dayStartUtc.isAfter(earliestExisting)) {
        dayStartUtc = earliestExisting;
      }
      if (dayEndUtc.isBefore(latestExisting)) {
        dayEndUtc = latestExisting;
      }

      var currentSpan = dayEndUtc.difference(dayStartUtc).inSeconds;
      if (currentSpan > 8 * 3600) {
        throw const DayBuilderException(
          'С учётом существующих записей день превышает лимит в 8 часов.',
        );
      }

      // Если текущий span меньше номинального, попробуем расширить, не превышая 8 часов
      if (currentSpan < nominalDurationSeconds) {
        final toAdd = nominalDurationSeconds - currentSpan;
        dayEndUtc = dayEndUtc.add(Duration(seconds: toAdd));
        if (dayEndUtc.difference(dayStartUtc).inSeconds > 8 * 3600) {
          dayEndUtc = dayStartUtc.add(const Duration(seconds: 8 * 3600));
        }
      }
    }

    final totalDaySeconds = dayEndUtc.difference(dayStartUtc).inSeconds;

    // Размещение пауз (обед + короткие перерывы)
    final breaks = _placeBreaks(
      dayStartUtc: dayStartUtc,
      dayEndUtc: dayEndUtc,
      localMidnightUtc: localMidnightUtc,
      settings: settings,
      existingWorklogs: existingSorted,
      draftId: input.draftId,
      rnd: rnd,
    );

    final totalBreaksSeconds = breaks.fold<int>(
      0,
      (sum, b) => sum + b.durationSeconds,
    );

    // Бюджет для новых сегментов
    final newWorkBudget =
        totalDaySeconds - totalBreaksSeconds - totalExistingSeconds;
    if (newWorkBudget <= 0) {
      throw const DayBuilderException(
        'Бюджет рабочего времени исчерпан существующими записями и перерывами.',
      );
    }

    // Распределение бюджета между логами
    final lockedLogs = logs.where((l) => l.durationLocked).toList();
    final unlockedLogs = logs.where((l) => !l.durationLocked).toList();

    final lockedSum = lockedLogs.fold<int>(
      0,
      (sum, l) => sum + l.sourceDurationSeconds,
    );

    if (lockedSum > newWorkBudget) {
      final reqH = lockedSum ~/ 3600;
      final reqM = (lockedSum % 3600) ~/ 60;
      final availH = newWorkBudget ~/ 3600;
      final availM = (newWorkBudget % 3600) ~/ 60;
      throw DayBuilderException(
        'Фиксированные логи требуют $reqH ч $reqM мин, а доступно только $availH ч $availM мин.',
      );
    }

    final allocated = <String, int>{};

    if (unlockedLogs.isEmpty) {
      if (lockedSum != newWorkBudget) {
        final reqH = lockedSum ~/ 3600;
        final reqM = (lockedSum % 3600) ~/ 60;
        final availH = newWorkBudget ~/ 3600;
        final availM = (newWorkBudget % 3600) ~/ 60;
        throw DayBuilderException(
          'Все логи зафиксированы ($reqH ч $reqM мин), но бюджет составляет $availH ч $availM мин. Разблокируйте хотя бы один лог.',
        );
      }
      for (final log in lockedLogs) {
        allocated[log.sourceLogId] = log.sourceDurationSeconds;
      }
    } else {
      for (final log in lockedLogs) {
        allocated[log.sourceLogId] = log.sourceDurationSeconds;
      }

      final remainingBudget = newWorkBudget - lockedSum;
      if (remainingBudget < unlockedLogs.length) {
        throw const DayBuilderException(
          'Недостаточно свободного времени для распределения между незафиксированными задачами.',
        );
      }

      final totalUnlockedSource = unlockedLogs.fold<int>(
        0,
        (sum, l) => sum + l.sourceDurationSeconds,
      );

      var currentAllocatedSum = 0;
      for (final log in unlockedLogs) {
        final raw = totalUnlockedSource > 0
            ? (log.sourceDurationSeconds * remainingBudget) ~/
                  totalUnlockedSource
            : remainingBudget ~/ unlockedLogs.length;
        final val = max(1, raw);
        allocated[log.sourceLogId] = val;
        currentAllocatedSum += val;
      }

      var diff = remainingBudget - currentAllocatedSum;
      final sortedUnlocked = List<DayBuilderLogInput>.from(unlockedLogs)
        ..sort(
          (a, b) => b.sourceDurationSeconds.compareTo(a.sourceDurationSeconds),
        );

      if (diff > 0) {
        var idx = 0;
        while (diff > 0) {
          final logId = sortedUnlocked[idx % sortedUnlocked.length].sourceLogId;
          allocated[logId] = (allocated[logId] ?? 0) + 1;
          diff--;
          idx++;
        }
      } else if (diff < 0) {
        var idx = 0;
        while (diff < 0) {
          final logId = sortedUnlocked[idx % sortedUnlocked.length].sourceLogId;
          if ((allocated[logId] ?? 0) > 1) {
            allocated[logId] = allocated[logId]! - 1;
            diff++;
          }
          idx++;
        }
      }
    }

    // Разбиение больших логов (> 120 мин) на части
    final logChunks = <_LogChunk>[];
    for (final log in logs) {
      final allocatedSec = allocated[log.sourceLogId]!;
      final parts = splitLargeDuration(allocatedSec, rnd);
      for (final part in parts) {
        logChunks.add(
          _LogChunk(
            sourceLogId: log.sourceLogId,
            issueId: log.issueId,
            description: log.description,
            durationSeconds: part,
          ),
        );
      }
    }

    // Чередование частей разных логов по кругу
    final reorderedChunks = _interleaveChunks(logChunks, logs);

    // Определение свободных интервалов в дне
    final occupied = <_TimeInterval>[];
    for (final b in breaks) {
      occupied.add(
        _TimeInterval(
          start: b.startUtc,
          end: b.endUtc,
          type: 'Перерыв',
          id: b.id,
        ),
      );
    }
    for (final ew in existingSorted) {
      occupied.add(
        _TimeInterval(
          start: ew.startUtc,
          end: ew.endUtc,
          type: 'Существующий worklog',
          id: ew.id,
        ),
      );
    }
    occupied.sort((a, b) => a.start.compareTo(b.start));

    final freeIntervals = <_FreeInterval>[];
    var currentCursor = dayStartUtc;
    for (final occ in occupied) {
      if (occ.start.isAfter(currentCursor)) {
        freeIntervals.add(
          _FreeInterval(startUtc: currentCursor, endUtc: occ.start),
        );
      }
      if (occ.end.isAfter(currentCursor)) {
        currentCursor = occ.end;
      }
    }
    if (currentCursor.isBefore(dayEndUtc)) {
      freeIntervals.add(
        _FreeInterval(startUtc: currentCursor, endUtc: dayEndUtc),
      );
    }

    // Заполнение свободных промежутков частями логов
    final segments = <Segment>[];
    var currentIntervalIdx = 0;
    var currentOffsetInInterval = 0;

    for (final chunk in reorderedChunks) {
      var chunkRemaining = chunk.durationSeconds;

      while (chunkRemaining > 0) {
        if (currentIntervalIdx >= freeIntervals.length) {
          throw const DayBuilderException(
            'Ошибка компоновки: закончились свободные промежутки дня.',
          );
        }

        final interval = freeIntervals[currentIntervalIdx];
        final availableInInterval =
            interval.durationSeconds - currentOffsetInInterval;

        final sliceDuration = min(chunkRemaining, availableInInterval);
        final sliceStart = interval.startUtc.add(
          Duration(seconds: currentOffsetInInterval),
        );

        segments.add(
          Segment(
            id: generateDeterministicUuid(rnd),
            draftId: input.draftId,
            sourceLogId: chunk.sourceLogId,
            issueId: chunk.issueId,
            startUtc: sliceStart,
            durationSeconds: sliceDuration,
            description: chunk.description,
            sendState: SendState.pending,
          ),
        );

        currentOffsetInInterval += sliceDuration;
        chunkRemaining -= sliceDuration;

        if (currentOffsetInInterval >= interval.durationSeconds) {
          currentIntervalIdx++;
          currentOffsetInInterval = 0;
        }
      }
    }

    final totalNewWorkSeconds = segments.fold<int>(
      0,
      (sum, s) => sum + s.durationSeconds,
    );

    final plan = DayPlanResult(
      dayStartUtc: dayStartUtc,
      dayEndUtc: dayEndUtc,
      segments: segments,
      breaks: breaks,
      allocatedSecondsBySourceLogId: allocated,
      totalNewWorkSeconds: totalNewWorkSeconds,
      totalBreaksSeconds: totalBreaksSeconds,
      totalExistingSeconds: totalExistingSeconds,
      totalDaySeconds: totalDaySeconds,
    );

    // Валидация построенного плана
    final errors = validate(plan: plan, existingWorklogs: existingSorted);
    if (errors.isNotEmpty) {
      throw DayBuilderException(errors.join('\n'));
    }

    return plan;
  }

  /// Проверка полуоткрытых интервалов [start, end) и инвариантов расписания.
  static List<String> validate({
    required DayPlanResult plan,
    List<ImportedWorklog> existingWorklogs = const [],
  }) {
    final errors = <String>[];

    if (plan.totalDaySeconds > 8 * 3600) {
      errors.add(
        'Общая продолжительность дня (${plan.totalDaySeconds} сек) превышает 8 часов (28 800 сек).',
      );
    }

    for (final s in plan.segments) {
      if (s.durationSeconds <= 0) {
        errors.add('Сегмент ${s.id} имеет неположительную длительность.');
      }
      if (s.startUtc.isBefore(plan.dayStartUtc) ||
          s.endUtc.isAfter(plan.dayEndUtc)) {
        errors.add('Сегмент ${s.id} выходит за границы рабочего дня.');
      }
    }

    for (final b in plan.breaks) {
      if (b.durationSeconds <= 0) {
        errors.add('Перерыв ${b.id} имеет неположительную длительность.');
      }
      if (b.startUtc.isBefore(plan.dayStartUtc) ||
          b.endUtc.isAfter(plan.dayEndUtc)) {
        errors.add('Перерыв ${b.id} выходит за границы рабочего дня.');
      }
    }

    for (final ew in existingWorklogs) {
      if (ew.durationSeconds <= 0) {
        errors.add(
          'Существующая запись ${ew.id} имеет неположительную длительность.',
        );
      }
      if (ew.startUtc.isBefore(plan.dayStartUtc) ||
          ew.endUtc.isAfter(plan.dayEndUtc)) {
        errors.add(
          'Существующая запись ${ew.id} выходит за границы рабочего дня.',
        );
      }
    }

    final intervals = <_TimeInterval>[];
    for (final s in plan.segments) {
      intervals.add(
        _TimeInterval(
          start: s.startUtc,
          end: s.endUtc,
          type: 'Сегмент',
          id: s.id,
        ),
      );
    }
    for (final b in plan.breaks) {
      intervals.add(
        _TimeInterval(
          start: b.startUtc,
          end: b.endUtc,
          type: 'Перерыв',
          id: b.id,
        ),
      );
    }
    for (final ew in existingWorklogs) {
      intervals.add(
        _TimeInterval(
          start: ew.startUtc,
          end: ew.endUtc,
          type: 'Существующий worklog',
          id: ew.id,
        ),
      );
    }

    intervals.sort((a, b) => a.start.compareTo(b.start));

    for (var i = 0; i < intervals.length - 1; i++) {
      final a = intervals[i];
      final b = intervals[i + 1];

      if (a.overlaps(b)) {
        errors.add(
          'Обнаружено пересечение: ${a.type} (${a.start} - ${a.end}) и ${b.type} (${b.start} - ${b.end}).',
        );
      }

      if (a.type == 'Перерыв' &&
          b.type == 'Перерыв' &&
          a.end.isAtSameMomentAs(b.start)) {
        errors.add(
          'Перерывы не должны следовать подряд без рабочего интервала между ними.',
        );
      }
    }

    return errors;
  }

  /// Размещение обеденного перерыва и коротких пауз.
  static List<Break> _placeBreaks({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required DateTime localMidnightUtc,
    required DaySettings settings,
    required List<ImportedWorklog> existingWorklogs,
    required String draftId,
    required Random rnd,
  }) {
    final breaks = <Break>[];

    // 1. Размещение обеда
    final lunchDuration = pickSecondsInRange(
      rnd,
      settings.lunchDurationSecondsMin,
      settings.lunchDurationSecondsMax,
    );

    final earliestLunch = localMidnightUtc.add(
      Duration(minutes: settings.lunchStartMinutesMin),
    );
    final latestLunch = localMidnightUtc.add(
      Duration(minutes: settings.lunchStartMinutesMax),
    );

    // Границы поиска обеда
    var minLunchStart = earliestLunch.isBefore(dayStartUtc)
        ? dayStartUtc
        : earliestLunch;
    var maxLunchStart =
        latestLunch.isAfter(
          dayEndUtc.subtract(Duration(seconds: lunchDuration)),
        )
        ? dayEndUtc.subtract(Duration(seconds: lunchDuration))
        : latestLunch;

    if (maxLunchStart.isBefore(minLunchStart)) {
      minLunchStart = dayStartUtc;
      maxLunchStart = dayEndUtc.subtract(Duration(seconds: lunchDuration));
    }

    DateTime? chosenLunchStart;

    if (!maxLunchStart.isBefore(minLunchStart)) {
      final spanMinutes =
          maxLunchStart.difference(minLunchStart).inSeconds ~/ 60;
      final attempts = 20;
      for (var i = 0; i < attempts; i++) {
        final offsetMinutes = spanMinutes > 0
            ? rnd.nextInt(spanMinutes + 1)
            : 0;
        final candidate = minLunchStart.add(Duration(minutes: offsetMinutes));
        final candidateEnd = candidate.add(Duration(seconds: lunchDuration));

        final candidateInterval = _TimeInterval(
          start: candidate,
          end: candidateEnd,
          type: 'Обед',
          id: 'candidate-lunch',
        );

        final collides = existingWorklogs.any(
          (ew) => candidateInterval.overlaps(
            _TimeInterval(
              start: ew.startUtc,
              end: ew.endUtc,
              type: 'Worklog',
              id: ew.id,
            ),
          ),
        );

        if (!collides) {
          chosenLunchStart = candidate;
          break;
        }
      }
    }

    // Если случайный подбор не нашёл слот, ищем линейно с шагом 5 минут
    if (chosenLunchStart == null && !maxLunchStart.isBefore(minLunchStart)) {
      var candidate = minLunchStart;
      while (!candidate.isAfter(maxLunchStart)) {
        final candidateEnd = candidate.add(Duration(seconds: lunchDuration));
        final candidateInterval = _TimeInterval(
          start: candidate,
          end: candidateEnd,
          type: 'Обед',
          id: 'candidate-lunch',
        );
        final collides = existingWorklogs.any(
          (ew) => candidateInterval.overlaps(
            _TimeInterval(
              start: ew.startUtc,
              end: ew.endUtc,
              type: 'Worklog',
              id: ew.id,
            ),
          ),
        );
        if (!collides) {
          chosenLunchStart = candidate;
          break;
        }
        candidate = candidate.add(const Duration(minutes: 5));
      }
    }

    // Если всё ещё нет, ищем любой свободный промежуток дня >= lunchDuration
    if (chosenLunchStart == null) {
      var cursor = dayStartUtc;
      for (final ew in existingWorklogs) {
        if (ew.startUtc.difference(cursor).inSeconds >= lunchDuration) {
          chosenLunchStart = cursor;
          break;
        }
        if (ew.endUtc.isAfter(cursor)) {
          cursor = ew.endUtc;
        }
      }
      if (chosenLunchStart == null &&
          dayEndUtc.difference(cursor).inSeconds >= lunchDuration) {
        chosenLunchStart = cursor;
      }
    }

    if (chosenLunchStart == null) {
      throw const DayBuilderException(
        'Невозможно разместить обеденный перерыв: нет свободного времени достаточной длины.',
      );
    }

    final lunchBreak = Break(
      id: generateDeterministicUuid(rnd),
      draftId: draftId,
      startUtc: chosenLunchStart,
      durationSeconds: lunchDuration,
      kind: BreakKind.lunch,
    );
    breaks.add(lunchBreak);

    // 2. Размещение коротких пауз
    final breakCount = settings.shortBreakCountMax > settings.shortBreakCountMin
        ? settings.shortBreakCountMin +
              rnd.nextInt(
                settings.shortBreakCountMax - settings.shortBreakCountMin + 1,
              )
        : settings.shortBreakCountMin;

    if (breakCount > 0) {
      final morningBreaksCount = breakCount ~/ 2;
      final afternoonBreaksCount = breakCount - morningBreaksCount;

      _placeShortBreaksInSpan(
        spanStart: dayStartUtc,
        spanEnd: lunchBreak.startUtc,
        count: morningBreaksCount,
        settings: settings,
        existingWorklogs: existingWorklogs,
        breaks: breaks,
        draftId: draftId,
        rnd: rnd,
      );

      _placeShortBreaksInSpan(
        spanStart: lunchBreak.endUtc,
        spanEnd: dayEndUtc,
        count: afternoonBreaksCount,
        settings: settings,
        existingWorklogs: existingWorklogs,
        breaks: breaks,
        draftId: draftId,
        rnd: rnd,
      );
    }

    breaks.sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return breaks;
  }

  /// Размещение коротких пауз внутри половины дня (утро или день).
  static void _placeShortBreaksInSpan({
    required DateTime spanStart,
    required DateTime spanEnd,
    required int count,
    required DaySettings settings,
    required List<ImportedWorklog> existingWorklogs,
    required List<Break> breaks,
    required String draftId,
    required Random rnd,
  }) {
    if (count <= 0) return;

    final spanDuration = spanEnd.difference(spanStart).inSeconds;
    if (spanDuration < 600) return; // Слишком короткий интервал

    for (var i = 0; i < count; i++) {
      final breakDuration = pickSecondsInRange(
        rnd,
        settings.shortBreakDurationSecondsMin,
        settings.shortBreakDurationSecondsMax,
      );

      // Желаемый центр паузы внутри span
      final slotWidth = spanDuration ~/ (count + 1);
      final nominalCenterOffset = slotWidth * (i + 1);
      final jitterSeconds = (slotWidth ~/ 4 > 60)
          ? rnd.nextInt(slotWidth ~/ 2) - slotWidth ~/ 4
          : 0;
      final targetStart = spanStart.add(
        Duration(seconds: nominalCenterOffset + jitterSeconds),
      );

      // Ищем свободное место рядом с targetStart
      final placedStart = _findFreeBreakSlot(
        targetStart: targetStart,
        durationSeconds: breakDuration,
        minBound: spanStart.add(const Duration(minutes: 5)),
        maxBound: spanEnd.subtract(Duration(seconds: breakDuration + 5 * 60)),
        existingWorklogs: existingWorklogs,
        existingBreaks: breaks,
      );

      if (placedStart != null) {
        breaks.add(
          Break(
            id: generateDeterministicUuid(rnd),
            draftId: draftId,
            startUtc: placedStart,
            durationSeconds: breakDuration,
            kind: BreakKind.short,
          ),
        );
      }
    }
  }

  /// Поиск свободного окна для короткой паузы с отступом от других перерывов и записей.
  static DateTime? _findFreeBreakSlot({
    required DateTime targetStart,
    required int durationSeconds,
    required DateTime minBound,
    required DateTime maxBound,
    required List<ImportedWorklog> existingWorklogs,
    required List<Break> existingBreaks,
  }) {
    if (maxBound.isBefore(minBound)) return null;

    final minGap = const Duration(minutes: 3);

    bool isValid(DateTime candidate) {
      final cEnd = candidate.add(Duration(seconds: durationSeconds));
      final cIntervalWithGaps = _TimeInterval(
        start: candidate.subtract(minGap),
        end: cEnd.add(minGap),
        type: 'Кандидат',
        id: 'candidate',
      );

      for (final ew in existingWorklogs) {
        if (cIntervalWithGaps.overlaps(
          _TimeInterval(
            start: ew.startUtc,
            end: ew.endUtc,
            type: 'Worklog',
            id: ew.id,
          ),
        )) {
          return false;
        }
      }
      for (final b in existingBreaks) {
        if (cIntervalWithGaps.overlaps(
          _TimeInterval(
            start: b.startUtc,
            end: b.endUtc,
            type: 'Break',
            id: b.id,
          ),
        )) {
          return false;
        }
      }
      return true;
    }

    var clampedTarget = targetStart;
    if (clampedTarget.isBefore(minBound)) clampedTarget = minBound;
    if (clampedTarget.isAfter(maxBound)) clampedTarget = maxBound;

    if (isValid(clampedTarget)) return clampedTarget;

    // Смещение влево и вправо с шагом 1 минута
    for (var delta = 1; delta <= 60; delta++) {
      final earlier = clampedTarget.subtract(Duration(minutes: delta));
      if (!earlier.isBefore(minBound) && isValid(earlier)) {
        return earlier;
      }
      final later = clampedTarget.add(Duration(minutes: delta));
      if (!later.isAfter(maxBound) && isValid(later)) {
        return later;
      }
    }

    return null;
  }

  /// Чередование частей логов по кругу (Round-Robin).
  static List<_LogChunk> _interleaveChunks(
    List<_LogChunk> chunks,
    List<DayBuilderLogInput> originalLogs,
  ) {
    final chunksBySource = <String, List<_LogChunk>>{};
    for (final c in chunks) {
      chunksBySource.putIfAbsent(c.sourceLogId, () => []).add(c);
    }

    final result = <_LogChunk>[];
    var hasMore = true;
    var round = 0;

    while (hasMore) {
      hasMore = false;
      for (final log in originalLogs) {
        final list = chunksBySource[log.sourceLogId];
        if (list != null && round < list.length) {
          result.add(list[round]);
          hasMore = true;
        }
      }
      round++;
    }

    return result;
  }
}

class _LogChunk {
  final String sourceLogId;
  final String issueId;
  final String description;
  final int durationSeconds;

  const _LogChunk({
    required this.sourceLogId,
    required this.issueId,
    required this.description,
    required this.durationSeconds,
  });
}

class _FreeInterval {
  final DateTime startUtc;
  final DateTime endUtc;

  const _FreeInterval({required this.startUtc, required this.endUtc});

  int get durationSeconds => endUtc.difference(startUtc).inSeconds;
}
