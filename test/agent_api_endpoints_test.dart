import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:jira_time_tracker/agent_api_server.dart';
import 'package:jira_time_tracker/app_state.dart';
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

    const testScope = 'agent-test-scope';

    setUp(() async {
      db = sqlite3.openInMemory();
      store = LocalStore(db);
      store.init();
      connectionStore = ConnectionStore(
        secureStorage: InMemorySecureStorage(),
        environment: {},
      );
      client = HttpClient();

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
        jiraClient: JiraClient(),
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

    test('POST /api/logs создает лог времени и возвращает 201', () async {
      final req = await client.postUrl(Uri.parse('${server.url}/api/logs'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'issue_key': 'PROJ-101',
        'duration_minutes': 45,
        'description': 'Анализ архитектуры агента',
      }));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.created));
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;

      expect(body['issue_key'], equals('PROJ-101'));
      expect(body['duration_seconds'], equals(45 * 60));
      expect(body['duration_minutes'], equals(45));
      expect(body['description'], equals('Анализ архитектуры агента'));
      expect(body['id'], isNotEmpty);

      // Проверяем, что лог появился в AppState
      expect(appState.logs.length, equals(1));
      expect(appState.logs.first.accumulatedSeconds, equals(45 * 60));
    });

    test('GET /api/logs возвращает список неотправленных логов', () async {
      // Создаем задачу и пару логов
      final issue = await appState.resolveOrCreateIssue('PROJ-202');
      await appState.addManualLog(
        issueId: issue.issueId,
        durationSeconds: 1800,
        description: 'Лог 1',
      );
      await appState.addManualLog(
        issueId: issue.issueId,
        durationSeconds: 3600,
        description: 'Лог 2',
      );

      final req = await client.getUrl(Uri.parse('${server.url}/api/logs'));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as List;

      expect(body.length, equals(2));
      expect(body[0]['issue_key'], equals('PROJ-202'));
      expect(body[0]['duration_minutes'], equals(30));
      expect(body[1]['duration_minutes'], equals(60));
    });

    test('PATCH /api/logs/{id} и DELETE /api/logs/{id} обновляют и удаляют лог', () async {
      final issue = await appState.resolveOrCreateIssue('PROJ-303');
      final log = await appState.addManualLog(
        issueId: issue.issueId,
        durationSeconds: 1200,
        description: 'Первоначальное описание',
      );

      // PATCH: меняем на 40 минут и новое описание
      final patchReq = await client.openUrl('PATCH', Uri.parse('${server.url}/api/logs/${log.id}'));
      patchReq.headers.contentType = ContentType.json;
      patchReq.write(jsonEncode({
        'duration_minutes': 40,
        'description': 'Обновленное описание',
      }));
      final patchRes = await patchReq.close();
      expect(patchRes.statusCode, equals(HttpStatus.ok));

      final updatedLog = appState.logs.firstWhere((l) => l.id == log.id);
      expect(updatedLog.accumulatedSeconds, equals(40 * 60));
      expect(updatedLog.description, equals('Обновленное описание'));

      // DELETE: удаляем лог
      final delReq = await client.deleteUrl(Uri.parse('${server.url}/api/logs/${log.id}'));
      final delRes = await delReq.close();
      expect(delRes.statusCode, equals(HttpStatus.ok));

      expect(appState.logs.any((l) => l.id == log.id), isFalse);
    });

    test('POST /api/day сохраняет расписание дня от агента, валидирует и обновляет черновик', () async {
      final req = await client.postUrl(Uri.parse('${server.url}/api/day'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'date': '2026-09-17',
        'segments': [
          {
            'issue_key': 'TASK-1',
            'start': '09:00',
            'duration_minutes': 60,
            'description': 'Утренняя задача 1',
          },
          {
            'issue_key': 'TASK-2',
            'start': '10:30',
            'duration_minutes': 90,
            'description': 'Вторая задача дня',
          }
        ]
      }));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;

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
    });

    test('POST /api/day отклоняет пересекающиеся сегменты (400 Bad Request)', () async {
      final req = await client.postUrl(Uri.parse('${server.url}/api/day'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'date': '2026-09-17',
        'segments': [
          {
            'issue_key': 'TASK-1',
            'start': '09:00',
            'duration_minutes': 60, // до 10:00
          },
          {
            'issue_key': 'TASK-2',
            'start': '09:30', // ПЕРЕСЕЧЕНИЕ с первой!
            'duration_minutes': 60,
          }
        ]
      }));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.badRequest));
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
      expect(body['error'], contains('пересечени'));
    });
  });
}
