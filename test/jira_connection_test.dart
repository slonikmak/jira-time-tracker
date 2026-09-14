import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';

void main() {
  group('ConnectionStore (Сценарий A16)', () {
    late SecureStorage secureStorage;

    setUp(() {
      secureStorage = InMemorySecureStorage();
    });

    test('Env vars populate form when no saved credentials exist', () async {
      final env = {
        'JIRA_BASE_URL': 'https://custom.atlassian.net',
        'JIRA_EMAIL': 'agent@example.com',
        'JIRA_TOKEN': 'env_secret_token',
      };

      final store = ConnectionStore(
        secureStorage: secureStorage,
        environment: env,
      );
      final form = await store.loadForm();

      expect(form.baseUrl, equals('https://custom.atlassian.net'));
      expect(form.email, equals('agent@example.com'));
      expect(form.token, equals('env_secret_token'));
    });

    test(
      'Falls back to defaultBaseUrl when JIRA_BASE_URL is not set',
      () async {
        final store = ConnectionStore(
          secureStorage: secureStorage,
          environment: {},
        );
        final form = await store.loadForm();

        expect(form.baseUrl, equals(ConnectionStore.defaultBaseUrl));
        expect(form.email, isEmpty);
        expect(form.token, isEmpty);
      },
    );

    test('Saved input wins over environment variables', () async {
      final env = {
        'JIRA_BASE_URL': 'https://env.atlassian.net',
        'JIRA_EMAIL': 'env@example.com',
        'JIRA_TOKEN': 'env_token',
      };

      final store = ConnectionStore(
        secureStorage: secureStorage,
        environment: env,
      );

      // Сохраняем пользовательский ввод
      const connection = JiraConnection(
        baseUrl: 'https://saved.atlassian.net',
        email: 'saved@example.com',
        accountId: 'acc_saved_123',
        displayName: 'Saved User',
        route: JiraAuthRoute.direct,
        scope: 'https://saved.atlassian.net#acc_saved_123',
      );
      await store.saveConnection(connection, 'saved_token_xyz');

      // Повторное открытие формы
      final form = await store.loadForm();
      expect(form.baseUrl, equals('https://saved.atlassian.net'));
      expect(form.email, equals('saved@example.com'));
      expect(form.token, equals('saved_token_xyz'));
    });

    test(
      'Canceling or not saving does not modify existing connection',
      () async {
        final store = ConnectionStore(
          secureStorage: secureStorage,
          environment: {},
        );

        const connection = JiraConnection(
          baseUrl: 'https://initial.atlassian.net',
          email: 'initial@example.com',
          accountId: 'acc_1',
          displayName: 'Initial',
          route: JiraAuthRoute.direct,
          scope: 'https://initial.atlassian.net#acc_1',
        );
        await store.saveConnection(connection, 'initial_token');

        // Пользователь открыл форму и отменил
        final form = await store.loadForm();
        expect(form.email, equals('initial@example.com'));

        // Проверяем, что в хранилище осталось изначальное подключение
        final saved = await store.getSavedConnection();
        final savedToken = await store.getSavedToken();
        expect(saved?.email, equals('initial@example.com'));
        expect(savedToken, equals('initial_token'));
      },
    );
  });

  group('JiraClient Auth & Routes (Сценарии A16, A17)', () {
    test('Direct auth succeeds (200 on /rest/api/3/myself)', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/rest/api/3/myself'));
        expect(request.url.host, equals('esprowteam.atlassian.net'));
        expect(request.headers['authorization'], contains('Basic '));

        return http.Response(
          jsonEncode({
            'accountId': 'acc_direct_999',
            'displayName': 'Direct User',
            'emailAddress': 'direct@example.com',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final jira = JiraClient(client: mockClient);
      final connection = await jira.testConnection(
        baseUrl: 'https://esprowteam.atlassian.net',
        email: 'direct@example.com',
        token: 'valid_direct_token',
      );

      expect(connection.route, equals(JiraAuthRoute.direct));
      expect(connection.accountId, equals('acc_direct_999'));
      expect(connection.displayName, equals('Direct User'));
      expect(
        connection.scope,
        equals('https://esprowteam.atlassian.net#acc_direct_999'),
      );
      expect(connection.apiBaseUrl, equals('https://esprowteam.atlassian.net'));
    });

    test('Scoped auth succeeds when direct returns 401 (A17)', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'esprowteam.atlassian.net' &&
            request.url.path == '/rest/api/3/myself') {
          // Прямой маршрут отклоняет обычный токен (401)
          return http.Response(
            jsonEncode({
              'errorMessages': ['Unauthorized'],
            }),
            401,
          );
        }

        if (request.url.host == 'esprowteam.atlassian.net' &&
            request.url.path == '/_edge/tenant_info') {
          return http.Response(
            jsonEncode({'cloudId': 'cloud-id-uuid-4444'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.host == 'api.atlassian.com' &&
            request.url.path ==
                '/ex/jira/cloud-id-uuid-4444/rest/api/3/myself') {
          return http.Response(
            jsonEncode({
              'accountId': 'acc_scoped_555',
              'displayName': 'Scoped User',
              'emailAddress': 'scoped@example.com',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final jira = JiraClient(client: mockClient);
      final connection = await jira.testConnection(
        baseUrl: 'https://esprowteam.atlassian.net',
        email: 'scoped@example.com',
        token: 'scoped_api_token',
      );

      expect(connection.route, equals(JiraAuthRoute.scoped));
      expect(connection.cloudId, equals('cloud-id-uuid-4444'));
      expect(connection.accountId, equals('acc_scoped_555'));
      expect(
        connection.apiBaseUrl,
        equals('https://api.atlassian.com/ex/jira/cloud-id-uuid-4444'),
      );
      expect(
        connection.scope,
        equals('https://esprowteam.atlassian.net#acc_scoped_555'),
      );
    });

    test('Fails with 401 when both direct and scoped return 401', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/_edge/tenant_info') {
          return http.Response(jsonEncode({'cloudId': 'cloud-id-123'}), 200);
        }
        return http.Response('Unauthorized', 401);
      });

      final jira = JiraClient(client: mockClient);

      expect(
        () => jira.testConnection(
          baseUrl: 'https://site.atlassian.net',
          email: 'bad@example.com',
          token: 'invalid_token',
        ),
        throwsA(
          isA<JiraApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });

    test(
      'Fails immediately with 403 Forbidden without falling back to scoped',
      () async {
        var scopedCalled = false;
        final mockClient = MockClient((request) async {
          if (request.url.path == '/_edge/tenant_info') {
            scopedCalled = true;
            return http.Response(jsonEncode({'cloudId': 'cloud-id-123'}), 200);
          }
          return http.Response('Forbidden', 403);
        });

        final jira = JiraClient(client: mockClient);

        expect(
          () => jira.testConnection(
            baseUrl: 'https://site.atlassian.net',
            email: 'user@example.com',
            token: 'token',
          ),
          throwsA(
            isA<JiraApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              403,
            ),
          ),
        );
        expect(scopedCalled, isFalse);
      },
    );

    test('Handles 429 Too Many Requests with Retry-After header', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          'Rate limited',
          429,
          headers: {'retry-after': '30'},
        );
      });

      final jira = JiraClient(client: mockClient);

      expect(
        () => jira.testConnection(
          baseUrl: 'https://site.atlassian.net',
          email: 'user@example.com',
          token: 'token',
        ),
        throwsA(
          isA<JiraApiException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having((e) => e.message, 'message', contains('30')),
        ),
      );
    });
  });
}
