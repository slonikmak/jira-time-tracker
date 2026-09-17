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
  group('AgentApiServer Split, Merge and Fixed Start Time (Issue 05)', () {
    late Database db;
    late LocalStore store;
    late ConnectionStore connectionStore;
    late AppState appState;
    late AgentApiServer server;
    late HttpClient client;

    const testScope = 'agent-split-merge-scope';

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

      server = AgentApiServer(appState: appState, initialPort: 0);
      await server.start();
    });

    tearDown(() async {
      client.close(force: true);
      await server.stop();
      appState.dispose();
      db.close();
    });

    test('POST /api/logs с fixed_start_time сохраняет фиксированное время начала', () async {
      final req = await client.postUrl(Uri.parse('${server.url}/api/logs'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'issue_key': 'EG-294',
        'duration_minutes': 30,
        'description': 'Daily standup',
        'fixed_start_time': '10:30',
      }));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.created));
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;

      expect(body['issue_key'], equals('EG-294'));
      expect(body['fixed_start_time'], equals('10:30'));
      expect(body['duration_seconds'], equals(1800));

      // Проверяем, что поле возвращается и через GET /api/logs
      final getReq = await client.getUrl(Uri.parse('${server.url}/api/logs'));
      final getRes = await getReq.close();
      final getBody = jsonDecode(await getRes.transform(utf8.decoder).join()) as List<dynamic>;

      expect(getBody.length, equals(1));
      expect(getBody.first['fixed_start_time'], equals('10:30'));
    });

    test('POST /api/logs/{id}/split делит лог на 2 части', () async {
      // 1. Создаем лог на 60 минут
      final issue = await appState.resolveOrCreateIssue('PROJ-101');
      final originalLog = await appState.addManualLog(
        issueId: issue.issueId,
        durationSeconds: 3600,
        description: 'Полная задача',
      );

      // 2. Вызываем эндпоинт разделения на 20 и 40 минут
      final req = await client.postUrl(Uri.parse('${server.url}/api/logs/${originalLog.id}/split'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'part1_minutes': 20,
        'part1_description': 'Часть 1: рефакторинг',
        'part2_description': 'Часть 2: тесты',
      }));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as List<dynamic>;

      expect(body.length, equals(2));
      final part1 = body[0] as Map<String, dynamic>;
      final part2 = body[1] as Map<String, dynamic>;

      expect(part1['id'], equals(originalLog.id));
      expect(part1['duration_seconds'], equals(1200));
      expect(part1['duration_minutes'], equals(20));
      expect(part1['description'], equals('Часть 1: рефакторинг'));

      expect(part2['id'], isNot(equals(originalLog.id)));
      expect(part2['duration_seconds'], equals(2400));
      expect(part2['duration_minutes'], equals(40));
      expect(part2['description'], equals('Часть 2: тесты'));

      // Проверяем состояние хранилища в AppState
      expect(appState.logs.length, equals(2));
    });

    test('POST /api/logs/{id}/split возвращает 400 при некорректном смещении', () async {
      final issue = await appState.resolveOrCreateIssue('PROJ-101');
      final originalLog = await appState.addManualLog(
        issueId: issue.issueId,
        durationSeconds: 1800,
      );

      // Смещение больше или равно длительности
      final req = await client.postUrl(Uri.parse('${server.url}/api/logs/${originalLog.id}/split'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'part1_seconds': 1800,
      }));
      final res = await req.close();
      expect(res.statusCode, equals(HttpStatus.badRequest));
    });

    test('POST /api/logs/merge объединяет несколько логов в один', () async {
      // 1. Создаем два лога
      final issue1 = await appState.resolveOrCreateIssue('PROJ-101');
      final issue2 = await appState.resolveOrCreateIssue('PROJ-102');

      final log1 = await appState.addManualLog(
        issueId: issue1.issueId,
        durationSeconds: 1800, // 30 мин
        description: 'Вводные исследования',
      );
      final log2 = await appState.addManualLog(
        issueId: issue2.issueId,
        durationSeconds: 3600, // 60 мин
        description: 'Реализация кода',
      );

      // 2. Объединяем их в PROJ-102
      final req = await client.postUrl(Uri.parse('${server.url}/api/logs/merge'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'source_log_ids': [log1.id, log2.id],
        'target_issue_key': 'PROJ-102',
        'description': 'Объединенная работа по PROJ-102',
      }));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;

      expect(body['issue_key'], equals('PROJ-102'));
      expect(body['duration_seconds'], equals(5400)); // 1800 + 3600
      expect(body['duration_minutes'], equals(90));
      expect(body['description'], equals('Объединенная работа по PROJ-102'));

      // В AppState остался 1 лог
      expect(appState.logs.length, equals(1));
      expect(appState.logs.first.accumulatedSeconds, equals(5400));
    });

    test('POST /api/logs/merge возвращает 400 если передано меньше 2 логов', () async {
      final req = await client.postUrl(Uri.parse('${server.url}/api/logs/merge'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'source_log_ids': ['single-log-id'],
      }));
      final res = await req.close();
      expect(res.statusCode, equals(HttpStatus.badRequest));
    });

    test('POST /api/day сохраняет is_fixed и fixed_start_time в сегментах', () async {
      final req = await client.postUrl(Uri.parse('${server.url}/api/day'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'date': '2026-09-17',
        'segments': [
          {
            'issue_key': 'PROJ-101',
            'start': '09:00',
            'duration_minutes': 90,
            'description': 'Плавающая разработка',
            'is_fixed': false,
          },
          {
            'issue_key': 'EG-294',
            'start': '11:00',
            'duration_minutes': 30,
            'description': 'Daily meeting',
            'is_fixed': true,
            'fixed_start_time': '11:00',
          },
        ],
      }));
      final res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));

      // Проверяем через GET /api/day
      final getReq = await client.getUrl(Uri.parse('${server.url}/api/day?date=2026-09-17'));
      final getRes = await getReq.close();
      final getBody = jsonDecode(await getRes.transform(utf8.decoder).join()) as Map<String, dynamic>;

      final draft = getBody['draft'] as Map<String, dynamic>;
      final segments = draft['segments'] as List<dynamic>;
      expect(segments.length, equals(2));

      final seg1 = segments[0] as Map<String, dynamic>;
      final seg2 = segments[1] as Map<String, dynamic>;

      expect(seg1['issue_key'], equals('PROJ-101'));
      expect(seg1['is_fixed'], isFalse);

      expect(seg2['issue_key'], equals('EG-294'));
      expect(seg2['is_fixed'], isTrue);
    });
  });
}
