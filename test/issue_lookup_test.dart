import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/issue_parser.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';

void main() {
  group('IssueParser (разбор ввода ключей, ID и URL)', () {
    test('Parses plain uppercase and lowercase issue keys', () {
      expect(IssueParser.parse('PROJ-123'), equals('PROJ-123'));
      expect(IssueParser.parse('proj-123'), equals('PROJ-123'));
      expect(IssueParser.parse('  ED-42  '), equals('ED-42'));
      expect(IssueParser.parse('CLIENT_APP-999'), equals('CLIENT_APP-999'));
    });

    test('Parses numeric issue ID', () {
      expect(IssueParser.parse('10025'), equals('10025'));
      expect(IssueParser.parse('  42  '), equals('42'));
    });

    test('Parses browser URLs with /browse/', () {
      expect(
        IssueParser.parse('https://esprowteam.atlassian.net/browse/PROJ-123'),
        equals('PROJ-123'),
      );
      expect(
        IssueParser.parse(
          'https://company.atlassian.net/browse/proj-456?atlOrigin=xyz',
        ),
        equals('PROJ-456'),
      );
      expect(IssueParser.parse('/browse/ED-77'), equals('ED-77'));
    });

    test('Returns null for invalid/empty input', () {
      expect(IssueParser.parse(''), isNull);
      expect(IssueParser.parse('   '), isNull);
      expect(IssueParser.parse('not an issue key or url'), isNull);
    });
  });

  group('JiraClient.getIssue (Сценарий A05)', () {
    const testConnection = JiraConnection(
      baseUrl: 'https://esprowteam.atlassian.net',
      email: 'user@example.com',
      accountId: 'acc_current_user',
      displayName: 'Current User',
      route: JiraAuthRoute.direct,
      scope: 'https://esprowteam.atlassian.net#acc_current_user',
    );

    test('Fetches issue summary, canonical key and status', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/rest/api/3/issue/PROJ-123'));
        expect(request.url.queryParameters['fields'], equals('summary,status'));

        return http.Response(
          jsonEncode({
            'id': '10042',
            'key': 'PROJ-123',
            'fields': {
              'summary': 'Implement authorization module',
              'status': {'name': 'В работе'},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final jira = JiraClient(client: mockClient);
      final issue = await jira.getIssue(
        'PROJ-123',
        connection: testConnection,
        token: 'secret_token',
      );

      expect(issue.key, equals('PROJ-123'));
      expect(issue.issueId, equals('10042'));
      expect(issue.summary, equals('Implement authorization module'));
      expect(issue.status, equals('В работе'));
      expect(issue.scope, equals(testConnection.scope));
    });

    test('Succeeds even if task is assigned to another user (A05)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'id': '10043',
            'key': 'PROJ-124',
            'fields': {
              'summary': 'Task assigned to colleague',
              'assignee': {
                'accountId': 'acc_other_colleague',
                'displayName': 'Other Colleague',
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final jira = JiraClient(client: mockClient);
      final issue = await jira.getIssue(
        'PROJ-124',
        connection: testConnection,
        token: 'secret_token',
      );

      expect(issue.key, equals('PROJ-124'));
      expect(issue.summary, equals('Task assigned to colleague'));
    });

    test('Throws 404 when issue not found', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final jira = JiraClient(client: mockClient);

      expect(
        () => jira.getIssue(
          'NONEXIST-1',
          connection: testConnection,
          token: 'token',
        ),
        throwsA(
          isA<JiraApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });
  });

  group('AppState.addIssue & фильтрация (Сценарий A05)', () {
    late Database db;
    late LocalStore store;
    late SecureStorage secureStorage;
    late ConnectionStore connectionStore;

    const testConnection = JiraConnection(
      baseUrl: 'https://esprowteam.atlassian.net',
      email: 'user@example.com',
      accountId: 'acc_current_user',
      displayName: 'Current User',
      route: JiraAuthRoute.direct,
      scope: 'https://esprowteam.atlassian.net#acc_current_user',
    );

    setUp(() async {
      db = sqlite3.openInMemory();
      store = LocalStore(db);
      store.init();
      secureStorage = InMemorySecureStorage();
      connectionStore = ConnectionStore(
        secureStorage: secureStorage,
        environment: {},
      );
      await connectionStore.saveConnection(testConnection, 'valid_token');
    });

    tearDown(() {
      store.close();
    });

    test(
      'Adding by key, numeric ID and URL deduplicates and updates order (A05)',
      () async {
        final mockClient = MockClient((request) async {
          // Ответ для ключа PROJ-555 или ID 20055
          return http.Response(
            jsonEncode({
              'id': '20055',
              'key': 'PROJ-555',
              'fields': {'summary': 'Task added by different methods'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final appState = AppState(
          store: store,
          connectionStore: connectionStore,
          jiraClient: JiraClient(client: mockClient),
          isReadOnly: false,
          initialConnection: testConnection,
        );

        // 1. Добавляем по ссылке URL
        await appState.addIssue(
          'https://esprowteam.atlassian.net/browse/PROJ-555',
        );
        expect(appState.issues.length, equals(1));
        expect(appState.issues.first.key, equals('PROJ-555'));
        expect(appState.issues.first.issueId, equals('20055'));

        // 2. Повторно добавляем по числовому ID
        await appState.addIssue('20055');
        // Дубликат не должен появиться — одна строка задачи в списке (A05)
        expect(appState.issues.length, equals(1));
        expect(appState.issues.first.key, equals('PROJ-555'));

        // 3. Повторно добавляем по ключу
        await appState.addIssue('proj-555');
        expect(appState.issues.length, equals(1));
      },
    );

    test('Filters by search query and period without deleting data', () async {
      final appState = AppState(
        store: store,
        connectionStore: connectionStore,
        jiraClient: JiraClient(),
        isReadOnly: false,
        initialConnection: testConnection,
      );

      final now = DateTime.now().toUtc();

      // Добавим 3 задачи в хранилище с разными датами
      store.upsertIssue(
        Issue(
          scope: testConnection.scope,
          issueId: '1',
          key: 'ALPHA-1',
          summary: 'Authentication feature',
          lastUsedAtUtc: now.subtract(const Duration(days: 2)),
        ),
      );
      store.upsertIssue(
        Issue(
          scope: testConnection.scope,
          issueId: '2',
          key: 'BETA-2',
          summary: 'Database refactoring',
          lastUsedAtUtc: now.subtract(const Duration(days: 15)),
        ),
      );
      store.upsertIssue(
        Issue(
          scope: testConnection.scope,
          issueId: '3',
          key: 'GAMMA-3',
          summary: 'Legacy old issue',
          lastUsedAtUtc: now.subtract(const Duration(days: 45)),
        ),
      );

      await appState.loadIssues();
      expect(appState.issues.length, equals(3));

      // Фильтр '7 дней' -> только ALPHA-1
      appState.setIssueFilterPeriod(IssueFilterPeriod.days7);
      expect(appState.filteredIssues.map((i) => i.key), contains('ALPHA-1'));
      expect(appState.filteredIssues.length, equals(1));

      // Фильтр '30 дней' -> ALPHA-1 и BETA-2
      appState.setIssueFilterPeriod(IssueFilterPeriod.days30);
      expect(appState.filteredIssues.length, equals(2));

      // Фильтр 'Все' -> все 3
      appState.setIssueFilterPeriod(IssueFilterPeriod.all);
      expect(appState.filteredIssues.length, equals(3));

      // Поиск по названию
      appState.setIssueSearchQuery('refactoring');
      expect(appState.filteredIssues.length, equals(1));
      expect(appState.filteredIssues.first.key, equals('BETA-2'));

      // Поиск по ключу
      appState.setIssueSearchQuery('alpha');
      expect(appState.filteredIssues.length, equals(1));
      expect(appState.filteredIssues.first.key, equals('ALPHA-1'));

      // Сброс поиска
      appState.setIssueSearchQuery('');
      expect(appState.filteredIssues.length, equals(3));

      // Проверяем, что в БД ничего не удалено
      expect(store.getIssues(scope: testConnection.scope).length, equals(3));
    });
  });
}
