import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  const connection = JiraConnection(
    baseUrl: 'https://test.atlassian.net',
    email: 'user@example.com',
    accountId: 'acc-123',
    displayName: 'Test User',
    route: JiraAuthRoute.direct,
    scope: 'https://test.atlassian.net#acc-123',
  );

  late LocalStore store;
  late ConnectionStore connectionStore;
  late JiraClient jiraClient;

  setUp(() async {
    store = LocalStore(sqlite3.openInMemory());
    store.init();
    connectionStore = ConnectionStore(
      secureStorage: InMemorySecureStorage(),
      environment: {},
    );
    await connectionStore.saveConnection(connection, 'test-token');
  });

  tearDown(() {
    jiraClient.close();
    store.close();
  });

  test('A13: opening Day loads Jira worklogs without a local draft', () async {
    final requests = <String>[];
    jiraClient = JiraClient(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          requests.add(
            (jsonDecode(request.body) as Map<String, dynamic>)['jql'] as String,
          );
          return http.Response(jsonEncode({'issues': [], 'isLast': true}), 200);
        }
        return http.Response('Not found', 404);
      }),
    );
    final state = AppState(
      store: store,
      connectionStore: connectionStore,
      jiraClient: jiraClient,
      initialConnection: connection,
      nowProvider: () => DateTime.utc(2026, 9, 14, 12),
      isReadOnly: false,
    );
    addTearDown(state.dispose);

    state.selectTab(1);
    await Future<void>.delayed(Duration.zero);

    expect(requests, hasLength(1));
    expect(requests.single, contains("worklogDate >= '2026-09-13'"));
  });

  test('A13: failed Jira read stays distinct from an empty day', () async {
    jiraClient = JiraClient(
      client: MockClient((request) async {
        final jql =
            (jsonDecode(request.body) as Map<String, dynamic>)['jql'] as String;
        if (jql.contains("worklogDate >= '2026-09-13'")) {
          return http.Response('Unavailable', 500);
        }
        return http.Response(jsonEncode({'issues': [], 'isLast': true}), 200);
      }),
    );
    final state = AppState(
      store: store,
      connectionStore: connectionStore,
      jiraClient: jiraClient,
      initialConnection: connection,
      nowProvider: () => DateTime.utc(2026, 9, 14, 12),
      isReadOnly: false,
    );
    addTearDown(state.dispose);

    state.setSelectedDate(DateTime(2026, 9, 14));
    await Future<void>.delayed(Duration.zero);
    expect(state.jiraWorklogsLoadFailed, isTrue);
    expect(state.hasLoadedJiraWorklogs, isFalse);
    state.setStatusMessage(null);
    expect(state.jiraWorklogsLoadFailed, isTrue);

    state.setSelectedDate(DateTime(2026, 9, 16));
    await Future<void>.delayed(Duration.zero);
    expect(state.jiraWorklogsLoadFailed, isFalse);
    expect(state.hasLoadedJiraWorklogs, isTrue);
    expect(state.importedWorklogs, isEmpty);
  });

  test(
    'A13: switching dates clears old logs and ignores a late Jira response',
    () async {
      final firstSearch = Completer<http.Response>();
      final firstStarted = Completer<void>();
      jiraClient = JiraClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            final jql =
                (jsonDecode(request.body) as Map<String, dynamic>)['jql']
                    as String;
            if (jql.contains("worklogDate >= '2026-09-13'")) {
              firstStarted.complete();
              return firstSearch.future;
            }
            return http.Response(
              jsonEncode({
                'issues': [
                  {
                    'id': '1002',
                    'key': 'PROJ-2',
                    'fields': {'summary': 'Second'},
                  },
                ],
                'isLast': true,
              }),
              200,
            );
          }
          final first = request.url.path.contains('/issue/1001/');
          return http.Response(
            jsonEncode({
              'total': 1,
              'worklogs': [
                {
                  'id': first ? 'first' : 'second',
                  'author': {'accountId': connection.accountId},
                  'started': first
                      ? '2026-09-14T09:00:00.000+0000'
                      : '2026-09-16T09:00:00.000+0000',
                  'timeSpentSeconds': 3600,
                },
              ],
            }),
            200,
          );
        }),
      );
      final state = AppState(
        store: store,
        connectionStore: connectionStore,
        jiraClient: jiraClient,
        initialConnection: connection,
        nowProvider: () => DateTime.utc(2026, 9, 14, 12),
        isReadOnly: false,
      );
      addTearDown(state.dispose);
      state.setImportedWorklogs([
        ImportedWorklog(
          id: 'stale',
          issueId: '1000',
          startUtc: DateTime.utc(2026, 9, 12, 9),
          durationSeconds: 3600,
          authorAccountId: connection.accountId,
        ),
      ]);

      state.setSelectedDate(DateTime(2026, 9, 14));
      expect(state.importedWorklogs, isEmpty);
      await firstStarted.future;
      state.setSelectedDate(DateTime(2026, 9, 16));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(state.importedWorklogs.map((w) => w.id), ['second']);

      firstSearch.complete(
        http.Response(
          jsonEncode({
            'issues': [
              {
                'id': '1001',
                'key': 'PROJ-1',
                'fields': {'summary': 'First'},
              },
            ],
            'isLast': true,
          }),
          200,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(state.selectedDate, DateTime(2026, 9, 16));
      expect(state.importedWorklogs.map((w) => w.id), ['second']);
    },
  );
}
