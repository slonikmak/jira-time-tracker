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

  final DateTime? originalStartUtc;
  final DateTime? originalEndUtc;
  final bool isFixed;
  final String? fixedStartTime;
  final DateTime? fixedStartUtc;

  const DayBuilderLogInput({
    required this.sourceLogId,
    required this.issueId,
    required this.titleSnapshot,
    this.description = '',
    required this.sourceDurationSeconds,
    this.durationLocked = false,
    this.originalStartUtc,
    this.originalEndUtc,
    this.isFixed = false,
    this.fixedStartTime,
    this.fixedStartUtc,
  });

  DayBuilderLogInput copyWith({
    String? sourceLogId,
    String? issueId,
    String? titleSnapshot,
    String? description,
    int? sourceDurationSeconds,
    bool? durationLocked,
    DateTime? originalStartUtc,
    DateTime? originalEndUtc,
    bool? isFixed,
    String? fixedStartTime,
    DateTime? fixedStartUtc,
  }) {
    return DayBuilderLogInput(
      sourceLogId: sourceLogId ?? this.sourceLogId,
      issueId: issueId ?? this.issueId,
      titleSnapshot: titleSnapshot ?? this.titleSnapshot,
      description: description ?? this.description,
      sourceDurationSeconds:
          sourceDurationSeconds ?? this.sourceDurationSeconds,
      durationLocked: durationLocked ?? this.durationLocked,
      originalStartUtc: originalStartUtc ?? this.originalStartUtc,
      originalEndUtc: originalEndUtc ?? this.originalEndUtc,
      isFixed: isFixed ?? this.isFixed,
      fixedStartTime: fixedStartTime ?? this.fixedStartTime,
      fixedStartUtc: fixedStartUtc ?? this.fixedStartUtc,
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

  /// Разбиение длительности свыше 60 минут на части по 30–60 минут.
  static List<int> splitLargeDuration(int totalSeconds, Random rnd) {
    const int maxChunk = 60 * 60; // 3600 сек
    const int minChunk = 30 * 60; // 1800 сек

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

  /// Построение плана дня «как записано» (без изменения длительностей,
  /// без искусственных пауз, с каскадным сдвигом при пересечениях).
  static DayPlanResult buildAsRecorded({
    required DayBuilderInput input,
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

    // Вычисление локальной полуночи в UTC
    final localMidnightUtc = DateTime.utc(
      input.localDate.year,
      input.localDate.month,
      input.localDate.day,
    ).subtract(input.timeZoneOffset);

    final localDayEndUtc = localMidnightUtc.add(const Duration(days: 1));

    // Подготовка занятых интервалов (начинаем с существующих записей Jira)
    final occupied = <_TimeInterval>[];
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

    // Проекция исходного времени каждого лога на целевую дату в локальном времени
    final candidateLogs = <_CandidateLog>[];
    for (final log in logs) {
      DateTime projStart;
      if (log.originalStartUtc != null) {
        final origLocal = log.originalStartUtc!.add(input.timeZoneOffset);
        projStart = DateTime.utc(
          input.localDate.year,
          input.localDate.month,
          input.localDate.day,
          origLocal.hour,
          origLocal.minute,
          origLocal.second,
          origLocal.millisecond,
        ).subtract(input.timeZoneOffset);
      } else {
        projStart = localMidnightUtc.add(
          Duration(minutes: input.settings.startMinutesMin),
        );
      }
      candidateLogs.add(_CandidateLog(log: log, projectedStartUtc: projStart));
    }

    // Сортировка по времени начала. Если равны — сохраняем исходный порядок в списке
    candidateLogs.sort(
      (a, b) => a.projectedStartUtc.compareTo(b.projectedStartUtc),
    );

    final segments = <Segment>[];
    final allocated = <String, int>{};
    final rnd = Random(
      input.draftId.hashCode ^ input.localDate.millisecondsSinceEpoch,
    );

    for (final candidate in candidateLogs) {
      final log = candidate.log;
      var curStart = candidate.projectedStartUtc;
      var curEnd = curStart.add(Duration(seconds: log.sourceDurationSeconds));

      // Каскадный сдвиг при пересечении с уже занятыми интервалами
      bool placed = false;
      while (!placed) {
        _TimeInterval? conflict;
        for (final occ in occupied) {
          final candInterval = _TimeInterval(
            start: curStart,
            end: curEnd,
            type: 'Сегмент',
            id: 'temp',
          );
          if (candInterval.overlaps(occ)) {
            conflict = occ;
            break;
          }
        }

        if (conflict != null) {
          curStart = conflict.end;
          curEnd = curStart.add(Duration(seconds: log.sourceDurationSeconds));
        } else {
          placed = true;
        }
      }

      if (curEnd.isAfter(localDayEndUtc)) {
        throw const DayBuilderException(
          'Задачи не помещаются в выбранные сутки (до 23:59:59). Уменьшите длительность или перенесите часть задач на другой день.',
        );
      }

      occupied.add(
        _TimeInterval(
          start: curStart,
          end: curEnd,
          type: 'Сегмент',
          id: log.sourceLogId,
        ),
      );
      occupied.sort((a, b) => a.start.compareTo(b.start));

      segments.add(
        Segment(
          id: generateDeterministicUuid(rnd),
          draftId: input.draftId,
          sourceLogId: log.sourceLogId,
          issueId: log.issueId,
          startUtc: curStart,
          durationSeconds: log.sourceDurationSeconds,
          description: log.description,
          sendState: SendState.pending,
        ),
      );
      allocated[log.sourceLogId] =
          (allocated[log.sourceLogId] ?? 0) + log.sourceDurationSeconds;
    }

    DateTime dayStartUtc = segments.first.startUtc;
    DateTime dayEndUtc = segments.first.endUtc;

    for (final s in segments) {
      if (s.startUtc.isBefore(dayStartUtc)) dayStartUtc = s.startUtc;
      if (s.endUtc.isAfter(dayEndUtc)) dayEndUtc = s.endUtc;
    }
    for (final ew in existingSorted) {
      if (ew.startUtc.isBefore(dayStartUtc)) dayStartUtc = ew.startUtc;
      if (ew.endUtc.isAfter(dayEndUtc)) dayEndUtc = ew.endUtc;
    }

    final totalNewWorkSeconds = segments.fold<int>(
      0,
      (sum, s) => sum + s.durationSeconds,
    );

    final plan = DayPlanResult(
      dayStartUtc: dayStartUtc,
      dayEndUtc: dayEndUtc,
      segments: segments,
      breaks: const [],
      allocatedSecondsBySourceLogId: allocated,
      totalNewWorkSeconds: totalNewWorkSeconds,
      totalBreaksSeconds: 0,
      totalExistingSeconds: totalExistingSeconds,
      totalDaySeconds: dayEndUtc.difference(dayStartUtc).inSeconds,
    );

    final errors = validate(
      plan: plan,
      existingWorklogs: existingSorted,
      requirePauses: false,
    );
    if (errors.isNotEmpty) {
      throw DayBuilderException(errors.join('\n'));
    }

    return plan;
  }

  /// Вычисление динамических временных зазоров (Timeline Gaps) между рабочими интервалами и границами дня.
  static List<Break> computeTimelineGaps({
    required DateTime dayStartUtc,
    required DateTime dayEndUtc,
    required List<Segment> segments,
    required List<ImportedWorklog> existingWorklogs,
    List<Break>? plannedBreaks,
    String draftId = '',
  }) {
    final intervals = <({DateTime start, DateTime end})>[];
    for (final s in segments) {
      if (s.durationSeconds > 0) {
        intervals.add((start: s.startUtc, end: s.endUtc));
      }
    }
    for (final ew in existingWorklogs) {
      if (ew.durationSeconds > 0) {
        intervals.add((start: ew.startUtc, end: ew.endUtc));
      }
    }

    if (intervals.isEmpty) {
      if (dayEndUtc.isAfter(dayStartUtc)) {
        final dur = dayEndUtc.difference(dayStartUtc).inSeconds;
        return [
          Break(
            id: 'gap-0',
            draftId: draftId,
            startUtc: dayStartUtc,
            durationSeconds: dur,
            kind: _determineBreakKind(dayStartUtc, dayEndUtc, dur, plannedBreaks),
          ),
        ];
      }
      return const [];
    }

    intervals.sort((a, b) => a.start.compareTo(b.start));

    // Объединяем накладывающиеся или смежные интервалы занятости
    final merged = <({DateTime start, DateTime end})>[];
    var currentMerged = intervals.first;

    for (var i = 1; i < intervals.length; i++) {
      final item = intervals[i];
      if (item.start.isBefore(currentMerged.end)) {
        if (item.end.isAfter(currentMerged.end)) {
          currentMerged = (start: currentMerged.start, end: item.end);
        }
      } else {
        merged.add(currentMerged);
        currentMerged = item;
      }
    }
    merged.add(currentMerged);

    final gaps = <Break>[];
    int gapCounter = 0;

    // Зазор перед первой задачей дня
    if (merged.first.start.isAfter(dayStartUtc)) {
      final gapDur = merged.first.start.difference(dayStartUtc).inSeconds;
      if (gapDur > 0) {
        gaps.add(Break(
          id: 'gap-${gapCounter++}',
          draftId: draftId,
          startUtc: dayStartUtc,
          durationSeconds: gapDur,
          kind: _determineBreakKind(dayStartUtc, merged.first.start, gapDur, plannedBreaks),
        ));
      }
    }

    // Зазоры между задачами
    for (var i = 0; i < merged.length - 1; i++) {
      final currentEnd = merged[i].end;
      final nextStart = merged[i + 1].start;
      if (nextStart.isAfter(currentEnd)) {
        final gapDur = nextStart.difference(currentEnd).inSeconds;
        if (gapDur > 0) {
          gaps.add(Break(
            id: 'gap-${gapCounter++}',
            draftId: draftId,
            startUtc: currentEnd,
            durationSeconds: gapDur,
            kind: _determineBreakKind(currentEnd, nextStart, gapDur, plannedBreaks),
          ));
        }
      }
    }

    // Зазор после последней задачи дня
    if (dayEndUtc.isAfter(merged.last.end)) {
      final gapDur = dayEndUtc.difference(merged.last.end).inSeconds;
      if (gapDur > 0) {
        gaps.add(Break(
          id: 'gap-${gapCounter++}',
          draftId: draftId,
          startUtc: merged.last.end,
          durationSeconds: gapDur,
          kind: _determineBreakKind(merged.last.end, dayEndUtc, gapDur, plannedBreaks),
        ));
      }
    }

    return gaps;
  }

  static BreakKind _determineBreakKind(
    DateTime startUtc,
    DateTime endUtc,
    int durationSeconds,
    List<Break>? plannedBreaks,
  ) {
    return BreakKind.short;
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
        settings.totalDurationSecondsMax > 24 * 3600 ||
        settings.lunchStartMinutesMin > settings.lunchStartMinutesMax ||
        settings.lunchDurationSecondsMin > settings.lunchDurationSecondsMax ||
        settings.shortBreakCountMin > settings.shortBreakCountMax ||
        settings.shortBreakDurationSecondsMin <= 0 ||
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

    if (totalExistingSeconds >= settings.totalDurationSecondsMax) {
      throw DayBuilderException(
        'Существующие записи в Jira уже занимают ${settings.totalDurationSecondsMax ~/ 3600} или более часов.',
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

    final totalSourceSeconds = logs.fold<int>(
      0,
      (sum, l) => sum + l.sourceDurationSeconds,
    );

    final isShortDay = (totalSourceSeconds + totalExistingSeconds) < 6 * 3600 &&
        settings.totalDurationSecondsMin != settings.totalDurationSecondsMax;
    final needsLunch = !isShortDay ||
        (totalSourceSeconds + totalExistingSeconds) >= 4 * 3600;

    // Выбор номинальной продолжительности дня
    var nominalDurationSeconds = pickSecondsInRange(
      rnd,
      settings.totalDurationSecondsMin,
      settings.totalDurationSecondsMax,
    );

    final estimatedBreaks = needsLunch ? 3000 : 600;
    if (nominalDurationSeconds > 24 * 3600) {
      nominalDurationSeconds = 24 * 3600;
    }

    if (isShortDay &&
        settings.totalDurationSecondsMin != settings.totalDurationSecondsMax) {
      nominalDurationSeconds = min(
        nominalDurationSeconds,
        totalSourceSeconds + totalExistingSeconds + estimatedBreaks + 1800,
      );
    }
    var dayEndUtc = dayStartUtc.add(Duration(seconds: nominalDurationSeconds));

    // Корректировка окна дня под существующие записи Jira
    if (existingSorted.isNotEmpty) {
      final earliestExisting = existingSorted.first.startUtc;
      final latestExisting = existingSorted.last.endUtc;
      final existingSpanSeconds = latestExisting
          .difference(earliestExisting)
          .inSeconds;

      if (existingSpanSeconds > 24 * 3600) {
        throw const DayBuilderException(
          'Существующие записи в Jira выходят за допустимое 24-часовое окно рабочего дня.',
        );
      }

      if (dayStartUtc.isAfter(earliestExisting)) {
        dayStartUtc = earliestExisting;
      }
      if (dayEndUtc.isBefore(latestExisting)) {
        dayEndUtc = latestExisting;
      }

      var currentSpan = dayEndUtc.difference(dayStartUtc).inSeconds;
      if (currentSpan > 24 * 3600) {
        throw const DayBuilderException(
          'С учётом существующих записей день превышает лимит в 24 часа.',
        );
      }

      // Если текущий span меньше номинального, попробуем расширить, не превышая 24 часа
      if (currentSpan < nominalDurationSeconds) {
        final toAdd = nominalDurationSeconds - currentSpan;
        dayEndUtc = dayEndUtc.add(Duration(seconds: toAdd));
        if (dayEndUtc.difference(dayStartUtc).inSeconds > 24 * 3600) {
          dayEndUtc = dayStartUtc.add(const Duration(seconds: 24 * 3600));
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
      needsLunch: needsLunch,
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

    final targetWorkSeconds = isShortDay
        ? min(totalSourceSeconds, newWorkBudget)
        : newWorkBudget;

    final workSchedule = _buildWorkSchedule(
      logs: logs,
      maximumWorkSeconds: targetWorkSeconds,
      freeIntervals: freeIntervals,
      existingBreaks: breaks,
      mandatoryPauseSeconds: settings.shortBreakDurationSecondsMin,
      draftId: input.draftId,
      seed: seed,
    );
    final segments = workSchedule.segments;
    breaks.addAll(workSchedule.additionalBreaks);
    breaks.sort((a, b) => a.startUtc.compareTo(b.startUtc));
    final allocated = workSchedule.allocatedSecondsBySourceLogId;

    final totalNewWorkSeconds = segments.fold<int>(
      0,
      (sum, s) => sum + s.durationSeconds,
    );

    final actualTotalBreaksSeconds = breaks.fold<int>(
      0,
      (sum, b) => sum + b.durationSeconds,
    );

    if (isShortDay &&
        settings.totalDurationSecondsMin != settings.totalDurationSecondsMax) {
      var actualEndUtc = dayStartUtc;
      for (final s in segments) {
        if (s.endUtc.isAfter(actualEndUtc)) actualEndUtc = s.endUtc;
      }
      for (final b in breaks) {
        if (b.endUtc.isAfter(actualEndUtc)) actualEndUtc = b.endUtc;
      }
      for (final ew in existingSorted) {
        if (ew.endUtc.isAfter(actualEndUtc)) actualEndUtc = ew.endUtc;
      }
      dayEndUtc = actualEndUtc;
    }

    final actualTotalDaySeconds = dayEndUtc.difference(dayStartUtc).inSeconds;

    final plan = DayPlanResult(
      dayStartUtc: dayStartUtc,
      dayEndUtc: dayEndUtc,
      segments: segments,
      breaks: breaks,
      allocatedSecondsBySourceLogId: allocated,
      totalNewWorkSeconds: totalNewWorkSeconds,
      totalBreaksSeconds: actualTotalBreaksSeconds,
      totalExistingSeconds: totalExistingSeconds,
      totalDaySeconds: actualTotalDaySeconds,
    );

    // Валидация построенного плана
    final errors = validate(plan: plan, existingWorklogs: existingSorted);
    if (errors.isNotEmpty) {
      throw DayBuilderException(errors.join('\n'));
    }

    return plan;
  }

  static _WorkSchedule _buildWorkSchedule({
    required List<DayBuilderLogInput> logs,
    required int maximumWorkSeconds,
    required List<_FreeInterval> freeIntervals,
    required List<Break> existingBreaks,
    required int mandatoryPauseSeconds,
    required String draftId,
    required int seed,
  }) {
    const minimumSegmentSeconds = 15 * 60;
    final lockedLogs = logs.where((log) => log.durationLocked).toList();
    final unlockedLogs = logs.where((log) => !log.durationLocked).toList();
    final lockedSum = lockedLogs.fold<int>(
      0,
      (sum, log) => sum + log.sourceDurationSeconds,
    );

    if (lockedLogs.any(
      (log) => log.sourceDurationSeconds < minimumSegmentSeconds,
    )) {
      throw const DayBuilderException(
        'Зафиксированный лог короче минимального рабочего интервала 15 минут.',
      );
    }
    if (lockedSum > maximumWorkSeconds) {
      final reqH = lockedSum ~/ 3600;
      final reqM = (lockedSum % 3600) ~/ 60;
      final availH = maximumWorkSeconds ~/ 3600;
      final availM = (maximumWorkSeconds % 3600) ~/ 60;
      throw DayBuilderException(
        'Фиксированные логи требуют $reqH ч $reqM мин, а доступно только $availH ч $availM мин.',
      );
    }
    if (unlockedLogs.isEmpty && lockedSum != maximumWorkSeconds) {
      final reqH = lockedSum ~/ 3600;
      final reqM = (lockedSum % 3600) ~/ 60;
      final availH = maximumWorkSeconds ~/ 3600;
      final availM = (maximumWorkSeconds % 3600) ~/ 60;
      throw DayBuilderException(
        'Все логи зафиксированы ($reqH ч $reqM мин), но бюджет составляет $availH ч $availM мин. Разблокируйте хотя бы один лог.',
      );
    }

    final minimumWorkSeconds =
        lockedSum + unlockedLogs.length * minimumSegmentSeconds;
    if (minimumWorkSeconds > maximumWorkSeconds) {
      throw const DayBuilderException(
        'Недостаточно времени: каждому выбранному логу требуется минимум 15 минут.',
      );
    }

    var workSeconds = maximumWorkSeconds;
    while (true) {
      final allocated = _allocateWorkSeconds(
        lockedLogs: lockedLogs,
        unlockedLogs: unlockedLogs,
        workSeconds: workSeconds,
        minimumSegmentSeconds: minimumSegmentSeconds,
      );
      final attemptRandom = Random(seed ^ workSeconds);
      final chunks = <_LogChunk>[];
      for (final log in logs) {
        for (final part in splitLargeDuration(
          allocated[log.sourceLogId]!,
          attemptRandom,
        )) {
          chunks.add(
            _LogChunk(
              sourceLogId: log.sourceLogId,
              issueId: log.issueId,
              description: log.description,
              durationSeconds: part,
            ),
          );
        }
      }

      final placement = _tryPlaceWorkChunks(
        chunks: _interleaveChunks(chunks, logs),
        freeIntervals: freeIntervals,
        existingBreaks: existingBreaks,
        mandatoryPauseSeconds: mandatoryPauseSeconds,
        minimumSegmentSeconds: minimumSegmentSeconds,
        draftId: draftId,
        rnd: attemptRandom,
      );
      if (placement != null) {
        return _WorkSchedule(
          segments: placement.segments,
          additionalBreaks: placement.additionalBreaks,
          allocatedSecondsBySourceLogId: allocated,
        );
      }

      if (workSeconds == minimumWorkSeconds) break;
      workSeconds = max(minimumWorkSeconds, workSeconds - 60);
    }

    throw const DayBuilderException(
      'Невозможно разместить рабочие интервалы от 15 минут с обязательными паузами. Измените выбор логов или настройки дня.',
    );
  }

  static Map<String, int> _allocateWorkSeconds({
    required List<DayBuilderLogInput> lockedLogs,
    required List<DayBuilderLogInput> unlockedLogs,
    required int workSeconds,
    required int minimumSegmentSeconds,
  }) {
    final allocated = <String, int>{
      for (final log in lockedLogs) log.sourceLogId: log.sourceDurationSeconds,
    };
    if (unlockedLogs.isEmpty) return allocated;

    final lockedSum = allocated.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final remaining = workSeconds - lockedSum;
    final distributable =
        remaining - unlockedLogs.length * minimumSegmentSeconds;
    final totalSourceSeconds = unlockedLogs.fold<int>(
      0,
      (sum, log) => sum + log.sourceDurationSeconds,
    );
    var allocatedSum = lockedSum;
    for (final log in unlockedLogs) {
      final extra = totalSourceSeconds == 0
          ? distributable ~/ unlockedLogs.length
          : log.sourceDurationSeconds * distributable ~/ totalSourceSeconds;
      allocated[log.sourceLogId] = minimumSegmentSeconds + extra;
      allocatedSum += minimumSegmentSeconds + extra;
    }

    var remainder = workSeconds - allocatedSum;
    final byDuration = [...unlockedLogs]
      ..sort(
        (a, b) => b.sourceDurationSeconds.compareTo(a.sourceDurationSeconds),
      );
    var index = 0;
    while (remainder > 0) {
      final logId = byDuration[index % byDuration.length].sourceLogId;
      allocated[logId] = allocated[logId]! + 1;
      remainder--;
      index++;
    }
    return allocated;
  }

  static _WorkPlacement? _tryPlaceWorkChunks({
    required List<_LogChunk> chunks,
    required List<_FreeInterval> freeIntervals,
    required List<Break> existingBreaks,
    required int mandatoryPauseSeconds,
    required int minimumSegmentSeconds,
    required String draftId,
    required Random rnd,
  }) {
    final segments = <Segment>[];
    final additionalBreaks = <Break>[];
    var intervalIndex = 0;
    var offset = 0;

    bool hasBreakBetween(DateTime start, DateTime end) =>
        [...existingBreaks, ...additionalBreaks].any(
          (pause) =>
              !pause.startUtc.isBefore(start) && !pause.endUtc.isAfter(end),
        );

    for (final chunk in chunks) {
      var remaining = chunk.durationSeconds;
      while (remaining > 0) {
        if (intervalIndex >= freeIntervals.length) return null;
        final interval = freeIntervals[intervalIndex];
        var available = interval.durationSeconds - offset;
        if (available < minimumSegmentSeconds) {
          intervalIndex++;
          offset = 0;
          continue;
        }

        var start = interval.startUtc.add(Duration(seconds: offset));
        if (segments.isNotEmpty &&
            !hasBreakBetween(segments.last.endUtc, start)) {
          if (available < mandatoryPauseSeconds + minimumSegmentSeconds) {
            intervalIndex++;
            offset = 0;
            continue;
          }
          additionalBreaks.add(
            Break(
              id: generateDeterministicUuid(rnd),
              draftId: draftId,
              startUtc: start,
              durationSeconds: mandatoryPauseSeconds,
              kind: BreakKind.short,
            ),
          );
          offset += mandatoryPauseSeconds;
          available -= mandatoryPauseSeconds;
          start = start.add(Duration(seconds: mandatoryPauseSeconds));
        }

        var slice = min(remaining, available);
        if (slice < minimumSegmentSeconds) {
          intervalIndex++;
          offset = 0;
          continue;
        }
        final tail = remaining - slice;
        if (tail > 0 && tail < minimumSegmentSeconds) {
          slice = remaining - minimumSegmentSeconds;
          if (slice < minimumSegmentSeconds) {
            intervalIndex++;
            offset = 0;
            continue;
          }
        }

        segments.add(
          Segment(
            id: generateDeterministicUuid(rnd),
            draftId: draftId,
            sourceLogId: chunk.sourceLogId,
            issueId: chunk.issueId,
            startUtc: start,
            durationSeconds: slice,
            description: chunk.description,
            sendState: SendState.pending,
          ),
        );
        offset += slice;
        remaining -= slice;
        if (offset >= interval.durationSeconds) {
          intervalIndex++;
          offset = 0;
        }
      }
    }

    return _WorkPlacement(
      segments: segments,
      additionalBreaks: additionalBreaks,
    );
  }

  /// Проверка полуоткрытых интервалов [start, end) и инвариантов расписания.
  static List<String> validate({
    required DayPlanResult plan,
    List<ImportedWorklog> existingWorklogs = const [],
    bool requirePauses = true,
  }) {
    final errors = <String>[];

    if (plan.totalDaySeconds > 24 * 3600) {
      errors.add(
        'Общая продолжительность дня (${plan.totalDaySeconds} сек) превышает 24 часа.',
      );
    }
    if (plan.totalNewWorkSeconds + plan.totalExistingSeconds > 24 * 3600) {
      errors.add(
        'Суммарное рабочее время превышает 24 часа.',
      );
    }

    for (final s in plan.segments) {
      if (s.durationSeconds <= 0) {
        errors.add('Сегмент ${s.id} имеет неположительную длительность.');
      } else if (requirePauses && s.durationSeconds < 10 * 60) {
        errors.add('Сегмент ${s.id} короче минимальных 10 минут.');
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

    if (requirePauses && plan.breaks.isNotEmpty) {
      final workSegments = [...plan.segments]
        ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
      for (var i = 0; i < workSegments.length - 1; i++) {
        final current = workSegments[i];
        final next = workSegments[i + 1];
        if (current.endUtc.isAfter(next.startUtc)) continue;
        final hasPause = plan.breaks.any(
          (pause) =>
              !pause.startUtc.isBefore(current.endUtc) &&
              !pause.endUtc.isAfter(next.startUtc),
        );
        if (!hasPause) {
          errors.add(
            'Между рабочими интервалами ${current.id} и ${next.id} отсутствует обязательная пауза.',
          );
        }
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
    bool needsLunch = true,
  }) {
    final breaks = <Break>[];

    Break? lunchBreak;
    if (needsLunch) {
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
            type: 'Перерыв',
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
            type: 'Перерыв',
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
          'Невозможно разместить длинный перерыв: нет свободного времени достаточной длины.',
        );
      }

      lunchBreak = Break(
        id: generateDeterministicUuid(rnd),
        draftId: draftId,
        startUtc: chosenLunchStart,
        durationSeconds: lunchDuration,
        kind: BreakKind.short,
      );
      breaks.add(lunchBreak);
    }

    // 2. Размещение коротких пауз
    final breakCount = settings.shortBreakCountMax > settings.shortBreakCountMin
        ? settings.shortBreakCountMin +
              rnd.nextInt(
                settings.shortBreakCountMax - settings.shortBreakCountMin + 1,
              )
        : settings.shortBreakCountMin;

    if (breakCount > 0) {
      if (lunchBreak != null) {
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
      } else {
        _placeShortBreaksInSpan(
          spanStart: dayStartUtc,
          spanEnd: dayEndUtc,
          count: breakCount,
          settings: settings,
          existingWorklogs: existingWorklogs,
          breaks: breaks,
          draftId: draftId,
          rnd: rnd,
        );
      }
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

class _WorkPlacement {
  final List<Segment> segments;
  final List<Break> additionalBreaks;

  const _WorkPlacement({
    required this.segments,
    required this.additionalBreaks,
  });
}

class _WorkSchedule extends _WorkPlacement {
  final Map<String, int> allocatedSecondsBySourceLogId;

  const _WorkSchedule({
    required super.segments,
    required super.additionalBreaks,
    required this.allocatedSecondsBySourceLogId,
  });
}

class _CandidateLog {
  final DayBuilderLogInput log;
  final DateTime projectedStartUtc;

  const _CandidateLog({
    required this.log,
    required this.projectedStartUtc,
  });
}
