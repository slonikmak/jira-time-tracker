import 'app_message.dart';
import 'dart:convert';
import 'jira_client.dart';
import 'local_store.dart';
import 'models.dart';

/// Результат отправки черновика дня в Jira.
class SendDraftResult {
  final int sent;
  final int failed;
  final int unknown;
  final int skipped;
  final Object? errorText;
  String? get errorMessage => errorText?.toString();

  const SendDraftResult({
    required this.sent,
    required this.failed,
    required this.unknown,
    required this.skipped,
    Object? errorMessage,
  }) : errorText = errorMessage;

  bool get isSuccess => failed == 0 && unknown == 0 && errorMessage == null;
}

/// Статус сверки unknown сегмента.
enum ReconcileStatus { recovered, conflict, notFound, error }

/// Результат сверки неизвестного статуса сегмента по properties в Jira.
class ReconcileResult {
  final ReconcileStatus status;
  final String? worklogId;
  final Object messageText;
  String get message => messageText.toString();

  const ReconcileResult({
    required this.status,
    this.worklogId,
    required Object message,
  }) : messageText = message;

  factory ReconcileResult.recovered(String worklogId) => ReconcileResult(
    status: ReconcileStatus.recovered,
    worklogId: worklogId,
    message: AppMessage(
      'entrySuccessfullyFoundAndConfirmedInJiraId',
      [worklogId],
      'Запись успешно найдена в Jira и подтверждена (ID: $worklogId).',
    ),
  );

  factory ReconcileResult.conflict(Object message) =>
      ReconcileResult(status: ReconcileStatus.conflict, message: message);

  factory ReconcileResult.notFound([Object? message]) => ReconcileResult(
    status: ReconcileStatus.notFound,
    message:
        message ??
        AppMessage(
          'theJiraTimeTrackerSegmentPropertyWasNot',
          [],
          'Свойство jira-time-tracker.segment не найдено среди записей задачи в Jira. Слепая повторная отправка запрещена.',
        ),
  );

  factory ReconcileResult.error(Object message) =>
      ReconcileResult(status: ReconcileStatus.error, message: message);
}

/// Результат ручной привязки worklog ID.
class ManualResolveResult {
  final bool isSuccess;
  final Object? errorText;
  String? get errorMessage => errorText?.toString();

  const ManualResolveResult({required this.isSuccess, Object? errorMessage})
    : errorText = errorMessage;

  factory ManualResolveResult.success() =>
      const ManualResolveResult(isSuccess: true);
  factory ManualResolveResult.error(Object message) =>
      ManualResolveResult(isSuccess: false, errorMessage: message);
}

/// Модуль для надежной, транзакционной и идемпотентной отправки интервалов в Jira (сценарии A14, A15).
class WorklogSender {
  final LocalStore store;
  final JiraClient jiraClient;
  final DateTime Function() nowProvider;

  WorklogSender({
    required this.store,
    required this.jiraClient,
    DateTime Function()? nowProvider,
  }) : nowProvider = nowProvider ?? (() => DateTime.now().toUtc());

  /// Форматирует время старта в каноничный ISO-формат Jira (YYYY-MM-DDTHH:mm:ss.SSS+0000).
  static String formatJiraStarted(DateTime utcDate) {
    final dt = utcDate.toUtc();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$y-$m-${d}T$h:$min:$s.$ms+0000';
  }

  /// Формирует ADF-комментарий для описания worklog. Если описание пустое — возвращает null.
  static Map<String, dynamic>? buildAdfComment(String description) {
    final trimmed = description.trim();
    if (trimmed.isEmpty) return null;
    return {
      'type': 'doc',
      'version': 1,
      'content': [
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': trimmed},
          ],
        },
      ],
    };
  }

  /// Формирует тело запроса к Jira API.
  static Map<String, dynamic> buildPayload(Segment segment) {
    final payload = <String, dynamic>{
      'started': formatJiraStarted(segment.startUtc),
      'timeSpentSeconds': segment.durationSeconds,
      'properties': [
        {
          'key': 'jira-time-tracker.segment',
          'value': {'id': segment.id},
        },
      ],
    };

    final comment = buildAdfComment(segment.description);
    if (comment != null) {
      payload['comment'] = comment;
    }

    return payload;
  }

  /// Пошаговая отправка сегментов черновика дня в Jira.
  Future<SendDraftResult> sendDraft({
    required DayDraft draft,
    required JiraConnection connection,
    required String token,
    void Function(Segment segment)? onSegmentProgress,
  }) async {
    // Проверка соответствия scope (сценарий A17)
    if (draft.scope != connection.scope) {
      return SendDraftResult(
        sent: 0,
        failed: 0,
        unknown: 0,
        skipped: 0,
        errorMessage: AppMessage(
          'connectionMismatchTheDraftBelongsToSiteAccount',
          [draft.scope, connection.scope],
          'Несоответствие подключения: черновик принадлежит сайту/аккаунту "${draft.scope}", а текущее подключение — "${connection.scope}". Отправка заблокирована.',
        ),
      );
    }

    // Переводим черновик в статус sending
    store.updateDayDraft(draft.copyWith(status: DraftStatus.sending));

    final segments = store.getSegments(draftId: draft.id);
    if (segments.isEmpty) {
      store.updateDayDraft(draft.copyWith(status: DraftStatus.draft));
      return SendDraftResult(
        sent: 0,
        failed: 0,
        unknown: 0,
        skipped: 0,
        errorMessage: AppMessage(
          'theDraftIsEmptyThereAreNoIntervals',
          [],
          'Черновик пуст, нет интервалов для отправки.',
        ),
      );
    }

    var sentCount = 0;
    var failedCount = 0;
    var unknownCount = 0;
    var skippedCount = 0;

    for (final segment in segments) {
      // Подтвержденные ранее интервалы пропускаем (сценарий A14)
      if (segment.sendState == SendState.sent) {
        skippedCount++;
        continue;
      }

      // Неопределенный статус нельзя отправлять вслепую (сценарии A15, A19)
      if (segment.sendState == SendState.unknown) {
        unknownCount++;
        continue;
      }

      // Отправляем pending и failed (сценарий A14)
      if (segment.sendState == SendState.pending ||
          segment.sendState == SendState.failed) {
        // Шаг 1: До сетевого POST транзакционно сохраняем sending и неизменяемое тело (сценарий A14)
        final payload = buildPayload(segment);
        final frozenPayloadStr = jsonEncode(payload);
        final sendingSegment = segment.copyWith(
          sendState: SendState.sending,
          frozenPayload: frozenPayloadStr,
          lastError: null,
        );
        store.updateSegment(sendingSegment);
        onSegmentProgress?.call(sendingSegment);

        // Шаг 2: Сетевой POST строго по одному интервалу
        final postResult = await jiraClient.postWorklog(
          issueIdOrKey: segment.issueId,
          payload: payload,
          connection: connection,
          token: token,
        );

        // Шаг 3: Фиксация результата транзакцией в SQLite
        if (postResult.kind == JiraPostResultKind.success) {
          final sentSegment = segment.copyWith(
            sendState: SendState.sent,
            jiraWorklogId: postResult.worklogId,
            lastError: null,
            frozenPayload: frozenPayloadStr,
          );
          store.updateSegment(sentSegment);
          sentCount++;
          onSegmentProgress?.call(sentSegment);

          // Исходный лог помечается consumed ТОЛЬКО когда ВСЕ его сегменты перешли в sent (A10, A14)
          if (store.areAllSegmentsSentForLog(draft.id, segment.sourceLogId)) {
            store.markLocalLogConsumed(segment.sourceLogId, nowProvider());
          }
        } else if (postResult.kind == JiraPostResultKind.failed) {
          final failedSegment = segment.copyWith(
            sendState: SendState.failed,
            lastError: serializeMessage(
              postResult.errorText ??
                  AppMessage('jiraRejectedTheRequest', [], 'Отказ Jira'),
            ),
            frozenPayload: frozenPayloadStr,
          );
          store.updateSegment(failedSegment);
          failedCount++;
          onSegmentProgress?.call(failedSegment);
        } else {
          final unknownSegment = segment.copyWith(
            sendState: SendState.unknown,
            lastError: serializeMessage(
              postResult.errorText ??
                  AppMessage(
                    'unknownSubmissionResultTheConnectionMayHaveBeen',
                    [],
                    'Неопределённый статус отправки (возможен обрыв связи)',
                  ),
            ),
            frozenPayload: frozenPayloadStr,
          );
          store.updateSegment(unknownSegment);
          unknownCount++;
          onSegmentProgress?.call(unknownSegment);
        }
      }
    }

    // Обновляем статус черновика: completed если всё подтверждено, иначе draft
    final isAllSent = store.areAllSegmentsSentForDraft(draft.id);
    store.updateDayDraft(
      draft.copyWith(
        status: isAllSent ? DraftStatus.completed : DraftStatus.draft,
      ),
    );

    return SendDraftResult(
      sent: sentCount,
      failed: failedCount,
      unknown: unknownCount,
      skipped: skippedCount,
    );
  }

  /// Сверка сегмента со статусом unknown через properties в Jira (сценарий A15).
  Future<ReconcileResult> reconcileSegment({
    required Segment segment,
    required JiraConnection connection,
    required String token,
  }) async {
    try {
      final worklogs = await jiraClient.getIssueWorklogs(
        issueIdOrKey: segment.issueId,
        connection: connection,
        token: token,
      );

      // Ищем записи с совпадающим segment id в properties
      final matchingWorklogs = <ImportedWorklog>[];

      for (final w in worklogs) {
        if (w.segmentPropertyId == segment.id) {
          matchingWorklogs.add(w);
        } else if (w.segmentPropertyId == null) {
          // Если expand=properties не вернул свойство, пробуем индивидуальный запрос свойства
          final prop = await jiraClient.getWorklogProperty(
            issueIdOrKey: segment.issueId,
            worklogId: w.id,
            propertyKey: 'jira-time-tracker.segment',
            connection: connection,
            token: token,
          );
          if (prop != null && prop['value'] is Map) {
            final val = prop['value'] as Map;
            if (val['id']?.toString() == segment.id) {
              matchingWorklogs.add(w);
            }
          }
        }
      }

      if (matchingWorklogs.length > 1) {
        final msg = AppMessage(
          'conflictMultipleEntriesFoundWithSegmentIdManual',
          [matchingWorklogs.length, segment.id],
          'Конфликт: найдено несколько (${matchingWorklogs.length}) записей с свойством segment id "${segment.id}". Требуется ручная проверка.',
        );
        store.updateSegment(segment.copyWith(lastError: serializeMessage(msg)));
        return ReconcileResult.conflict(msg);
      }

      if (matchingWorklogs.length == 1) {
        final match = matchingWorklogs.first;

        // Сверяем автора, длительность и приблизительное время
        final authorMatches = match.authorAccountId == connection.accountId;
        final durationMatches =
            match.durationSeconds == segment.durationSeconds;
        final timeDiffSeconds =
            (match.startUtc.difference(segment.startUtc).inSeconds).abs();
        final timeMatches = timeDiffSeconds <= 60; // допуск 1 минута

        if (authorMatches && durationMatches && timeMatches) {
          // Совпадение подтверждено! Переводим в sent без второго POST (сценарий A15)
          final updated = segment.copyWith(
            sendState: SendState.sent,
            jiraWorklogId: match.id,
            lastError: null,
          );
          store.updateSegment(updated);

          // Проверяем пометку исходного лога consumed
          if (store.areAllSegmentsSentForLog(
            segment.draftId,
            segment.sourceLogId,
          )) {
            store.markLocalLogConsumed(segment.sourceLogId, nowProvider());
          }

          if (store.areAllSegmentsSentForDraft(segment.draftId)) {
            final d = store.getDayDraftById(segment.draftId);
            if (d != null) {
              store.updateDayDraft(d.copyWith(status: DraftStatus.completed));
            }
          }

          return ReconcileResult.recovered(match.id);
        } else {
          final msg = AppMessage(
            'conflictAnEntryWithTheSameSegmentId',
            [
              authorMatches
                  ? "OK"
                  : const AppMessage('mismatch', [], "не совпадает"),
              durationMatches
                  ? "OK"
                  : const AppMessage('mismatch', [], "не совпадает"),
              timeMatches
                  ? "OK"
                  : const AppMessage('mismatch', [], "не совпадает"),
            ],
            'Конфликт: найдена запись с совпадающим segment id, но параметры не совпадают (автор: ${authorMatches ? "OK" : const AppMessage('mismatch', [], "не совпадает")}, длительность: ${durationMatches ? "OK" : const AppMessage('mismatch', [], "не совпадает")}, время: ${timeMatches ? "OK" : const AppMessage('mismatch', [], "не совпадает")}).',
          );
          store.updateSegment(
            segment.copyWith(lastError: serializeMessage(msg)),
          );
          return ReconcileResult.conflict(msg);
        }
      }

      return ReconcileResult.notFound();
    } catch (e) {
      return ReconcileResult.error(
        AppMessage('networkErrorDuringReconciliation', [
          e,
        ], 'Сетевая ошибка при сверке: $e'),
      );
    }
  }

  /// Ручное связывание сегмента с известным ID worklog в Jira (сценарий A15).
  Future<ManualResolveResult> manuallyLinkWorklog({
    required Segment segment,
    required String worklogId,
    required JiraConnection connection,
    required String token,
  }) async {
    try {
      final worklog = await jiraClient.getWorklogById(
        issueIdOrKey: segment.issueId,
        worklogId: worklogId,
        connection: connection,
        token: token,
      );

      if (worklog == null) {
        return ManualResolveResult.error(
          AppMessage(
            'entryWithIdWasNotFoundInIssue',
            [worklogId, segment.issueId],
            'Запись с ID "$worklogId" не найдена в задаче "${segment.issueId}".',
          ),
        );
      }

      if (worklog.authorAccountId != connection.accountId) {
        return ManualResolveResult.error(
          AppMessage(
            'theEntryBelongsToAnotherJiraUserAccountid',
            [worklog.authorAccountId],
            'Запись принадлежит другому пользователю Jira (accountId: ${worklog.authorAccountId}).',
          ),
        );
      }

      if (worklog.durationSeconds != segment.durationSeconds) {
        return ManualResolveResult.error(
          AppMessage(
            'jiraEntryDurationSDoesNotMatchThe',
            [worklog.durationSeconds, segment.durationSeconds],
            'Длительность записи в Jira (${worklog.durationSeconds} с) не совпадает с сегментом (${segment.durationSeconds} с).',
          ),
        );
      }

      // Все проверки пройдены
      final updated = segment.copyWith(
        sendState: SendState.sent,
        jiraWorklogId: worklog.id,
        lastError: null,
      );
      store.updateSegment(updated);

      if (store.areAllSegmentsSentForLog(
        segment.draftId,
        segment.sourceLogId,
      )) {
        store.markLocalLogConsumed(segment.sourceLogId, nowProvider());
      }

      if (store.areAllSegmentsSentForDraft(segment.draftId)) {
        final d = store.getDayDraftById(segment.draftId);
        if (d != null) {
          store.updateDayDraft(d.copyWith(status: DraftStatus.completed));
        }
      }

      return ManualResolveResult.success();
    } catch (e) {
      return ManualResolveResult.error(
        AppMessage('errorCheckingTheJiraEntry', [
          e,
        ], 'Ошибка проверки записи в Jira: $e'),
      );
    }
  }

  /// Пользователь подтвердил отсутствие записи в Jira и разрешил повтор (сценарий A15).
  void manuallyConfirmAbsenceAndAllowRetry({required Segment segment}) {
    final updated = segment.copyWith(
      sendState: SendState.pending,
      lastError: serializeMessage(
        AppMessage(
          'resetByUserConfirmedTheEntryDoesNot',
          [],
          'Сброшено пользователем: подтверждено отсутствие записи в Jira, разрешён повтор',
        ),
      ),
    );
    store.updateSegment(updated);
  }
}
