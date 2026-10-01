import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jira_time_tracker/agent_api_server.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/agent_instructions.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('AgentApiServer Logs and Day Endpoints (Ticket 02)', () {
    late Database db;
    late LocalStore store;
    late ConnectionStore connectionStore;
    late AppState appState;
    late AgentApiServer server;
    late HttpClient client;
    late List<Map<String, dynamic>> jiraIssues;
    late List<Map<String, dynamic>> jiraWorklogs;
    late List<String> jiraQueries;
    late int jiraSearchStatus;
    late int jiraWorklogStatus;
    Completer<void>? jiraSearchGate;
    Completer<void>? jiraSearchStarted;

    const testScope = 'agent-test-scope';

    Future<Issue> ensureIssue(String key) async {
      final cached = store.getIssueByKey(testScope, key);
      if (cached != null) return cached;
      final issue = Issue(
        scope: testScope,
        issueId: key,
        key: key,
        summary: 'Summary for $key',
        status: 'Open',
        lastUsedAtUtc: DateTime.utc(2026, 9, 17),
      );
      store.upsertIssue(issue);
      await appState.loadIssues();
      return issue;
    }

    Future<LocalLog> addSource(
      String key,
      int seconds, {
      String description = '',
    }) async {
      final issue = await ensureIssue(key);
      return appState.addManualLog(
        issueId: issue.issueId,
        durationSeconds: seconds,
        description: description,
      );
    }

    Future<(int, Map<String, dynamic>)> postDay(
      Map<String, dynamic> body,
    ) async {
      final req = await client.postUrl(Uri.parse('${server.url}/api/day'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
      final res = await req.close();
      return (
        res.statusCode,
        jsonDecode(await res.transform(utf8.decoder).join())
            as Map<String, dynamic>,
      );
    }

    setUp(() async {
      db = sqlite3.openInMemory();
      store = LocalStore(db);
      store.init();
      connectionStore = ConnectionStore(
        secureStorage: InMemorySecureStorage(),
        environment: {},
      );
      client = HttpClient();
      jiraIssues = [];
      jiraWorklogs = [];
      jiraQueries = [];
      jiraSearchStatus = HttpStatus.ok;
      jiraWorklogStatus = HttpStatus.ok;
      jiraSearchGate = null;
      jiraSearchStarted = null;

      final conn = JiraConnection(
        baseUrl: 'https://example.atlassian.net',
        email: 'agent@example.com',
        accountId: 'acc-agent-1',
        displayName: 'Agent User',
        route: JiraAuthRoute.direct,
        scope: testScope,
      );
      await connectionStore.saveConnection(conn, 'token-123');

      appState = AppState(
        store: store,
        connectionStore: connectionStore,
        jiraClient: JiraClient(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/rest/api/3/search/jql')) {
              final query =
                  (jsonDecode(request.body) as Map<String, dynamic>)['jql']
                      as String;
              jiraQueries.add(query);
              jiraSearchStarted?.complete();
              await jiraSearchGate?.future;
              return http.Response(
                jsonEncode({'issues': jiraIssues, 'isLast': true}),
                jiraSearchStatus,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path.endsWith('/worklog')) {
              return http.Response(
                jsonEncode({
                  'startAt': 0,
                  'maxResults': 50,
                  'total': jiraWorklogs.length,
                  'worklogs': jiraWorklogs,
                }),
                jiraWorklogStatus,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response('{}', HttpStatus.notFound);
          }),
        ),
        isReadOnly: false,
        initialConnection: conn,
        nowProvider: () => DateTime.utc(2026, 9, 17, 12, 0),
      );

      // Стартуем сервер на порту 0 (динамический порт)
      server = AgentApiServer(appState: appState, initialPort: 0);
      await server.start();
    });

    tearDown(() async {
      client.close(force: true);
      await server.stop();
      appState.dispose();
      db.close();
    });

    test(
      'GET /api/day-settings возвращает диапазоны и правило одним ответом',
      () async {
        const settings = DaySettings(
          startMinutesMin: 9 * 60,
          startMinutesMax: 10 * 60,
        );
        appState.updateDaySettings(
          settings,
          agentRule: 'Начинай день после первого фактического лога.',
        );

        final req = await client.getUrl(
          Uri.parse('${server.url}/api/day-settings'),
        );
        final res = await req.close();
        final body =
            jsonDecode(await res.transform(utf8.decoder).join())
                as Map<String, dynamic>;

        expect(res.statusCode, HttpStatus.ok);
        expect(body['settings'], settings.toMap());
        expect(body['rule'], 'Начинай день после первого фактического лога.');
      },
    );

    test(
      'API localises help and defaults while preserving the custom rule',
      () async {
        Future<String> read(String path) async {
          final response = await (await client.getUrl(
            Uri.parse('${server.url}$path'),
          )).close();
          expect(response.statusCode, HttpStatus.ok);
          return response.transform(utf8.decoder).join();
        }

        appState.selectLanguage(UiLanguage.en);
        expect(
          jsonDecode(await read('/api/day-settings'))['rule'],
          defaultAgentDayRuleEn,
        );
        expect(
          await read('/api/help'),
          contains('Only the user submits final worklogs'),
        );
        appState.selectLanguage(UiLanguage.ru);
        expect(
          jsonDecode(await read('/api/day-settings'))['rule'],
          defaultAgentDayRuleRu,
        );
        expect(
          await read('/api/help'),
          contains('Финальную отправку worklogs'),
        );
        appState.updateDaySettings(
          const DaySettings(),
          agentRule: 'Мой порядок работы.',
        );
        appState.selectLanguage(UiLanguage.en);
        expect(
          jsonDecode(await read('/api/day-settings'))['rule'],
          'Мой порядок работы.',
        );
      },
    );

    test(
      'Старый снимок агента не воссоздаёт очищенный пользователем день',
      () async {
        final source = await addSource('CLEAR-1', 1800);
        final plan = {
          'date': '2026-09-17',
          'segments': [
            {
              'source_log_id': source.id,
              'start': '09:00',
              'duration_minutes': 30,
            },
          ],
        };
        final (createdStatus, created) = await postDay(plan);
        expect(createdStatus, HttpStatus.ok);
        appState.clearCurrentDay();

        final (staleStatus, _) = await postDay({
          ...plan,
          'base_revision': created['revision'],
        });
        expect(staleStatus, HttpStatus.conflict);
        expect(store.getDayDraft(scope: testScope, date: '2026-09-17'), isNull);
        expect(store.getLocalLog(source.id), isNotNull);
      },
    );

    test('POST /api/logs создает лог времени и возвращает 201', () async {
      await ensureIssue('PROJ-101');
      final req = await client.postUrl(Uri.parse('${server.url}/api/logs'));
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'issue_key': 'PROJ-101',
          'duration_minutes': 45,
          'description': 'Анализ архитектуры агента',
        }),
      );
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.created));
      final body =
          jsonDecode(await res.transform(utf8.decoder).join())
              as Map<String, dynamic>;

      expect(body['issue_key'], equals('PROJ-101'));
      expect(body['duration_seconds'], equals(45 * 60));
      expect(body['duration_minutes'], equals(45));
      expect(body['description'], equals('Анализ архитектуры агента'));
      expect(body['id'], isNotEmpty);

      // Проверяем, что лог появился в AppState
      expect(appState.logs.length, equals(1));
      expect(appState.logs.first.accumulatedSeconds, equals(45 * 60));
    });

    test(
      'POST /api/logs не создаёт fallback issue при неизвестном Jira ref',
      () async {
        final req = await client.postUrl(Uri.parse('${server.url}/api/logs'));
        req.headers.contentType = ContentType.json;
        req.write(
          jsonEncode({'issue_key': 'UNKNOWN-404', 'duration_minutes': 30}),
        );
        final res = await req.close();

        expect(res.statusCode, equals(HttpStatus.notFound));
        expect(store.getIssueByKey(testScope, 'UNKNOWN-404'), isNull);
        expect(appState.logs, isEmpty);
      },
    );

    test(
      'POST /api/logs/merge rejects an unknown target without fallback issue',
      () async {
        final source1 = await addSource('MERGE-1', 600);
        final source2 = await addSource('MERGE-2', 600);
        final req = await client.postUrl(
          Uri.parse('${server.url}/api/logs/merge'),
        );
        req.headers.contentType = ContentType.json;
        req.write(
          jsonEncode({
            'source_log_ids': [source1.id, source2.id],
            'target_issue_key': 'UNKNOWN-404',
          }),
        );
        final res = await req.close();

        expect(res.statusCode, equals(HttpStatus.notFound));
        expect(store.getIssueByKey(testScope, 'UNKNOWN-404'), isNull);
        expect(
          appState.logs.map((log) => log.id),
          containsAll([source1.id, source2.id]),
        );
      },
    );

    test('GET /api/logs возвращает список неотправленных логов', () async {
      await addSource('PROJ-202', 1800, description: 'Лог 1');
      await addSource('PROJ-202', 3600, description: 'Лог 2');

      final req = await client.getUrl(Uri.parse('${server.url}/api/logs'));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as List;

      expect(body.length, equals(2));
      expect(body[0]['issue_key'], equals('PROJ-202'));
      expect(body[0]['duration_minutes'], equals(30));
      expect(body[1]['duration_minutes'], equals(60));
    });

    test(
      'PATCH /api/logs/{id} и DELETE /api/logs/{id} обновляют и удаляют лог',
      () async {
        final log = await addSource(
          'PROJ-303',
          1200,
          description: 'Первоначальное описание',
        );

        // PATCH: меняем на 40 минут и новое описание
        final patchReq = await client.openUrl(
          'PATCH',
          Uri.parse('${server.url}/api/logs/${log.id}'),
        );
        patchReq.headers.contentType = ContentType.json;
        patchReq.write(
          jsonEncode({
            'duration_minutes': 40,
            'description': 'Обновленное описание',
          }),
        );
        final patchRes = await patchReq.close();
        expect(patchRes.statusCode, equals(HttpStatus.ok));

        final updatedLog = appState.logs.firstWhere((l) => l.id == log.id);
        expect(updatedLog.accumulatedSeconds, equals(40 * 60));
        expect(updatedLog.description, equals('Обновленное описание'));

        // DELETE: удаляем лог
        final delReq = await client.deleteUrl(
          Uri.parse('${server.url}/api/logs/${log.id}'),
        );
        final delRes = await delReq.close();
        expect(delRes.statusCode, equals(HttpStatus.ok));

        expect(appState.logs.any((l) => l.id == log.id), isFalse);
      },
    );

    test(
      'POST /api/day сохраняет расписание дня от агента, валидирует и обновляет черновик',
      () async {
        final source1 = await addSource(
          'TASK-1',
          3600,
          description: 'Источник 1',
        );
        final source2 = await addSource(
          'TASK-2',
          5400,
          description: 'Источник 2',
        );
        final req = await client.postUrl(Uri.parse('${server.url}/api/day'));
        req.headers.contentType = ContentType.json;
        req.write(
          jsonEncode({
            'date': '2026-09-17',
            'segments': [
              {
                'source_log_id': source1.id,
                'issue_key': 'TASK-1',
                'start': '09:00',
                'duration_minutes': 60,
                'description': 'Утренняя задача 1',
              },
              {
                'source_log_id': source2.id,
                'issue_key': 'TASK-2',
                'start': '10:30',
                'duration_minutes': 90,
                'description': 'Вторая задача дня',
              },
            ],
          }),
        );
        final res = await req.close();

        expect(res.statusCode, equals(HttpStatus.ok));
        final body =
            jsonDecode(await res.transform(utf8.decoder).join())
                as Map<String, dynamic>;

        expect(body['date'], equals('2026-09-17'));
        expect(body['segments_count'], equals(2));
        expect(body['total_work_minutes'], equals(150));

        // Проверяем состояние AppState
        expect(appState.currentDraft, isNotNull);
        expect(appState.currentSegments.length, equals(2));
        expect(appState.currentSegments[0].durationSeconds, equals(3600));
        expect(appState.currentSegments[1].durationSeconds, equals(5400));

        // Между 10:00 и 10:30 появилась вычисленная пауза в 30 минут
        expect(appState.currentBreaks.length, equals(1));
        expect(appState.currentBreaks.first.durationSeconds, equals(1800));
      },
    );

    test(
      'POST /api/day сохраняет два сегмента одного источника с одной DraftLog',
      () async {
        final source = await addSource(
          'TASK-42',
          1800,
          description: 'Исходная работа',
        );

        final req = await client.postUrl(Uri.parse('${server.url}/api/day'));
        req.headers.contentType = ContentType.json;
        req.write(
          jsonEncode({
            'date': '2026-09-17',
            'segments': [
              {
                'source_log_id': source.id,
                'issue_key': 'TASK-42',
                'start': '09:00',
                'duration_minutes': 10,
                'description': 'Первая часть',
              },
              {
                'source_log_id': source.id,
                'issue_key': 'TASK-42',
                'start': '09:15',
                'duration_minutes': 15,
                'description': 'Вторая часть',
              },
            ],
          }),
        );
        final res = await req.close();

        expect(res.statusCode, equals(HttpStatus.ok));
        final draft = store.getDayDraft(scope: testScope, date: '2026-09-17')!;
        expect(store.getDraftLogs(draftId: draft.id), hasLength(1));
        expect(
          store.getDraftLogs(draftId: draft.id).single.sourceDurationSeconds,
          equals(1800),
        );
        final segments = store.getSegments(draftId: draft.id);
        expect(segments, hasLength(2));
        expect(
          segments.map((segment) => segment.sourceLogId),
          everyElement(source.id),
        );
        expect(segments.map((segment) => segment.durationSeconds), [600, 900]);
      },
    );

    test(
      'GET /api/issues и GET /api/logs ищут очередь и показывают availability',
      () async {
        final free = await addSource(
          'FIND-1',
          600,
          description: 'needle detail',
        );
        final inDraft = await addSource(
          'FIND-2',
          1200,
          description: 'reserved',
        );
        final runningIssue = await ensureIssue('FIND-3');
        final running = await appState.playTimer(runningIssue.issueId);
        final dayDraft = DayDraft(
          id: 'search-draft',
          scope: testScope,
          date: '2026-09-17',
          startUtc: DateTime.utc(2026, 9, 17, 9),
          endUtc: DateTime.utc(2026, 9, 17, 9, 20),
          seed: 0,
          settingsSnapshot: '{}',
        );
        store.saveDayDraft(
          draft: dayDraft,
          draftLogs: [
            DraftLog(
              draftId: dayDraft.id,
              sourceLogId: inDraft.id,
              sourceDurationSeconds: inDraft.accumulatedSeconds,
              descriptionSnapshot: inDraft.description,
            ),
          ],
          segments: [
            Segment(
              id: 'search-segment',
              draftId: dayDraft.id,
              sourceLogId: inDraft.id,
              issueId: inDraft.issueId,
              startUtc: DateTime.utc(2026, 9, 17, 9),
              durationSeconds: 1200,
            ),
          ],
          breaks: [],
        );
        await appState.loadLogs();

        final freeReq = await client.getUrl(
          Uri.parse('${server.url}/api/logs?availability=free'),
        );
        final freeRes = await freeReq.close();
        final freeBody =
            jsonDecode(await freeRes.transform(utf8.decoder).join())
                as List<dynamic>;
        expect(freeBody, hasLength(1));
        expect((freeBody.single as Map<String, dynamic>)['id'], free.id);

        final inDraftReq = await client.getUrl(
          Uri.parse('${server.url}/api/logs?availability=in_draft'),
        );
        final inDraftRes = await inDraftReq.close();
        final inDraftBody =
            jsonDecode(await inDraftRes.transform(utf8.decoder).join())
                as List<dynamic>;
        expect(inDraftBody, hasLength(1));
        expect(inDraftBody.single['id'], inDraft.id);
        expect(inDraftBody.single['draft_date'], '2026-09-17');

        final issueFilterReq = await client.getUrl(
          Uri.parse('${server.url}/api/logs?issue_key=FIND-2'),
        );
        final issueFilterRes = await issueFilterReq.close();
        final issueFilterBody =
            jsonDecode(await issueFilterRes.transform(utf8.decoder).join())
                as List<dynamic>;
        expect(issueFilterBody.map((entry) => entry['id']), [inDraft.id]);

        final runningReq = await client.getUrl(
          Uri.parse('${server.url}/api/logs?availability=running'),
        );
        final runningRes = await runningReq.close();
        final runningBody =
            jsonDecode(await runningRes.transform(utf8.decoder).join())
                as List<dynamic>;
        expect(runningBody, hasLength(1));
        expect(runningBody.single['id'], running.id);

        final searchReq = await client.getUrl(
          Uri.parse('${server.url}/api/logs?q=needle'),
        );
        final searchRes = await searchReq.close();
        final searchBody =
            jsonDecode(await searchRes.transform(utf8.decoder).join())
                as List<dynamic>;
        expect(searchBody.map((entry) => entry['id']), [free.id]);

        final issueReq = await client.getUrl(
          Uri.parse('${server.url}/api/issues?q=FIND-1'),
        );
        final issueRes = await issueReq.close();
        final issueBody =
            jsonDecode(await issueRes.transform(utf8.decoder).join())
                as List<dynamic>;
        expect(issueBody.single['issue_key'], 'FIND-1');
        expect(issueBody.single['status'], 'Open');

        for (final query in ['Summary for FIND-1', 'Open']) {
          final request = await client.getUrl(
            Uri.parse(
              '${server.url}/api/issues?q=${Uri.encodeQueryComponent(query)}',
            ),
          );
          final response = await request.close();
          final matches =
              jsonDecode(await response.transform(utf8.decoder).join())
                  as List<dynamic>;
          expect(matches, isNotEmpty, reason: 'query should search $query');
        }
      },
    );

    test(
      'GET /api/day читает свежие worklogs только указанной даты и явно сообщает Jira error',
      () async {
        jiraIssues = [
          {
            'id': 'jira-issue-1',
            'key': 'JRA-1',
            'fields': {'summary': 'Jira issue'},
          },
        ];
        jiraWorklogs = [
          {
            'id': 'worklog-sept-17',
            'issueId': 'jira-issue-1',
            'author': {'accountId': 'acc-agent-1', 'displayName': 'Agent User'},
            'started': '2026-09-17T09:00:00.000+0000',
            'timeSpentSeconds': 1800,
            'comment': 'Existing work',
          },
        ];
        final selectedDateBefore = appState.selectedDate;

        final sept17Req = await client.getUrl(
          Uri.parse('${server.url}/api/day?date=2026-09-17'),
        );
        final sept17Res = await sept17Req.close();
        final sept17Body =
            jsonDecode(await sept17Res.transform(utf8.decoder).join())
                as Map<String, dynamic>;
        expect(sept17Body['existing_worklogs'], hasLength(1));
        expect(sept17Body['existing_worklogs'].single['id'], 'worklog-sept-17');

        final sept18Req = await client.getUrl(
          Uri.parse('${server.url}/api/day?date=2026-09-18'),
        );
        final sept18Res = await sept18Req.close();
        final sept18Body =
            jsonDecode(await sept18Res.transform(utf8.decoder).join())
                as Map<String, dynamic>;
        expect(sept18Body['existing_worklogs'], isEmpty);
        expect(jiraQueries[0], contains("worklogDate >= '2026-09-16'"));
        expect(jiraQueries[1], contains("worklogDate >= '2026-09-17'"));
        expect(appState.selectedDate, selectedDateBefore);

        jiraWorklogs = [
          {
            'id': 'winter-boundary-worklog',
            'issueId': 'jira-issue-1',
            'author': {'accountId': 'acc-agent-1', 'displayName': 'Agent User'},
            'started': '2026-01-16T22:30:00.000+0000',
            'timeSpentSeconds': 1800,
            'comment': 'Outside winter local day',
          },
        ];
        final winterReq = await client.getUrl(
          Uri.parse('${server.url}/api/day?date=2026-01-17'),
        );
        final winterRes = await winterReq.close();
        final winterBody =
            jsonDecode(await winterRes.transform(utf8.decoder).join())
                as Map<String, dynamic>;
        expect(winterBody['existing_worklogs'], isEmpty);

        jiraSearchStatus = HttpStatus.internalServerError;
        final errorReq = await client.getUrl(
          Uri.parse('${server.url}/api/day?date=2026-09-19'),
        );
        final errorRes = await errorReq.close();
        expect(errorRes.statusCode, equals(HttpStatus.badGateway));
        expect(
          jsonDecode(await errorRes.transform(utf8.decoder).join())['error'],
          contains('Jira'),
        );
      },
    );

    test(
      'GET /api/day выдаёт сегменты и revision из одного согласованного snapshot',
      () async {
        final source = await addSource('RACE-1', 1800, description: 'source');
        final draft = DayDraft(
          id: 'race-draft',
          scope: testScope,
          date: '2026-09-17',
          startUtc: DateTime.utc(2026, 9, 17, 9),
          endUtc: DateTime.utc(2026, 9, 17, 9, 30),
          seed: 0,
          settingsSnapshot: '{}',
        );
        final segment = Segment(
          id: 'race-segment',
          draftId: draft.id,
          sourceLogId: source.id,
          issueId: source.issueId,
          startUtc: DateTime.utc(2026, 9, 17, 9),
          durationSeconds: 1800,
          description: 'before edit',
        );
        store.saveDayDraft(
          draft: draft,
          draftLogs: [
            DraftLog(
              draftId: draft.id,
              sourceLogId: source.id,
              sourceDurationSeconds: source.accumulatedSeconds,
              descriptionSnapshot: source.description,
            ),
          ],
          segments: [segment],
          breaks: [],
        );
        jiraSearchGate = Completer<void>();
        jiraSearchStarted = Completer<void>();
        final req = await client.getUrl(
          Uri.parse('${server.url}/api/day?date=2026-09-17'),
        );
        final responseFuture = req.close();
        await jiraSearchStarted!.future;
        store.updateSegment(
          segment.copyWith(description: 'manual edit during Jira read'),
        );
        jiraSearchGate!.complete();
        final res = await responseFuture;
        final body =
            jsonDecode(await res.transform(utf8.decoder).join())
                as Map<String, dynamic>;
        expect(
          body['draft']['segments'].single['description'],
          'manual edit during Jira read',
        );
        expect(
          body['revision'],
          appState.dayDraftRevision(
            store.getDayDraft(scope: testScope, date: '2026-09-17')!,
          ),
        );
        expect(body['draft']['revision'], body['revision']);
      },
    );

    test(
      'POST /api/day включает непересекающиеся Jira worklogs в границы дня',
      () async {
        jiraIssues = [
          {
            'id': 'jira-existing-issue',
            'key': 'JRA-EXISTING',
            'fields': {'summary': 'Existing Jira work'},
          },
        ];
        jiraWorklogs = [
          {
            'id': 'existing-before-agent-segment',
            'issueId': 'jira-existing-issue',
            'author': {'accountId': 'acc-agent-1', 'displayName': 'Agent User'},
            'started': '2026-09-17T08:00:00.000+0000',
            'timeSpentSeconds': 1800,
            'comment': 'Already in Jira',
          },
        ];
        final source = await addSource('AFTER-JIRA', 1800);

        final (status, _) = await postDay({
          'date': '2026-09-17',
          'segments': [
            {
              'source_log_id': source.id,
              'start': '11:00',
              'duration_minutes': 30,
            },
          ],
        });

        expect(status, HttpStatus.ok);
        final draft = store.getDayDraft(scope: testScope, date: '2026-09-17')!;
        final existingStart = DateTime.utc(2026, 9, 17, 8);
        final existingEnd = existingStart.add(const Duration(minutes: 30));
        final segmentStart = DateTime(2026, 9, 17, 11).toUtc();
        final segmentEnd = segmentStart.add(const Duration(minutes: 30));
        expect(
          draft.startUtc,
          existingStart.isBefore(segmentStart) ? existingStart : segmentStart,
        );
        expect(
          draft.endUtc,
          existingEnd.isAfter(segmentEnd) ? existingEnd : segmentEnd,
        );
      },
    );

    test(
      'POST /api/day rejects missing, running, consumed, cross-date, and out-of-day sources atomically',
      () async {
        final issue = await ensureIssue('SOURCE-1');
        final running = await appState.playTimer(issue.issueId);
        final consumed = await addSource('SOURCE-1', 600);
        store.upsertLocalLog(
          consumed.copyWith(consumedAtUtc: DateTime.utc(2026, 9, 17, 13)),
        );
        final inOtherDraft = await addSource('SOURCE-1', 1200);
        final otherDraft = DayDraft(
          id: 'other-date-draft',
          scope: testScope,
          date: '2026-09-16',
          startUtc: DateTime.utc(2026, 9, 16, 9),
          endUtc: DateTime.utc(2026, 9, 16, 9, 20),
          seed: 0,
          settingsSnapshot: '{}',
        );
        store.saveDayDraft(
          draft: otherDraft,
          draftLogs: [
            DraftLog(
              draftId: otherDraft.id,
              sourceLogId: inOtherDraft.id,
              sourceDurationSeconds: inOtherDraft.accumulatedSeconds,
              descriptionSnapshot: inOtherDraft.description,
            ),
          ],
          segments: [
            Segment(
              id: 'other-date-segment',
              draftId: otherDraft.id,
              sourceLogId: inOtherDraft.id,
              issueId: inOtherDraft.issueId,
              startUtc: DateTime.utc(2026, 9, 16, 9),
              durationSeconds: 1200,
            ),
          ],
          breaks: [],
        );
        final invalidSnapshots = [
          {
            'source_log_id': 'missing-id',
            'issue_key': 'SOURCE-1',
            'start': '09:00',
            'duration_minutes': 10,
          },
          {
            'source_log_id': running.id,
            'start': '09:00',
            'duration_minutes': 10,
          },
          {
            'source_log_id': consumed.id,
            'start': '09:00',
            'duration_minutes': 10,
          },
          {
            'source_log_id': inOtherDraft.id,
            'start': '09:00',
            'duration_minutes': 10,
          },
        ];
        for (final segment in invalidSnapshots) {
          final (status, _) = await postDay({
            'date': '2026-09-17',
            'segments': [segment],
          });
          expect(status, equals(HttpStatus.badRequest));
          expect(
            store.getDayDraft(scope: testScope, date: '2026-09-17'),
            isNull,
          );
        }

        final validSource = await addSource('SOURCE-1', 1800);
        final (mismatchedKeyStatus, _) = await postDay({
          'date': '2026-09-17',
          'segments': [
            {
              'source_log_id': validSource.id,
              'issue_key': 'WRONG-KEY',
              'start': '09:00',
              'duration_minutes': 30,
            },
          ],
        });
        expect(mismatchedKeyStatus, equals(HttpStatus.badRequest));
        expect(store.getDayDraft(scope: testScope, date: '2026-09-17'), isNull);
        for (final start in ['2026-09-18T09:00:00+02:00', '23:45']) {
          final (status, _) = await postDay({
            'date': '2026-09-17',
            'segments': [
              {
                'source_log_id': validSource.id,
                'start': start,
                'duration_minutes': 30,
              },
            ],
          });
          expect(status, equals(HttpStatus.badRequest));
          expect(
            store.getDayDraft(scope: testScope, date: '2026-09-17'),
            isNull,
          );
        }
      },
    );

    test(
      'POST /api/day uses target-date draft and rejects stale revisions without mutation',
      () async {
        final source1 = await addSource('TARGET-1', 1800);
        final (firstStatus, firstBody) = await postDay({
          'date': '2026-09-17',
          'segments': [
            {
              'source_log_id': source1.id,
              'start': '09:00',
              'duration_minutes': 30,
            },
          ],
        });
        expect(firstStatus, equals(HttpStatus.ok));
        final firstDraft = store.getDayDraft(
          scope: testScope,
          date: '2026-09-17',
        )!;
        expect(firstBody['revision'], isNotEmpty);

        final edited = store
            .getSegments(draftId: firstDraft.id)
            .single
            .copyWith(description: 'manual edit');
        store.updateSegment(edited);
        final (missingRevisionStatus, _) = await postDay({
          'date': '2026-09-17',
          'segments': [
            {
              'source_log_id': source1.id,
              'start': '09:00',
              'duration_minutes': 30,
              'description': 'agent overwrite',
            },
          ],
        });
        expect(missingRevisionStatus, equals(HttpStatus.conflict));
        final (staleStatus, _) = await postDay({
          'date': '2026-09-17',
          'base_revision': firstBody['revision'],
          'segments': [
            {
              'source_log_id': source1.id,
              'start': '09:00',
              'duration_minutes': 30,
              'description': 'agent overwrite',
            },
          ],
        });
        expect(staleStatus, equals(HttpStatus.conflict));
        expect(
          store.getSegments(draftId: firstDraft.id).single.description,
          'manual edit',
        );

        final source2 = await addSource('TARGET-2', 1800);
        final (secondStatus, _) = await postDay({
          'date': '2026-09-18',
          'segments': [
            {
              'source_log_id': source2.id,
              'start': '09:00',
              'duration_minutes': 30,
            },
          ],
        });
        expect(secondStatus, equals(HttpStatus.ok));
        final secondDraft = store.getDayDraft(
          scope: testScope,
          date: '2026-09-18',
        )!;
        expect(secondDraft.id, isNot(firstDraft.id));
        expect(
          store.getDayDraft(scope: testScope, date: '2026-09-17')!.id,
          firstDraft.id,
        );
      },
    );

    test(
      'GET /api/issues/{key}/worklogs читает все видимые записи тикета',
      () async {
        await ensureIssue('TASK-1');
        jiraWorklogs = [
          {
            'id': 'newer',
            'author': {'accountId': 'other-account'},
            'started': '2026-09-17T10:00:00.000+0000',
            'timeSpentSeconds': 3600,
            'comment': 'Работа коллеги',
          },
          {
            'id': 'older',
            'author': {'accountId': 'acc-agent-1'},
            'started': '2025-04-02T09:00:00.000+0000',
            'timeSpentSeconds': 10800,
            'comment': 'Моя работа',
          },
        ];

        final request = await client.getUrl(
          Uri.parse('${server.url}/api/issues/TASK-1/worklogs'),
        );
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);
        final body =
            jsonDecode(await response.transform(utf8.decoder).join())
                as Map<String, dynamic>;
        expect(body['issue_key'], 'TASK-1');
        final worklogs = body['worklogs'] as List<dynamic>;
        expect(worklogs.map((w) => w['id']), ['older', 'newer']);
        expect(worklogs.first['duration_seconds'], 10800);
        expect(worklogs.first['comment'], 'Моя работа');
        expect(worklogs.first['is_mine'], isTrue);
        expect(worklogs.last['is_mine'], isFalse);

        jiraWorklogStatus = HttpStatus.internalServerError;
        final failedRequest = await client.getUrl(
          Uri.parse('${server.url}/api/issues/TASK-1/worklogs'),
        );
        final failedResponse = await failedRequest.close();
        expect(failedResponse.statusCode, HttpStatus.badGateway);
      },
    );

    test(
      'POST /api/day сохраняет параллельные сегменты рядом с Jira worklog',
      () async {
        final source1 = await addSource('TASK-1', 3600);
        final source2 = await addSource('TASK-2', 3600);
        jiraIssues = [
          {
            'id': 'TASK-1',
            'key': 'TASK-1',
            'fields': {'summary': 'Existing Jira issue'},
          },
        ];
        jiraWorklogs = [
          {
            'id': 'jira-overlap',
            'author': {'accountId': 'acc-agent-1'},
            'started': '2026-09-17T09:15:00.000+0000',
            'timeSpentSeconds': 1800,
          },
        ];
        final req = await client.postUrl(Uri.parse('${server.url}/api/day'));
        req.headers.contentType = ContentType.json;
        req.write(
          jsonEncode({
            'date': '2026-09-17',
            'segments': [
              {
                'source_log_id': source1.id,
                'issue_key': 'TASK-1',
                'start': '09:00',
                'duration_minutes': 60,
              },
              {
                'source_log_id': source2.id,
                'issue_key': 'TASK-2',
                'start': '09:30',
                'duration_minutes': 60,
              },
            ],
          }),
        );
        final res = await req.close();

        expect(res.statusCode, equals(HttpStatus.ok));
        expect(appState.currentSegments, hasLength(2));
        expect(appState.validationErrors, isEmpty);
        expect(appState.importedWorklogs.single.id, 'jira-overlap');
      },
    );
  });
}
