import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/worklog_sender.dart';

void main() {
  group('Worklog Submission & Reconciliation (Ticket 09, A10, A14, A15, A17, A19)', () {
    const testBaseUrl = 'https://company.atlassian.net';
    const testAccountId = 'acc-test-123';
    const testScope = '$testBaseUrl#$testAccountId';
    const testToken = 'valid-token';

    const testConnection = JiraConnection(
      baseUrl: testBaseUrl,
      email: 'user@company.com',
      accountId: testAccountId,
      displayName: 'User Test',
      route: JiraAuthRoute.direct,
      scope: testScope,
    );

    late Database db;
    late LocalStore store;
    final fixedNow = DateTime.utc(2026, 9, 14, 18, 0);

    setUp(() {
      db = sqlite3.openInMemory();
      store = LocalStore(db);
      store.init();

      // Создаем базовые задачи
      store.upsertIssue(
        Issue(
          scope: testScope,
          issueId: '1001',
          key: 'PROJ-1',
          summary: 'Task 1',
          lastUsedAtUtc: DateTime.utc(2026, 9, 14, 8, 0),
        ),
      );
      store.upsertIssue(
        Issue(
          scope: testScope,
          issueId: '1002',
          key: 'PROJ-2',
          summary: 'Task 2',
          lastUsedAtUtc: DateTime.utc(2026, 9, 14, 9, 0),
        ),
      );
    });

    tearDown(() {
      store.close();
    });

    test(
      'A14: Сегмент перед POST сохраняет sending и frozenPayload; при 201 переходит в sent',
      () async {
        // Подготовка: 1 лог, 1 сегмент
        final log = LocalLog(
          id: 'log-1',
          scope: testScope,
          issueId: '1001',
          titleSnapshot: 'PROJ-1 Task 1',
          description: 'Разработка фичи',
          accumulatedSeconds: 3600,
          createdAtUtc: DateTime.utc(2026, 9, 14, 10, 0),
        );
        store.upsertLocalLog(log);

        final draft = DayDraft(
          id: 'draft-1',
          scope: testScope,
          date: '2026-09-14',
          startUtc: DateTime.utc(2026, 9, 14, 8, 0),
          endUtc: DateTime.utc(2026, 9, 14, 9, 0),
          seed: 42,
          settingsSnapshot: '{}',
        );
        store.saveDayDraft(
          draft: draft,
          draftLogs: [
            DraftLog(
              draftId: 'draft-1',
              sourceLogId: 'log-1',
              sourceDurationSeconds: 3600,
              descriptionSnapshot: 'Разработка фичи',
            ),
          ],
          segments: [
            Segment(
              id: 'seg-1',
              draftId: 'draft-1',
              sourceLogId: 'log-1',
              issueId: '1001',
              startUtc: DateTime.utc(2026, 9, 14, 8, 0),
              durationSeconds: 3600,
              description: 'Разработка фичи',
            ),
          ],
          breaks: [],
        );

        final capturedRequests = <http.Request>[];

        final mockHttpClient = MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path.contains('/worklog')) {
            capturedRequests.add(request);
            // Возвращаем 201 Created
            return http.Response(
              jsonEncode({
                'id': 'wl-9901',
                'issueId': '1001',
                'timeSpentSeconds': 3600,
              }),
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final jiraClient = JiraClient(client: mockHttpClient);
        final sender = WorklogSender(
          store: store,
          jiraClient: jiraClient,
          nowProvider: () => fixedNow,
        );

        final result = await sender.sendDraft(
          draft: draft,
          connection: testConnection,
          token: testToken,
        );

        expect(result.isSuccess, isTrue);
        expect(result.sent, 1);
        expect(result.failed, 0);
        expect(result.unknown, 0);

        // Проверяем тело сетевого запроса
        expect(capturedRequests.length, 1);
        final req = capturedRequests.first;
        expect(req.url.queryParameters['adjustEstimate'], 'leave');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['timeSpentSeconds'], 3600);
        expect(body['properties'], isNotEmpty);
        final prop = (body['properties'] as List).first as Map;
        expect(prop['key'], 'jira-time-tracker.segment');
        expect(prop['value']['id'], 'seg-1');
        expect(body['comment'], isNotNull);
        expect(body['comment']['type'], 'doc');

        // Проверяем состояние сегмента в базе данных
        final segments = store.getSegments(draftId: 'draft-1');
        expect(segments.first.sendState, SendState.sent);
        expect(segments.first.jiraWorklogId, 'wl-9901');
        expect(segments.first.frozenPayload, isNotNull);

        // Проверяем, что исходный лог помечен consumed, так как все его сегменты sent (A10, A14)
        final reloadedLog = store.getLocalLog('log-1');
        expect(reloadedLog?.consumedAtUtc, fixedNow);

        // Черновик дня перешел в completed
        final reloadedDraft = store.getDayDraftById('draft-1');
        expect(reloadedDraft?.status, DraftStatus.completed);
      },
    );

    test(
      'A14: Частичный отказ (1 sent, 1 failed) и повторный клик пропускает sent',
      () async {
        // 2 лога: log-1 и log-2
        final log1 = LocalLog(
          id: 'log-1',
          scope: testScope,
          issueId: '1001',
          titleSnapshot: 'Task 1',
          accumulatedSeconds: 3600,
          createdAtUtc: DateTime.utc(2026, 9, 14, 8, 0),
        );
        final log2 = LocalLog(
          id: 'log-2',
          scope: testScope,
          issueId: '1002',
          titleSnapshot: 'Task 2',
          accumulatedSeconds: 3600,
          createdAtUtc: DateTime.utc(2026, 9, 14, 9, 0),
        );
        store.upsertLocalLog(log1);
        store.upsertLocalLog(log2);

        final draft = DayDraft(
          id: 'draft-partial',
          scope: testScope,
          date: '2026-09-14',
          startUtc: DateTime.utc(2026, 9, 14, 8, 0),
          endUtc: DateTime.utc(2026, 9, 14, 10, 0),
          seed: 42,
          settingsSnapshot: '{}',
        );
        store.saveDayDraft(
          draft: draft,
          draftLogs: [
            DraftLog(
              draftId: draft.id,
              sourceLogId: 'log-1',
              sourceDurationSeconds: 3600,
              descriptionSnapshot: '',
            ),
            DraftLog(
              draftId: draft.id,
              sourceLogId: 'log-2',
              sourceDurationSeconds: 3600,
              descriptionSnapshot: '',
            ),
          ],
          segments: [
            Segment(
              id: 'seg-1',
              draftId: draft.id,
              sourceLogId: 'log-1',
              issueId: '1001',
              startUtc: DateTime.utc(2026, 9, 14, 8, 0),
              durationSeconds: 3600,
            ),
            Segment(
              id: 'seg-2',
              draftId: draft.id,
              sourceLogId: 'log-2',
              issueId: '1002',
              startUtc: DateTime.utc(2026, 9, 14, 9, 0),
              durationSeconds: 3600,
            ),
          ],
          breaks: [],
        );

        var attempt = 1;
        final requestedIssueIds = <String>[];

        final mockHttpClient = MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path.contains('/worklog')) {
            final isTask1 = request.url.path.contains('/1001/');
            requestedIssueIds.add(isTask1 ? '1001' : '1002');

            if (isTask1) {
              return http.Response(jsonEncode({'id': 'wl-101'}), 201);
            } else {
              if (attempt == 1) {
                // Первая попытка: Task 2 возвращает 403 Forbidden
                return http.Response.bytes(
                  utf8.encode(
                    jsonEncode({
                      'errorMessages': ['Нет прав на списание времени'],
                    }),
                  ),
                  403,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                );
              } else {
                // Вторая попытка: Task 2 возвращает 201 Created
                return http.Response(
                  jsonEncode({'id': 'wl-102'}),
                  201,
                  headers: {'content-type': 'application/json'},
                );
              }
            }
          }
          return http.Response('Not Found', 404);
        });

        final sender = WorklogSender(
          store: store,
          jiraClient: JiraClient(client: mockHttpClient),
          nowProvider: () => fixedNow,
        );

        // --- Первая отправка ---
        final res1 = await sender.sendDraft(
          draft: draft,
          connection: testConnection,
          token: testToken,
        );

        expect(res1.sent, 1);
        expect(res1.failed, 1);
        expect(res1.unknown, 0);

        // Проверяем: seg-1 sent, seg-2 failed
        final segs1 = store.getSegments(draftId: draft.id);
        expect(segs1[0].sendState, SendState.sent);
        expect(segs1[0].jiraWorklogId, 'wl-101');
        expect(segs1[1].sendState, SendState.failed);
        expect(segs1[1].lastError, contains('Нет прав'));

        // log-1 consumed, log-2 NOT consumed (A10, A14: успешный источник не ждёт ошибок других)
        expect(store.getLocalLog('log-1')?.consumedAtUtc, isNotNull);
        expect(store.getLocalLog('log-2')?.consumedAtUtc, isNull);

        // Черновик не completed, а draft
        expect(store.getDayDraftById(draft.id)?.status, DraftStatus.draft);

        // --- Вторая отправка (повторный клик) ---
        attempt = 2;
        requestedIssueIds.clear();

        final res2 = await sender.sendDraft(
          draft: draft,
          connection: testConnection,
          token: testToken,
        );

        expect(res2.sent, 1); // отправлен seg-2
        expect(res2.skipped, 1); // пропущен seg-1
        expect(res2.failed, 0);
        expect(res2.unknown, 0);

        // Запрос ушёл ТОЛЬКО для 1002, seg-1 не отправлялся повторно!
        expect(requestedIssueIds, ['1002']);

        // Теперь оба лога consumed
        expect(store.getLocalLog('log-2')?.consumedAtUtc, isNotNull);
        expect(store.getDayDraftById(draft.id)?.status, DraftStatus.completed);
      },
    );

    test(
      'A15: Обрыв соединения -> unknown; сверка properties восстанавливает sent без второго POST',
      () async {
        final log = LocalLog(
          id: 'log-reconcile',
          scope: testScope,
          issueId: '1001',
          titleSnapshot: 'Task Reconcile',
          accumulatedSeconds: 3600,
          createdAtUtc: DateTime.utc(2026, 9, 14, 8, 0),
        );
        store.upsertLocalLog(log);

        final draft = DayDraft(
          id: 'draft-rec',
          scope: testScope,
          date: '2026-09-14',
          startUtc: DateTime.utc(2026, 9, 14, 8, 0),
          endUtc: DateTime.utc(2026, 9, 14, 9, 0),
          seed: 42,
          settingsSnapshot: '{}',
        );
        final segment = Segment(
          id: 'seg-rec-1',
          draftId: draft.id,
          sourceLogId: 'log-reconcile',
          issueId: '1001',
          startUtc: DateTime.utc(2026, 9, 14, 8, 0),
          durationSeconds: 3600,
        );
        store.saveDayDraft(
          draft: draft,
          draftLogs: [
            DraftLog(
              draftId: draft.id,
              sourceLogId: 'log-reconcile',
              sourceDurationSeconds: 3600,
              descriptionSnapshot: '',
            ),
          ],
          segments: [segment],
          breaks: [],
        );

        var postCallCount = 0;

        final mockHttpClient = MockClient((request) async {
          if (request.method == 'POST') {
            postCallCount++;
            // Симуляция сетевого обрыва / 504 Gateway Timeout
            return http.Response('Gateway Timeout', 504);
          }

          // GET worklogs с expand=properties
          if (request.method == 'GET' &&
              request.url.path.contains('/worklog')) {
            // Имитируем, что в Jira запись на самом деле была создана перед сбоем шлюза!
            return http.Response(
              jsonEncode({
                'startAt': 0,
                'maxResults': 50,
                'total': 1,
                'worklogs': [
                  {
                    'id': 'wl-created-on-server-77',
                    'author': {'accountId': testAccountId},
                    'started': '2026-09-14T08:00:00.000+0000',
                    'timeSpentSeconds': 3600,
                    'properties': [
                      {
                        'key': 'jira-time-tracker.segment',
                        'value': {'id': 'seg-rec-1'},
                      },
                    ],
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.Response('Not Found', 404);
        });

        final sender = WorklogSender(
          store: store,
          jiraClient: JiraClient(client: mockHttpClient),
          nowProvider: () => fixedNow,
        );

        // 1. Отправка завершается с unknown из-за 504
        final sendResult = await sender.sendDraft(
          draft: draft,
          connection: testConnection,
          token: testToken,
        );

        expect(sendResult.sent, 0);
        expect(sendResult.unknown, 1);
        expect(postCallCount, 1);

        final segAfterSend = store.getSegments(draftId: draft.id).first;
        expect(segAfterSend.sendState, SendState.unknown);
        expect(store.getLocalLog('log-reconcile')?.consumedAtUtc, isNull);

        // 2. Сверка через свойства задачи
        final reconcileRes = await sender.reconcileSegment(
          segment: segAfterSend,
          connection: testConnection,
          token: testToken,
        );

        expect(reconcileRes.status, ReconcileStatus.recovered);
        expect(reconcileRes.worklogId, 'wl-created-on-server-77');

        // Ни одного второго POST не было! (Сценарий A15)
        expect(postCallCount, 1);

        // Сегмент стал sent с полученным worklogId
        final segAfterReconcile = store.getSegments(draftId: draft.id).first;
        expect(segAfterReconcile.sendState, SendState.sent);
        expect(segAfterReconcile.jiraWorklogId, 'wl-created-on-server-77');

        // Исходный лог переведён в consumed
        expect(store.getLocalLog('log-reconcile')?.consumedAtUtc, fixedNow);
      },
    );

    test(
      'A15: Ручное разрешение unknown: привязка worklog ID и подтверждение отсутствия',
      () async {
        final log = LocalLog(
          id: 'log-manual',
          scope: testScope,
          issueId: '1001',
          titleSnapshot: 'Task Manual',
          accumulatedSeconds: 1800,
          createdAtUtc: DateTime.utc(2026, 9, 14, 8, 0),
        );
        store.upsertLocalLog(log);

        final draft = DayDraft(
          id: 'draft-manual',
          scope: testScope,
          date: '2026-09-14',
          startUtc: DateTime.utc(2026, 9, 14, 8, 0),
          endUtc: DateTime.utc(2026, 9, 14, 8, 30),
          seed: 42,
          settingsSnapshot: '{}',
        );
        final segment = Segment(
          id: 'seg-manual-1',
          draftId: draft.id,
          sourceLogId: 'log-manual',
          issueId: '1001',
          startUtc: DateTime.utc(2026, 9, 14, 8, 0),
          durationSeconds: 1800,
          sendState: SendState.unknown,
        );
        store.saveDayDraft(
          draft: draft,
          draftLogs: [
            DraftLog(
              draftId: draft.id,
              sourceLogId: 'log-manual',
              sourceDurationSeconds: 1800,
              descriptionSnapshot: '',
            ),
          ],
          segments: [segment],
          breaks: [],
        );

        final mockHttpClient = MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path.endsWith('/worklog/8888')) {
            // Валидный worklog
            return http.Response(
              jsonEncode({
                'id': '8888',
                'author': {'accountId': testAccountId},
                'started': '2026-09-14T08:00:00.000+0000',
                'timeSpentSeconds': 1800,
              }),
              200,
            );
          } else if (request.method == 'GET' &&
              request.url.path.endsWith('/worklog/7777')) {
            // Чужой worklog
            return http.Response(
              jsonEncode({
                'id': '7777',
                'author': {'accountId': 'other-account'},
                'started': '2026-09-14T08:00:00.000+0000',
                'timeSpentSeconds': 1800,
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        final sender = WorklogSender(
          store: store,
          jiraClient: JiraClient(client: mockHttpClient),
          nowProvider: () => fixedNow,
        );

        // 1. Попытка привязать чужой worklog отвергается
        final alienRes = await sender.manuallyLinkWorklog(
          segment: segment,
          worklogId: '7777',
          connection: testConnection,
          token: testToken,
        );
        expect(alienRes.isSuccess, isFalse);
        expect(alienRes.errorMessage, contains('другому пользователю'));

        // 2. Привязка правильного worklog 8888 успешна
        final validRes = await sender.manuallyLinkWorklog(
          segment: segment,
          worklogId: '8888',
          connection: testConnection,
          token: testToken,
        );
        expect(validRes.isSuccess, isTrue);

        final segAfterManual = store.getSegments(draftId: draft.id).first;
        expect(segAfterManual.sendState, SendState.sent);
        expect(segAfterManual.jiraWorklogId, '8888');
        expect(store.getLocalLog('log-manual')?.consumedAtUtc, isNotNull);

        // 3. Подтверждение отсутствия сбрасывает сегмент в pending для повтора
        final segUnknown = segAfterManual.copyWith(
          sendState: SendState.unknown,
        );
        store.updateSegment(segUnknown);

        sender.manuallyConfirmAbsenceAndAllowRetry(segment: segUnknown);

        final segPending = store.getSegments(draftId: draft.id).first;
        expect(segPending.sendState, SendState.pending);
        expect(segPending.lastError, contains('подтверждено отсутствие'));
      },
    );

    test('A17: Чужой account/site черновика блокирует отправку', () async {
      final draft = DayDraft(
        id: 'draft-other-site',
        scope: 'https://other-site.atlassian.net#other-user',
        date: '2026-09-14',
        startUtc: DateTime.utc(2026, 9, 14, 8, 0),
        endUtc: DateTime.utc(2026, 9, 14, 9, 0),
        seed: 42,
        settingsSnapshot: '{}',
      );
      store.saveDayDraft(draft: draft, draftLogs: [], segments: [], breaks: []);

      final sender = WorklogSender(
        store: store,
        jiraClient: JiraClient(
          client: MockClient((_) async => http.Response('OK', 200)),
        ),
      );

      final result = await sender.sendDraft(
        draft: draft,
        connection:
            testConnection, // scope: https://company.atlassian.net#acc-test-123
        token: testToken,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Несоответствие подключения'));
    });

    test(
      'A19: Авария после sending восстанавливается при перезапуске как unknown',
      () {
        final logCrash = LocalLog(
          id: 'log-crash',
          scope: testScope,
          issueId: '1001',
          titleSnapshot: 'Crash Task',
          accumulatedSeconds: 3600,
          createdAtUtc: DateTime.utc(2026, 9, 14, 8, 0),
        );
        store.upsertLocalLog(logCrash);

        final draft = DayDraft(
          id: 'draft-crash',
          scope: testScope,
          date: '2026-09-14',
          startUtc: DateTime.utc(2026, 9, 14, 8, 0),
          endUtc: DateTime.utc(2026, 9, 14, 9, 0),
          seed: 42,
          settingsSnapshot: '{}',
          status: DraftStatus.sending,
        );
        final segment = Segment(
          id: 'seg-crash',
          draftId: draft.id,
          sourceLogId: 'log-crash',
          issueId: '1001',
          startUtc: DateTime.utc(2026, 9, 14, 8, 0),
          durationSeconds: 3600,
          sendState: SendState.sending, // Завис в sending перед крушением
        );
        store.saveDayDraft(
          draft: draft,
          draftLogs: [],
          segments: [segment],
          breaks: [],
        );

        // Имитация запуска приложения: recoverUnfinishedSending
        store.recoverUnfinishedSending();

        final reloadedSeg = store.getSegments(draftId: draft.id).first;
        expect(reloadedSeg.sendState, SendState.unknown);
        expect(reloadedSeg.lastError, contains('восстановлено при запуске'));

        final reloadedDraft = store.getDayDraftById(draft.id);
        expect(reloadedDraft?.status, DraftStatus.draft);
      },
    );
  });
}
