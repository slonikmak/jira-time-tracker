import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jira_time_tracker/day_builder.dart';
import 'package:jira_time_tracker/jira_client.dart';
import 'package:jira_time_tracker/models.dart';

void main() {
  group('Jira Worklog Discovery & Conflicts (Ticket 08, A12)', () {
    const testBaseUrl = 'https://test.atlassian.net';
    const testScope = 'https://test.atlassian.net#acc-123';
    const testAccountId = 'acc-123';
    const testToken = 'secret-token';

    const testConnection = JiraConnection(
      baseUrl: testBaseUrl,
      email: 'user@example.com',
      accountId: testAccountId,
      displayName: 'Test User',
      route: JiraAuthRoute.direct,
      scope: testScope,
    );

    test(
      'A12: JQL поиск с nextPageToken и пагинация worklogs по startAt/maxResults с фильтрацией по accountId',
      () async {
        final targetDate = DateTime.utc(2026, 9, 14);
        final offset = Duration.zero;

        final mockClient = MockClient((request) async {
          final path = request.url.path;

          // 1. POST /rest/api/3/search/jql
          if (path.endsWith('/rest/api/3/search/jql') &&
              request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final jql = body['jql'] as String;
            expect(jql, contains('worklogAuthor = "$testAccountId"'));
            expect(jql, contains("worklogDate >= '2026-09-13'"));
            expect(jql, contains("worklogDate <= '2026-09-15'"));

            final token = body['nextPageToken'] as String?;
            if (token == null) {
              // Первая страница поиска
              return http.Response(
                jsonEncode({
                  'issues': [
                    {
                      'id': '1001',
                      'key': 'PROJ-1',
                      'fields': {'summary': 'Задача 1'},
                    },
                  ],
                  'nextPageToken': 'token-page-2',
                  'isLast': false,
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            } else if (token == 'token-page-2') {
              // Вторая страница поиска
              return http.Response(
                jsonEncode({
                  'issues': [
                    {
                      'id': '1002',
                      'key': 'PROJ-2',
                      'fields': {'summary': 'Задача 2'},
                    },
                  ],
                  'nextPageToken': null,
                  'isLast': true,
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
          }

          // 2. GET /rest/api/3/issue/1001/worklog
          if (path.contains('/issue/1001/worklog')) {
            final startAt =
                int.tryParse(request.url.queryParameters['startAt'] ?? '0') ??
                0;
            if (startAt == 0) {
              // Страница 1 для задачи 1001 (всего 2 записи)
              return http.Response(
                jsonEncode({
                  'startAt': 0,
                  'maxResults': 1,
                  'total': 2,
                  'worklogs': [
                    {
                      'id': 'wl-1',
                      'issueId': '1001',
                      'author': {
                        'accountId': testAccountId,
                        'displayName': 'Test User',
                      },
                      'started': '2026-09-14T09:00:00.000+0000',
                      'timeSpentSeconds': 3600, // 1 час
                      'comment': {
                        'type': 'doc',
                        'version': 1,
                        'content': [
                          {
                            'type': 'paragraph',
                            'content': [
                              {'type': 'text', 'text': 'Моя утренняя работа'},
                            ],
                          },
                        ],
                      },
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            } else {
              // Страница 2 для задачи 1001: автор ДРУГОЙ пользователь!
              return http.Response(
                jsonEncode({
                  'startAt': 1,
                  'maxResults': 1,
                  'total': 2,
                  'worklogs': [
                    {
                      'id': 'wl-other-user',
                      'issueId': '1001',
                      'author': {
                        'accountId': 'other-account-999',
                        'displayName': 'Other Colleague',
                      },
                      'started': '2026-09-14T10:00:00.000+0000',
                      'timeSpentSeconds': 1800,
                      'comment': 'Чужая работа',
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
          }

          // 3. GET /rest/api/3/issue/1002/worklog
          if (path.contains('/issue/1002/worklog')) {
            // Запись нашего пользователя, но за ДРУГОЙ день (13 сентября)
            return http.Response(
              jsonEncode({
                'startAt': 0,
                'maxResults': 50,
                'total': 1,
                'worklogs': [
                  {
                    'id': 'wl-yesterday',
                    'issueId': '1002',
                    'author': {
                      'accountId': testAccountId,
                      'displayName': 'Test User',
                    },
                    'started': '2026-09-13T14:00:00.000+0000', // вчера!
                    'timeSpentSeconds': 3600,
                    'comment': 'Вчерашняя работа',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.Response('Not found', 404);
        });

        final jiraClient = JiraClient(client: mockClient);

        final worklogs = await jiraClient.fetchDayWorklogs(
          date: targetDate,
          timeZoneOffset: offset,
          connection: testConnection,
          token: testToken,
        );

        // Проверяем фильтрацию:
        // wl-1 (наш аккаунт, 14 сентября) должен быть включен!
        // wl-other-user (чужой аккаунт) должен быть отфильтрован!
        // wl-yesterday (вчерашний день) должен быть отфильтрован!
        expect(worklogs.length, 1);
        final w = worklogs.first;
        expect(w.id, 'wl-1');
        expect(w.authorAccountId, testAccountId);
        expect(w.durationSeconds, 3600);
        expect(w.comment, 'Моя утренняя работа');
        expect(w.startUtc, DateTime.utc(2026, 9, 14, 9, 0));
      },
    );

    test(
      'A12: Сбой при загрузке страницы Jira возвращает ошибку и не трактуется как пустой день',
      () async {
        final targetDate = DateTime.utc(2026, 9, 14);

        // Клиент возвращает ошибку 500 на JQL
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final jiraClient = JiraClient(client: mockClient);

        expect(
          () => jiraClient.fetchDayWorklogs(
            date: targetDate,
            timeZoneOffset: Duration.zero,
            connection: testConnection,
            token: testToken,
          ),
          throwsA(isA<JiraApiException>()),
        );
      },
    );

    test('A12: задачи дня читаются с ограниченной параллельностью', () async {
      final release = Completer<void>();
      var active = 0;
      var peak = 0;
      final pageSizes = <String?>[];
      final mockClient = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'issues': [
                for (var i = 1; i <= 5; i++)
                  {
                    'id': '$i',
                    'key': 'PROJ-$i',
                    'fields': {'summary': 'Issue $i'},
                  },
              ],
              'isLast': true,
            }),
            200,
          );
        }
        pageSizes.add(request.url.queryParameters['maxResults']);
        active++;
        if (active > peak) peak = active;
        await release.future;
        active--;
        return http.Response(jsonEncode({'total': 0, 'worklogs': []}), 200);
      });
      final jiraClient = JiraClient(client: mockClient);
      final fetch = jiraClient.fetchDayWorklogs(
        date: DateTime.utc(2026, 9, 14),
        timeZoneOffset: Duration.zero,
        connection: testConnection,
        token: testToken,
      );
      await Future<void>.delayed(Duration.zero);
      try {
        expect(peak, 4);
      } finally {
        release.complete();
        await fetch;
      }
      expect(pageSizes, everyElement('500'));
    });

    test(
      'A07, Ticket 08: DayBuilder строит день вокруг существующих записей Jira без пересечений',
      () {
        // Существующая запись в Jira: с 11:00 до 12:00 (1 час)
        final existingStart = DateTime.utc(2026, 9, 14, 11, 0);
        final existingWorklog = ImportedWorklog(
          id: 'jira-existing-1',
          issueId: '1001',
          issueKey: 'EXIST-1',
          startUtc: existingStart,
          durationSeconds: 3600,
          authorAccountId: testAccountId,
          comment: 'Существующий лог',
        );

        final input = DayBuilderInput(
          localDate: DateTime(2026, 9, 14),
          timeZoneOffset: Duration.zero,
          settings: const DaySettings(
            startMinutesMin: 8 * 60,
            startMinutesMax: 8 * 60,
            totalDurationSecondsMin: 8 * 3600,
            totalDurationSecondsMax: 8 * 3600,
          ),
          existingWorklogs: [existingWorklog],
          logs: [
            const DayBuilderLogInput(
              sourceLogId: 'log-new',
              issueId: '2001',
              titleSnapshot: 'NEW-1',
              sourceDurationSeconds: 14400, // 4 часа
            ),
          ],
        );

        final plan = DayBuilder.build(input: input, seed: 42);

        // День включает существующий worklog
        expect(plan.totalExistingSeconds, 3600);
        expect(plan.totalDaySeconds, lessThanOrEqualTo(28800));

        // Валидация подтверждает отсутствие пересечений между новым расписанием и существующим логом
        final errors = DayBuilder.validate(
          plan: plan,
          existingWorklogs: [existingWorklog],
        );
        expect(errors, isEmpty);
      },
    );

    test(
      'Конфликт: Существующие записи Jira пересекаются друг с другом или превышают 8 часов',
      () {
        final now = DateTime.utc(2026, 9, 14, 8, 0);

        // Пересекающиеся записи Jira
        final ew1 = ImportedWorklog(
          id: 'ew-1',
          issueId: '1',
          startUtc: now,
          durationSeconds: 7200, // 8:00 - 10:00
          authorAccountId: testAccountId,
        );
        final ew2 = ImportedWorklog(
          id: 'ew-2',
          issueId: '2',
          startUtc: now.add(
            const Duration(hours: 1),
          ), // 9:00 - 11:00 (пересекается!)
          durationSeconds: 7200,
          authorAccountId: testAccountId,
        );

        final inputOverlapping = DayBuilderInput(
          localDate: DateTime(2026, 9, 14),
          timeZoneOffset: Duration.zero,
          settings: const DaySettings(),
          existingWorklogs: [ew1, ew2],
          logs: [
            const DayBuilderLogInput(
              sourceLogId: 'log-1',
              issueId: '1',
              titleSnapshot: 'Task',
              sourceDurationSeconds: 3600,
            ),
          ],
        );

        expect(
          () => DayBuilder.build(input: inputOverlapping, seed: 1),
          throwsA(
            isA<DayBuilderException>().having(
              (e) => e.message,
              'message',
              contains('существующие записи в Jira пересекаются'),
            ),
          ),
        );

        // Существующие записи уже превышают 8 часов
        final ewHuge = ImportedWorklog(
          id: 'ew-huge',
          issueId: '1',
          startUtc: now,
          durationSeconds: 9 * 3600, // 9 часов
          authorAccountId: testAccountId,
        );

        final inputExceeding = DayBuilderInput(
          localDate: DateTime(2026, 9, 14),
          timeZoneOffset: Duration.zero,
          settings: const DaySettings(),
          existingWorklogs: [ewHuge],
          logs: [
            const DayBuilderLogInput(
              sourceLogId: 'log-1',
              issueId: '1',
              titleSnapshot: 'Task',
              sourceDurationSeconds: 3600,
            ),
          ],
        );

        expect(
          () => DayBuilder.build(input: inputExceeding, seed: 1),
          throwsA(
            isA<DayBuilderException>().having(
              (e) => e.message,
              'message',
              contains(
                'Существующие записи в Jira уже занимают 8 или более часов',
              ),
            ),
          ),
        );
      },
    );
  });
}
