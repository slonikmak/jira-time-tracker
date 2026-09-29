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
  group('Agent API Jira issue details', () {
    late Database db;
    late AppState state;
    late AgentApiServer server;
    late HttpClient client;
    late List<http.Request> jiraRequests;
    var commentPageStatus = 200;
    var attachmentStatus = 200;

    const attachment = {
      'id': '55',
      'filename': 'план.txt',
      'mimeType': 'text/plain',
      'size': 4,
      'created': '2026-09-28T10:00:00.000+0000',
      'author': {'accountId': 'author-1', 'displayName': 'Автор'},
    };

    Future<HttpClientResponse> get(String path) async {
      final request = await client.getUrl(Uri.parse('${server.url}$path'));
      return request.close();
    }

    setUp(() async {
      commentPageStatus = 200;
      attachmentStatus = 200;
      jiraRequests = [];
      db = sqlite3.openInMemory();
      final store = LocalStore(db)..init();
      final connectionStore = ConnectionStore(
        secureStorage: InMemorySecureStorage(),
        environment: {},
      );
      final connection = JiraConnection(
        baseUrl: 'https://example.atlassian.net',
        email: 'agent@example.com',
        accountId: 'agent-1',
        displayName: 'Agent',
        route: JiraAuthRoute.direct,
        scope: 'issue-details-test',
      );
      await connectionStore.saveConnection(connection, 'token-123');
      state = AppState(
        store: store,
        connectionStore: connectionStore,
        jiraClient: JiraClient(
          client: MockClient((request) async {
            jiraRequests.add(request);
            if (request.url.path.endsWith('/issue/PROJ-1')) {
              return http.Response(
                jsonEncode({
                  'id': '10001',
                  'key': 'PROJ-1',
                  'fields': {
                    'summary': 'Исправить экспорт',
                    'description': {
                      'type': 'doc',
                      'content': [
                        {
                          'type': 'paragraph',
                          'content': [
                            {'type': 'text', 'text': 'Первая строка'},
                          ],
                        },
                        {
                          'type': 'paragraph',
                          'content': [
                            {'type': 'text', 'text': 'Вторая строка'},
                          ],
                        },
                      ],
                    },
                    'status': {'name': 'In Progress'},
                    'issuetype': {'name': 'Task'},
                    'priority': {'name': 'High'},
                    'assignee': {'displayName': 'Исполнитель'},
                    'labels': ['backend'],
                    'created': '2026-09-27T10:00:00.000+0000',
                    'updated': '2026-09-28T11:00:00.000+0000',
                    'attachment': [attachment],
                  },
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            if (request.url.path.endsWith('/comment')) {
              final startAt = request.url.queryParameters['startAt'];
              if (startAt == '2' && commentPageStatus != 200) {
                return http.Response('{}', commentPageStatus);
              }
              final ids = startAt == '0' ? ['1', '2'] : ['3'];
              return http.Response(
                jsonEncode({
                  'total': 3,
                  'comments': [
                    for (final id in ids)
                      {
                        'id': id,
                        'author': {
                          'accountId': 'author-$id',
                          'displayName': 'Автор $id',
                        },
                        'created': '2026-09-28T10:00:00.000+0000',
                        'updated': '2026-09-28T10:00:00.000+0000',
                        'body': {
                          'type': 'doc',
                          'content': [
                            {
                              'type': 'paragraph',
                              'content': [
                                {'type': 'text', 'text': 'Комментарий $id'},
                                if (id == '1') {'type': 'hardBreak'},
                                if (id == '1')
                                  {'type': 'text', 'text': 'продолжение'},
                              ],
                            },
                          ],
                        },
                      },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            if (request.url.path.endsWith('/attachment/content/55')) {
              return http.Response.bytes(
                [0, 1, 2, 255],
                attachmentStatus,
                headers: {'content-type': 'application/octet-stream'},
              );
            }
            return http.Response('{}', 404);
          }),
        ),
        isReadOnly: false,
        initialConnection: connection,
        nowProvider: () => DateTime.utc(2026, 9, 29),
      );
      server = AgentApiServer(appState: state, initialPort: 0);
      await server.start();
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.stop();
      state.dispose();
      db.close();
    });

    test(
      'returns fresh issue text, every comment page and attachment list',
      () async {
      final response = await get('/api/issues/PROJ-1');
      final body =
          jsonDecode(await response.transform(utf8.decoder).join())
              as Map<String, dynamic>;
      expect(response.statusCode, 200, reason: body.toString());
        expect(body['issue_id'], '10001');
        expect(body['summary'], 'Исправить экспорт');
        expect(body['description'], 'Первая строка\nВторая строка');
        expect(body['status'], 'In Progress');
        expect(body['labels'], ['backend']);
        final comments = body['comments'] as List;
        expect(comments.map((item) => item['id']), ['1', '2', '3']);
        expect(comments.first['body'], 'Комментарий 1\nпродолжение');
        final attachments = body['attachments'] as List;
        expect(attachments.single['filename'], 'план.txt');
        expect(attachments.single['size_bytes'], 4);
        expect(
          attachments.single['download_path'],
          '/api/issues/PROJ-1/attachments/55',
        );
        expect(body.toString(), isNot(contains('token-123')));
        expect(
          jiraRequests
              .where((request) => request.url.path.endsWith('/comment'))
              .length,
          2,
        );
        expect(
          jiraRequests.every(
            (request) =>
                request.url.host == 'example.atlassian.net' &&
                request.headers['Authorization'] ==
                    JiraClient.buildBasicAuthHeader(
                      'agent@example.com',
                      'token-123',
                    ),
          ),
          isTrue,
        );
      },
    );

    test(
      'downloads listed attachment as binary without following Jira redirects',
      () async {
        final response = await get('/api/issues/PROJ-1/attachments/55');
        expect(response.statusCode, 200);
        expect(
          response.headers.contentType?.mimeType,
          'application/octet-stream',
        );
        expect(
          response.headers.value('content-disposition'),
          contains("filename*=UTF-8''"),
        );
        expect(await response.expand((bytes) => bytes).toList(), [
          0,
          1,
          2,
          255,
        ]);
        final attachmentRequest = jiraRequests.last;
        expect(attachmentRequest.url.queryParameters['redirect'], 'false');
        expect(attachmentRequest.followRedirects, isFalse);
        expect(
          jiraRequests.any((request) => request.url.path.endsWith('/comment')),
          isFalse,
        );
      },
    );

    test('rejects an attachment ID absent from the issue', () async {
      final response = await get('/api/issues/PROJ-1/attachments/99');
      expect(response.statusCode, 404);
      expect(jiraRequests.length, 1);
    });

    test(
      'reports incomplete comments and attachment redirects as errors',
      () async {
        commentPageStatus = 500;
        final details = await get('/api/issues/PROJ-1');
        expect(details.statusCode, 502);
        attachmentStatus = 303;
        final file = await get('/api/issues/PROJ-1/attachments/55');
        expect(file.statusCode, 502);
      },
    );

    test(
      'rejects invalid refs and foreign browser Origin before reading Jira',
      () async {
        final invalid = await get(
          '/api/issues/PROJ-1/attachments/not-a-number',
        );
        expect(invalid.statusCode, 400);
        final request = await client.getUrl(
          Uri.parse('${server.url}/api/issues/PROJ-1'),
        );
        request.headers.set('Origin', 'https://foreign.example');
        final foreign = await request.close();
        expect(foreign.statusCode, 403);
        expect(jiraRequests, isEmpty);
      },
    );

    test('rejects DNS rebinding Host', () async {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        server.port,
      );
      socket.write(
        'GET /api/help HTTP/1.1\r\nHost: foreign.example\r\nConnection: close\r\n\r\n',
      );
      final raw = await socket.cast<List<int>>().transform(utf8.decoder).join();
      expect(raw, startsWith('HTTP/1.1 403'));
    });
  });
}
