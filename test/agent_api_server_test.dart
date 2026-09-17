import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:jira_time_tracker/agent_api_server.dart';

void main() {
  group('AgentApiServer Core & Discovery (Ticket 01)', () {
    late AgentApiServer server;
    late HttpClient client;

    setUp(() {
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.stop();
    });

    test('Запускается на loopback интерфейсе и останавливается', () async {
      server = AgentApiServer(initialPort: 0); // 0 = порт назначается ОС для изолированного теста
      await server.start();

      expect(server.isRunning, isTrue);
      expect(server.port, greaterThan(0));
      expect(server.url, startsWith('http://127.0.0.1:'));
    });

    test('Отвечает на GET /api/help понятной справкой', () async {
      server = AgentApiServer(initialPort: 0);
      await server.start();

      final req = await client.getUrl(Uri.parse('${server.url}/api/help'));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      expect(res.headers.contentType?.mimeType, equals('text/markdown'));

      final body = await res.transform(utf8.decoder).join();
      expect(body, contains('Jira Time Tracker Local Agent API'));
      expect(body, contains('/api/logs'));
      expect(body, contains('/api/day'));
      expect(body, contains('curl'));
    });

    test('Отвечает на GET /api/openapi.json валидной спецификацией OpenAPI 3.0', () async {
      server = AgentApiServer(initialPort: 0);
      await server.start();

      final req = await client.getUrl(Uri.parse('${server.url}/api/openapi.json'));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      expect(res.headers.contentType?.mimeType, equals('application/json'));

      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      expect(json['openapi'], equals('3.0.0'));
      expect(json['info']['title'], equals('Jira Time Tracker Agent API'));
      expect(json['paths'], contains('/api/logs'));
      expect(json['paths'], contains('/api/day'));
      expect(json['paths'], contains('/api/service-tickets'));
    });

    test('Отвечает на GET /api/service-tickets списком всех служебных тикетов компании', () async {
      server = AgentApiServer(initialPort: 0);
      await server.start();

      final req = await client.getUrl(Uri.parse('${server.url}/api/service-tickets'));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.ok));
      expect(res.headers.contentType?.mimeType, equals('application/json'));

      final body = await res.transform(utf8.decoder).join();
      final list = jsonDecode(body) as List<dynamic>;

      expect(list.length, equals(18));
      final first = list.first as Map<String, dynamic>;
      expect(first['key'], equals('EG-294'));
      expect(first['category'], contains('Meeting'));
      expect(first['description'], contains('Созвоны'));

      final hr = list.firstWhere((t) => t['key'] == 'EG-304') as Map<String, dynamic>;
      expect(hr['category'], equals('Recruiting'));
    });

    test('Обрабатывает CORS preflight (OPTIONS)', () async {
      server = AgentApiServer(initialPort: 0);
      await server.start();

      final req = await client.openUrl('OPTIONS', Uri.parse('${server.url}/api/logs'));
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.noContent));
      expect(res.headers.value('access-control-allow-origin'), equals('*'));
      expect(res.headers.value('access-control-allow-methods'), contains('POST'));
    });
  });
}
