import 'models.dart';

/// Результат вычисления времени по часам.
class ClockResult {
  /// Итоговое прошедшее время в секундах.
  final int elapsedSeconds;

  /// Признак обнаружения отката системных часов назад.
  final bool hasClockRollback;

  /// Сообщение об ошибке при обнаружении отката времени.
  final String? errorMessage;

  const ClockResult({
    required this.elapsedSeconds,
    this.hasClockRollback = false,
    this.errorMessage,
  });
}

/// Чистый Dart-модуль расчёта времени логов.
///
/// Не обращается к DateTime.now() напрямую: время nowUtc всегда передаётся явно,
/// что обеспечивает детерминированность и простоту тестирования.
class LogClock {
  const LogClock._();

  /// Вычисляет текущее прошедшее время для лога.
  ///
  /// Для остановленного лога возвращает [LocalLog.accumulatedSeconds].
  /// Для работающего лога прибавляет разницу между [nowUtc] и [LocalLog.runningSinceUtc].
  /// Если [nowUtc] предшествует [LocalLog.runningSinceUtc], фиксирует ошибку отката часов.
  static ClockResult calculateElapsed({
    required LocalLog log,
    required DateTime nowUtc,
  }) {
    final utc = nowUtc.isUtc ? nowUtc : nowUtc.toUtc();

    if (!log.isRunning) {
      return ClockResult(
        elapsedSeconds: log.accumulatedSeconds,
        hasClockRollback: false,
      );
    }

    final runningSince = log.runningSinceUtc!.isUtc
        ? log.runningSinceUtc!
        : log.runningSinceUtc!.toUtc();

    final delta = utc.difference(runningSince).inSeconds;

    if (delta < 0) {
      return ClockResult(
        elapsedSeconds: log.accumulatedSeconds,
        hasClockRollback: true,
        errorMessage:
            'Отрицательная разница времени ($delta с): системные часы были переведены назад. Проверьте лог.',
      );
    }

    return ClockResult(
      elapsedSeconds: log.accumulatedSeconds + delta,
      hasClockRollback: false,
    );
  }

  /// Переводит лог в состояние запуска (Play).
  ///
  /// Если лог уже работает, возвращает его без изменений.
  static LocalLog start({required LocalLog log, required DateTime nowUtc}) {
    if (log.isRunning) return log;
    final utc = nowUtc.isUtc ? nowUtc : nowUtc.toUtc();
    return log.copyWith(runningSinceUtc: utc);
  }

  /// Переводит работающий лог в состояние паузы (Pause).
  ///
  /// Фиксирует накопленное время в [LocalLog.accumulatedSeconds] и очищает [LocalLog.runningSinceUtc].
  /// При обнаружении отката системных часов лог не изменяет накопленные секунды
  /// и возвращает результат с признаком [ClockResult.hasClockRollback].
  static (LocalLog, ClockResult) pause({
    required LocalLog log,
    required DateTime nowUtc,
  }) {
    if (!log.isRunning) {
      return (
        log,
        ClockResult(
          elapsedSeconds: log.accumulatedSeconds,
          hasClockRollback: false,
        ),
      );
    }

    final result = calculateElapsed(log: log, nowUtc: nowUtc);
    if (result.hasClockRollback) {
      // При откате системных часов сохраняем лог как есть, но очищаем таймер или возвращаем ошибку
      return (log, result);
    }

    final pausedLog = log.copyWith(
      accumulatedSeconds: result.elapsedSeconds,
      clearRunningSince: true,
    );

    return (pausedLog, result);
  }

  /// Форматирует секунды в текстовый вид для интерфейса: «3ч 15м», «45м», «0м».
  static String formatHoursMinutes(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '$hoursч ${minutes.toString().padLeft(2, '0')}м';
    } else {
      return '$minutesм';
    }
  }

  /// Форматирует секунды в цифровой таймер: «HH:MM:SS».
  static String formatDigital(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    return '$hStr:$mStr:$sStr';
  }
}
