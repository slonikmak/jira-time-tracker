import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jira_time_tracker/agent_api_server.dart';
import 'package:jira_time_tracker/app_state.dart';
import 'package:jira_time_tracker/connection_store.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/local_store.dart';
import 'package:jira_time_tracker/models.dart';
import 'package:jira_time_tracker/secure_storage.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('QuickIssue storage', () {
    late Database db;
    late LocalStore store;

    setUp(() {
      db = sqlite3.openInMemory();
      store = LocalStore(db)..init();
    });

    tearDown(() => store.close());

    test('stores a scoped issue reference and supports note changes', () {
      final issue = Issue(
        scope: 'jira#account-1',
        issueId: '1001',
        key: 'PROJ-1',
        summary: 'Implement feature',
        lastUsedAtUtc: DateTime.utc(2026, 9, 25),
      );
      store.upsertIssue(issue);

      final quickIssue = QuickIssue(
        scope: issue.scope,
        issueId: issue.issueId,
        note: 'Review first',
        createdAtUtc: DateTime.utc(2026, 9, 25, 9),
      );
      store.addQuickIssue(quickIssue);
      expect(store.getQuickIssues(scope: issue.scope), [quickIssue]);

      store.updateQuickIssueNote(issue.scope, issue.issueId, 'Pair with Alex');
      expect(
        store.getQuickIssues(scope: issue.scope).single.note,
        'Pair with Alex',
      );
    });

    test('guards every QuickIssue mutation in read-only mode', () {
      final issue = Issue(
        scope: 'jira#account-1',
        issueId: '1001',
        key: 'PROJ-1',
        summary: 'Implement feature',
        lastUsedAtUtc: DateTime.utc(2026, 9, 25),
      );
      store.upsertIssue(issue);
      final quickIssue = QuickIssue(
        scope: issue.scope,
        issueId: issue.issueId,
        createdAtUtc: DateTime.utc(2026, 9, 25, 9),
      );
      store.addQuickIssue(quickIssue);
      final readOnlyStore = LocalStore(db, isReadOnly: true);

      expect(
        () => readOnlyStore.addQuickIssue(quickIssue),
        throwsA(isA<ReadOnlyException>()),
      );
      expect(
        () => readOnlyStore.updateQuickIssueNote(
          issue.scope,
          issue.issueId,
          'new',
        ),
        throwsA(isA<ReadOnlyException>()),
      );
      expect(
        () => readOnlyStore.deleteQuickIssue(issue.scope, issue.issueId),
        throwsA(isA<ReadOnlyException>()),
      );
    });

    test('migrates an existing version 3 database to version 4', () {
      db.execute('DROP TABLE quick_issues;');
      db.execute('PRAGMA user_version = 3;');
      store.init();

      expect(db.select('PRAGMA user_version;').single.values.first, 4);
      expect(store.getQuickIssues(scope: 'jira#account-1'), isEmpty);
    });
  });

  group('QuickIssue AppState', () {
    late Database db;
    late LocalStore store;
    late ConnectionStore connectionStore;
    late AppState appState;
    late DateTime clockNow;
    var jiraUnavailable = false;

    const connection = JiraConnection(
      baseUrl: 'https://example.atlassian.net',
      email: 'agent@example.com',
      accountId: 'account-1',
      displayName: 'Agent User',
      route: JiraAuthRoute.direct,
      scope: 'https://example.atlassian.net#account-1',
    );

    setUp(() async {
      db = sqlite3.openInMemory();
      store = LocalStore(db)..init();
      connectionStore = ConnectionStore(
        secureStorage: InMemorySecureStorage(),
        environment: {},
      );
      await connectionStore.saveConnection(connection, 'token');
      clockNow = DateTime.utc(2026, 9, 25);
      jiraUnavailable = false;
      appState = AppState(
        store: store,
        connectionStore: connectionStore,
        jiraClient: JiraClient(
          client: MockClient((request) async {
            if (jiraUnavailable) return http.Response('Not found', 404);
            final key = request.url.path.split('/').last;
            return http.Response(
              jsonEncode({
                'id': key == 'TWO-2' ? '2002' : '1001',
                'key': key,
                'fields': {'summary': 'Summary for $key'},
              }),
              HttpStatus.ok,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
        isReadOnly: false,
        initialConnection: connection,
        nowProvider: () => clockNow,
      );
    });

    tearDown(() {
      appState.dispose();
      store.close();
    });

    test(
      'keeps insertion order and the original position on duplicate add',
      () async {
        await appState.addQuickIssue('ONE-1', note: 'First note');
        clockNow = DateTime.utc(2026, 9, 25, 10);
        await appState.addQuickIssue('TWO-2');
        clockNow = DateTime.utc(2026, 9, 25, 11);
        await appState.addQuickIssue('ONE-1', note: 'Changed by duplicate');

        expect(appState.quickIssues.map((item) => item.issueId), [
          '1001',
          '2002',
        ]);
        expect(
          appState.quickIssues.first.createdAtUtc,
          DateTime.utc(2026, 9, 25),
        );
        expect(appState.quickIssues.first.note, 'First note');
      },
    );

    test(
      'does not create a local issue or quick issue when Jira lookup fails',
      () async {
        jiraUnavailable = true;

        await expectLater(
          appState.addQuickIssue('UNKNOWN-1'),
          throwsA(anything),
        );

        expect(store.getIssues(scope: connection.scope), isEmpty);
        expect(appState.quickIssues, isEmpty);
      },
    );

    test(
      'preview validates the issue without adding it to recent issues',
      () async {
        final issue = await appState.previewQuickIssue('ONE-1');

        expect(issue.key, 'ONE-1');
        expect(appState.issues, isEmpty);
        expect(appState.quickIssues, isEmpty);
        expect(store.getIssue(connection.scope, issue.issueId), isNull);
      },
    );

    test(
      'switching connections isolates and restores the catalogue by scope',
      () async {
        await appState.addQuickIssue('SAME-1', note: 'Account one');
        const otherConnection = JiraConnection(
          baseUrl: 'https://other.atlassian.net',
          email: 'other@example.com',
          accountId: 'account-2',
          displayName: 'Other User',
          route: JiraAuthRoute.direct,
          scope: 'https://other.atlassian.net#account-2',
        );

        await appState.updateConnection(otherConnection, 'token-2');
        expect(appState.quickIssues, isEmpty);
        await appState.addQuickIssue('SAME-1', note: 'Account two');
        expect(appState.quickIssues.single.note, 'Account two');

        await appState.updateConnection(connection, 'token-1');
        expect(appState.quickIssues.single.note, 'Account one');
        expect(
          store.getQuickIssues(scope: connection.scope).single.issueId,
          '1001',
        );
        expect(
          store.getQuickIssues(scope: otherConnection.scope).single.issueId,
          '1001',
        );
      },
    );

    test(
      'note changes and deletion leave the linked issue and local log intact',
      () async {
        final quickIssue = await appState.addQuickIssue(
          'ONE-1',
          note: 'Before',
        );
        final issue = store.getIssue(connection.scope, quickIssue.issueId)!;
        final log = LocalLog(
          id: 'log-1',
          scope: connection.scope,
          issueId: issue.issueId,
          titleSnapshot: issue.summary,
          accumulatedSeconds: 600,
          createdAtUtc: DateTime.utc(2026, 9, 25),
        );
        store.upsertLocalLog(log);

        await appState.updateQuickIssueNote(issue.issueId, '  After  ');
        expect(appState.quickIssues.single.note, 'After');
        await appState.deleteQuickIssue(issue.issueId);

        expect(appState.quickIssues, isEmpty);
        expect(store.getIssue(connection.scope, issue.issueId), isNotNull);
        expect(store.getLocalLog(log.id), log);
      },
    );

    test(
      'GET /api/quick-issues returns scoped fields in insertion order',
      () async {
        await appState.addQuickIssue('ONE-1', note: 'First note');
        clockNow = DateTime.utc(2026, 9, 25, 10);
        await appState.addQuickIssue('TWO-2');
        final server = AgentApiServer(appState: appState, initialPort: 0);
        final client = HttpClient();
        await server.start();
        addTearDown(() async {
          client.close(force: true);
          await server.stop();
        });

        Future<List<dynamic>> getQuickIssues() async {
          final request = await client.getUrl(
            Uri.parse('${server.url}/api/quick-issues'),
          );
          final response = await request.close();
          expect(response.statusCode, HttpStatus.ok);
          return jsonDecode(await response.transform(utf8.decoder).join())
              as List<dynamic>;
        }

        final firstScope = await getQuickIssues();
        expect(
          firstScope.map((item) => (item as Map<String, dynamic>)['issue_id']),
          ['1001', '2002'],
        );
        expect(firstScope.first, {
          'issue_id': '1001',
          'key': 'ONE-1',
          'summary': 'Summary for ONE-1',
          'note': 'First note',
        });

        const otherConnection = JiraConnection(
          baseUrl: 'https://other.atlassian.net',
          email: 'other@example.com',
          accountId: 'account-2',
          displayName: 'Other User',
          route: JiraAuthRoute.direct,
          scope: 'https://other.atlassian.net#account-2',
        );
        await appState.updateConnection(otherConnection, 'token-2');
        await appState.addQuickIssue('SAME-1', note: 'Only account two');
        final otherScope = await getQuickIssues();
        expect(otherScope, [
          {
            'issue_id': '1001',
            'key': 'SAME-1',
            'summary': 'Summary for SAME-1',
            'note': 'Only account two',
          },
        ]);
      },
    );

    test(
      'GET /api/quick-issues reports 409 without an active connection',
      () async {
        await appState.removeConnection();
        final server = AgentApiServer(appState: appState, initialPort: 0);
        final client = HttpClient();
        await server.start();
        addTearDown(() async {
          client.close(force: true);
          await server.stop();
        });

        final request = await client.getUrl(
          Uri.parse('${server.url}/api/quick-issues'),
        );
        final response = await request.close();

        expect(response.statusCode, HttpStatus.conflict);
        expect(
          jsonDecode(await response.transform(utf8.decoder).join()),
          containsPair('error', isA<String>()),
        );
      },
    );
  });
}
