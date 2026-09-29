import 'dart:convert';
import 'dart:io';
import 'app_state.dart';
import 'day_builder.dart';
import 'jira_client.dart';
import 'models.dart';

/// Встроенный HTTP REST API сервер для взаимодействия с AI-агентами.
class AgentApiServer {
  final AppState? appState;
  final int initialPort;

  HttpServer? _server;
  int _actualPort = 0;

  AgentApiServer({this.appState, this.initialPort = 8765});

  bool get isRunning => _server != null;
  int get port => _actualPort;
  String get url => 'http://127.0.0.1:$_actualPort';

  /// Запуск сервера на 127.0.0.1 с автоматическим подбором свободного порта.
  Future<void> start() async {
    if (_server != null) return;

    var candidatePort = initialPort;
    final maxAttempts = candidatePort == 0 ? 1 : 20;

    for (var i = 0; i < maxAttempts; i++) {
      try {
        _server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          candidatePort,
          shared: false,
        );
        _actualPort = _server!.port;
        _server!.listen(_handleRequest);
        return;
      } on SocketException {
        if (candidatePort == 0) rethrow;
        candidatePort++;
      }
    }

    // Если все порты в диапазоне заняты, привязываемся к динамическому
    _server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: false,
    );
    _actualPort = _server!.port;
    _server!.listen(_handleRequest);
  }

  /// Остановка сервера.
  Future<void> stop() async {
    final s = _server;
    _server = null;
    _actualPort = 0;
    if (s != null) {
      await s.close(force: true);
    }
  }

  /// Возвращает готовый Markdown-текст инструкции/скилла для AI-агента.
  static String generateSkillPrompt(String baseUrl) {
    return '''# Навык: Взаимодействие с локальным Jira Time Tracker

Локальный REST API доступен по адресу `$baseUrl`.

## Правила
- Финальные worklogs в Jira отправляет только пользователь из UI.
- `LocalLog` — источник работы; `Segment` — отдельный планируемый Jira worklog.
- Каждый segment должен содержать `source_log_id` существующего queue log. Несколько сегментов могут ссылаться на один источник в пределах одного дня.
- Источник должен быть остановлен, не отправлен и не занят черновиком другой даты. Для разных дат раздели исходный лог в очереди через `POST /api/logs/{id}/split`.
- Сегменты одного дня должны полностью попадать в указанную дату. Пересечения рабочих сегментов разрешены; паузы формируются автоматически вне работы.

## Поиск и очередь
- `GET /api/issues?q=...` ищет локально по key, summary и status.
- `GET /api/issues/{key}` читает актуальные текстовые поля, все доступные комментарии и список вложений Jira.
- `GET /api/issues/{key}/attachments/{id}` отдельно скачивает вложение по ID из списка.
- `GET /api/issues/{key}/worklogs` читает все доступные записи Jira по тикету, включая записи других авторов; `is_mine` отмечает ваши.
- `GET /api/logs?q=...&issue_key=...&availability=...` возвращает логи с `availability` (`free`, `running`, `in_draft`) и `draft_date`.
- `GET /api/quick-issues` возвращает быстрые задачи активного подключения с локальными описаниями `note`; `POST /api/quick-issues`, `PATCH` и `DELETE /api/quick-issues/{issueId}` меняют этот список.
- `POST /api/logs` и `POST /api/logs/merge` принимают только известные локальные задачи или refs, которые удалось подтвердить через Jira; неизвестный ref не создаётся как offline fallback.
- Агент может создавать, редактировать, удалять, делить и объединять свободные queue logs.

## Сборка дня
1. Вызови `GET /api/day?date=YYYY-MM-DD` для свежих worklogs Jira и текущего draft. Если Jira недоступна, остановись и сообщи об ошибке.
2. Если draft существует, сохрани его top-level `revision`.
3. Вызови `POST /api/day`, передав весь набор segments целиком. Каждый segment должен ссылаться на свой `source_log_id`; `issue_key` необязателен и, если передан, должен соответствовать задаче источника.
4. При существующем draft передай `base_revision`. Ответ `409` означает конфликт правок: перечитай дату, объедини изменения и отправь snapshot заново.

```json
{
  "date": "2026-09-17",
  "base_revision": "revision-from-GET",
  "segments": [
    {"source_log_id": "uuid-1", "start": "09:00", "duration_minutes": 30, "description": "Разбор"},
    {"source_log_id": "uuid-1", "start": "09:45", "duration_minutes": 30, "description": "Реализация"}
  ]
}
```

Для полного контракта вызови `GET /api/help` или `GET /api/openapi.json`.
''';
  }

  void _handleRequest(HttpRequest request) async {
    final response = request.response;
    final host = request.headers.value(HttpHeaders.hostHeader);
    final allowedHosts = {'127.0.0.1:$_actualPort', 'localhost:$_actualPort'};
    final origin = request.headers.value('Origin');
    if (!allowedHosts.contains(host?.toLowerCase()) ||
        (origin != null &&
            origin != url &&
            origin != 'http://localhost:$_actualPort')) {
      _sendJson(response, HttpStatus.forbidden, {'error': 'Forbidden origin'});
      return;
    }
    if (origin != null) {
      response.headers.set('Access-Control-Allow-Origin', origin);
      response.headers.set('Vary', 'Origin');
    }
    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, PATCH, DELETE, OPTIONS',
    );
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization',
    );

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }

    try {
      final path = request.uri.path;

      if (path == '/api/help' && request.method == 'GET') {
        _sendHelp(response);
        return;
      }

      if (path == '/api/openapi.json' && request.method == 'GET') {
        _sendOpenApi(response);
        return;
      }

      if (path == '/api/issues' && request.method == 'GET') {
        _handleGetIssues(request, response);
        return;
      }

      final pathSegments = request.uri.pathSegments;
      if (request.method == 'GET' &&
          pathSegments.length == 3 &&
          pathSegments[0] == 'api' &&
          pathSegments[1] == 'issues') {
        await _handleGetIssueDetails(response, pathSegments[2]);
        return;
      }
      if (request.method == 'GET' &&
          pathSegments.length == 5 &&
          pathSegments[0] == 'api' &&
          pathSegments[1] == 'issues' &&
          pathSegments[3] == 'attachments') {
        await _handleDownloadAttachment(
          response,
          pathSegments[2],
          pathSegments[4],
        );
        return;
      }
      if (request.method == 'GET' &&
          pathSegments.length == 4 &&
          pathSegments[0] == 'api' &&
          pathSegments[1] == 'issues' &&
          pathSegments[3] == 'worklogs') {
        await _handleGetIssueWorklogs(response, pathSegments[2]);
        return;
      }

      // Маршруты Ticket 02 и Split/Merge
      if (path == '/api/logs') {
        if (request.method == 'GET') {
          await _handleGetLogs(request, response);
          return;
        } else if (request.method == 'POST') {
          await _handlePostLogs(request, response);
          return;
        }
      }

      if (path == '/api/logs/merge' && request.method == 'POST') {
        await _handleMergeLogs(request, response);
        return;
      }

      if (path.startsWith('/api/logs/') &&
          path.endsWith('/split') &&
          request.method == 'POST') {
        final id = path.substring(
          '/api/logs/'.length,
          path.length - '/split'.length,
        );
        await _handleSplitLog(request, response, id);
        return;
      }

      if (path.startsWith('/api/logs/') && path.length > '/api/logs/'.length) {
        final id = path.substring('/api/logs/'.length);
        if (request.method == 'PATCH') {
          await _handlePatchLog(request, response, id);
          return;
        } else if (request.method == 'DELETE') {
          await _handleDeleteLog(request, response, id);
          return;
        }
      }

      if (path == '/api/day') {
        if (request.method == 'GET') {
          await _handleGetDay(request, response);
          return;
        } else if (request.method == 'POST') {
          await _handlePostDay(request, response);
          return;
        }
      }

      if (path == '/api/quick-issues') {
        if (request.method == 'GET') {
          _handleGetQuickIssues(response);
          return;
        }
        if (request.method == 'POST') {
          await _handlePostQuickIssue(request, response);
          return;
        }
      }
      if (pathSegments.length == 3 &&
          pathSegments[0] == 'api' &&
          pathSegments[1] == 'quick-issues') {
        if (request.method == 'PATCH') {
          await _handlePatchQuickIssue(request, response, pathSegments[2]);
          return;
        }
        if (request.method == 'DELETE') {
          await _handleDeleteQuickIssue(response, pathSegments[2]);
          return;
        }
      }

      // 404 Not Found
      _sendJson(response, HttpStatus.notFound, {
        'error': 'Not Found',
        'path': path,
        'method': request.method,
      });
    } catch (e, st) {
      _sendJson(response, HttpStatus.internalServerError, {
        'error': e.toString(),
        'stackTrace': st.toString(),
      });
    }
  }

  void _handleGetQuickIssues(HttpResponse response) {
    final state = appState;
    final connection = state?.currentConnection;
    if (state == null || connection == null) {
      _sendJson(response, HttpStatus.conflict, {
        'error':
            'Подключите Jira, чтобы получить быстрые задачи активного каталога.',
      });
      return;
    }

    final list = state.quickIssues
        .map((quickIssue) => _formatQuickIssue(state, quickIssue))
        .toList();
    _sendJson(response, HttpStatus.ok, list);
  }

  Map<String, dynamic> _formatQuickIssue(
    AppState state,
    QuickIssue quickIssue,
  ) {
    final issue = state.issues.firstWhere(
      (i) => i.issueId == quickIssue.issueId,
    );
    return {
      'issue_id': quickIssue.issueId,
      'key': issue.key,
      'summary': issue.summary,
      'note': quickIssue.note,
    };
  }

  Future<void> _handlePostQuickIssue(
    HttpRequest request,
    HttpResponse response,
  ) async {
    final state = appState;
    if (state == null || state.currentConnection == null) {
      _sendJson(response, HttpStatus.conflict, {'error': 'Подключите Jira.'});
      return;
    }
    final body = await _parseJsonBody(request, response);
    if (body == null) return;
    final issueRef = body['issue_key'];
    final note = body['note'];
    if (issueRef is! String ||
        issueRef.trim().isEmpty ||
        (note != null && note is! String)) {
      _sendJson(response, HttpStatus.badRequest, {
        'error': 'Укажите issue_key и необязательный текст note.',
      });
      return;
    }
    try {
      final existingIds = state.quickIssues.map((item) => item.issueId).toSet();
      final quickIssue = await state.addQuickIssue(
        issueRef,
        note: note is String ? note : '',
      );
      final existed = existingIds.contains(quickIssue.issueId);
      if (existed && body.containsKey('note')) {
        await state.updateQuickIssueNote(
          quickIssue.issueId,
          note as String? ?? '',
        );
      }
      final result = state.quickIssues.firstWhere(
        (item) => item.issueId == quickIssue.issueId,
      );
      _sendJson(
        response,
        existed ? HttpStatus.ok : HttpStatus.created,
        _formatQuickIssue(state, result),
      );
    } catch (e) {
      _sendQuickIssueError(response, e);
    }
  }

  Future<void> _handlePatchQuickIssue(
    HttpRequest request,
    HttpResponse response,
    String issueId,
  ) async {
    final state = appState;
    if (state == null || state.currentConnection == null) {
      _sendJson(response, HttpStatus.conflict, {'error': 'Подключите Jira.'});
      return;
    }
    if (!state.quickIssues.any((item) => item.issueId == issueId)) {
      _sendJson(response, HttpStatus.notFound, {
        'error': 'Быстрая задача не найдена.',
      });
      return;
    }
    final body = await _parseJsonBody(request, response);
    if (body == null) return;
    if (!body.containsKey('note') ||
        (body['note'] != null && body['note'] is! String)) {
      _sendJson(response, HttpStatus.badRequest, {
        'error': 'Укажите текст note или null, чтобы очистить его.',
      });
      return;
    }
    try {
      await state.updateQuickIssueNote(issueId, body['note'] as String? ?? '');
      final quickIssue = state.quickIssues.firstWhere(
        (item) => item.issueId == issueId,
      );
      _sendJson(response, HttpStatus.ok, _formatQuickIssue(state, quickIssue));
    } catch (e) {
      _sendQuickIssueError(response, e);
    }
  }

  Future<void> _handleDeleteQuickIssue(
    HttpResponse response,
    String issueId,
  ) async {
    final state = appState;
    if (state == null || state.currentConnection == null) {
      _sendJson(response, HttpStatus.conflict, {'error': 'Подключите Jira.'});
      return;
    }
    if (!state.quickIssues.any((item) => item.issueId == issueId)) {
      _sendJson(response, HttpStatus.notFound, {
        'error': 'Быстрая задача не найдена.',
      });
      return;
    }
    try {
      await state.deleteQuickIssue(issueId);
      response.statusCode = HttpStatus.noContent;
      await response.close();
    } catch (e) {
      _sendQuickIssueError(response, e);
    }
  }

  void _sendQuickIssueError(HttpResponse response, Object error) {
    if (error is FormatException || error is ArgumentError) {
      _sendJson(response, HttpStatus.badRequest, {'error': error.toString()});
    } else if (error is StateError) {
      _sendJson(response, HttpStatus.conflict, {'error': error.toString()});
    } else if (error is JiraApiException) {
      _sendJson(
        response,
        error.statusCode == HttpStatus.notFound
            ? HttpStatus.notFound
            : HttpStatus.badGateway,
        {'error': error.toString()},
      );
    } else {
      _sendJson(response, HttpStatus.internalServerError, {
        'error': error.toString(),
      });
    }
  }

  void _sendHelp(HttpResponse response) {
    response.headers.contentType = ContentType(
      'text',
      'markdown',
      charset: 'utf-8',
    );
    response.write(_buildHelpMarkdown());
    response.close();
  }

  void _sendOpenApi(HttpResponse response) {
    _sendJson(response, HttpStatus.ok, _buildOpenApiSpec());
  }

  void _sendJson(HttpResponse response, int statusCode, Object body) {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    response.close();
  }

  Future<Map<String, dynamic>?> _parseJsonBody(
    HttpRequest request,
    HttpResponse response,
  ) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      if (content.trim().isEmpty) return {};
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      _sendJson(response, HttpStatus.badRequest, {
        'error': 'JSON body must be an object',
      });
      return null;
    } catch (e) {
      _sendJson(response, HttpStatus.badRequest, {'error': 'Invalid JSON: $e'});
      return null;
    }
  }

  Map<String, dynamic> _formatLog(LocalLog log, AppState state) {
    final issue = state.issues
        .where((i) => i.issueId == log.issueId)
        .firstOrNull;
    final key = issue?.key ?? log.issueId;
    final draftDate = state.getDraftDateForLog(log.id);
    return {
      'id': log.id,
      'issue_id': log.issueId,
      'issue_key': key,
      'issue_title': log.titleSnapshot,
      'duration_seconds': log.accumulatedSeconds,
      'duration_minutes': (log.accumulatedSeconds / 60).round(),
      'description': log.description,
      'created_at': log.createdAtUtc.toIso8601String(),
      'is_running': log.isRunning,
      'is_manual': log.isManual,
      'fixed_start_time': log.fixedStartTime,
      'availability': log.isRunning
          ? 'running'
          : draftDate != null
          ? 'in_draft'
          : 'free',
      'draft_date': draftDate,
    };
  }

  DateTime _parseDateOnly(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) throw FormatException('Expected YYYY-MM-DD');
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw FormatException('Invalid calendar date');
    }
    return parsed;
  }

  void _handleGetIssues(HttpRequest request, HttpResponse response) {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.serviceUnavailable, {
        'error': 'AppState not available',
      });
      return;
    }
    final query = request.uri.queryParameters['q'] ?? '';
    final result = state
        .searchIssuesLocally(query)
        .map(
          (issue) => {
            'issue_id': issue.issueId,
            'issue_key': issue.key,
            'summary': issue.summary,
            'status': issue.status,
          },
        )
        .toList();
    _sendJson(response, HttpStatus.ok, result);
  }

  Future<void> _handleGetIssueWorklogs(
    HttpResponse response,
    String issueRef,
  ) async {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.serviceUnavailable, {
        'error': 'AppState not available',
      });
      return;
    }
    try {
      final (issue, worklogs, accountId) = await state
          .fetchJiraWorklogsForIssue(issueRef);
      _sendJson(response, HttpStatus.ok, {
        'issue_id': issue.issueId,
        'issue_key': issue.key,
        'worklogs': [
          for (final log in worklogs)
            {
              'id': log.id,
              'start_utc': log.startUtc.toIso8601String(),
              'start_local': log.startUtc.toLocal().toIso8601String(),
              'duration_seconds': log.durationSeconds,
              'comment': log.comment,
              'author_account_id': log.authorAccountId,
              'is_mine': log.authorAccountId == accountId,
            },
        ],
      });
    } on ArgumentError catch (e) {
      _sendJson(response, HttpStatus.badRequest, {'error': e.toString()});
    } on StateError catch (e) {
      _sendJson(response, HttpStatus.conflict, {'error': e.toString()});
    } on JiraApiException catch (e) {
      _sendJson(
        response,
        e.statusCode == HttpStatus.notFound
            ? HttpStatus.notFound
            : HttpStatus.badGateway,
        {'error': e.toString()},
      );
    } catch (e) {
      _sendJson(response, HttpStatus.badGateway, {'error': e.toString()});
    }
  }

  Future<void> _handleGetIssueDetails(
    HttpResponse response,
    String issueRef,
  ) async {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.serviceUnavailable, {
        'error': 'AppState not available',
      });
      return;
    }
    try {
      _sendJson(
        response,
        HttpStatus.ok,
        await state.fetchJiraIssueDetails(issueRef),
      );
    } catch (e) {
      _sendIssueReadError(response, e);
    }
  }

  Future<void> _handleDownloadAttachment(
    HttpResponse response,
    String issueRef,
    String attachmentId,
  ) async {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.serviceUnavailable, {
        'error': 'AppState not available',
      });
      return;
    }
    var streaming = false;
    try {
      final (attachment, jiraResponse) = await state.downloadJiraAttachment(
        issueRef,
        attachmentId,
      );
      final filename = attachment['filename']?.toString() ?? attachmentId;
      response.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/octet-stream',
      );
      response.headers.set(
        'Content-Disposition',
        "attachment; filename*=UTF-8''${Uri.encodeComponent(filename)}",
      );
      response.headers.set('X-Content-Type-Options', 'nosniff');
      streaming = true;
      await response.addStream(jiraResponse.stream);
      await response.close();
    } catch (e) {
      if (!streaming) {
        _sendIssueReadError(response, e);
      } else {
        await response.close();
      }
    }
  }

  void _sendIssueReadError(HttpResponse response, Object error) {
    if (error is ArgumentError) {
      _sendJson(response, HttpStatus.badRequest, {'error': error.toString()});
    } else if (error is StateError) {
      _sendJson(response, HttpStatus.conflict, {'error': error.toString()});
    } else if (error is JiraApiException) {
      _sendJson(
        response,
        error.statusCode == HttpStatus.notFound
            ? HttpStatus.notFound
            : HttpStatus.badGateway,
        {'error': error.toString()},
      );
    } else {
      _sendJson(response, HttpStatus.badGateway, {'error': error.toString()});
    }
  }

  Future<void> _handleGetLogs(
    HttpRequest request,
    HttpResponse response,
  ) async {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.ok, []);
      return;
    }

    final query = (request.uri.queryParameters['q'] ?? '').trim().toLowerCase();
    final issueKey = request.uri.queryParameters['issue_key']
        ?.trim()
        .toLowerCase();
    final availability = request.uri.queryParameters['availability']
        ?.trim()
        .toLowerCase();
    final result = state.unconsumedLogs
        .where((log) {
          final item = _formatLog(log, state);
          if (query.isNotEmpty &&
              !'${item['issue_key']} ${item['issue_title']} ${item['description']}'
                  .toLowerCase()
                  .contains(query)) {
            return false;
          }
          if (issueKey != null &&
              issueKey.isNotEmpty &&
              (item['issue_key'] as String).toLowerCase() != issueKey) {
            return false;
          }
          return availability == null ||
              availability.isEmpty ||
              item['availability'] == availability;
        })
        .map((log) => _formatLog(log, state))
        .toList();
    _sendJson(response, HttpStatus.ok, result);
  }

  Future<void> _handlePostLogs(
    HttpRequest request,
    HttpResponse response,
  ) async {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.serviceUnavailable, {
        'error': 'AppState not available',
      });
      return;
    }

    final body = await _parseJsonBody(request, response);
    if (body == null) return;

    final issueKey = body['issue_key'] as String?;
    if (issueKey == null || issueKey.trim().isEmpty) {
      _sendJson(response, HttpStatus.badRequest, {
        'error': 'Field "issue_key" is required',
      });
      return;
    }

    final durationMinutes = body['duration_minutes'] as int?;
    final durationSeconds = body['duration_seconds'] as int?;
    final totalSeconds = durationSeconds ?? ((durationMinutes ?? 0) * 60);

    if (totalSeconds <= 0) {
      _sendJson(response, HttpStatus.badRequest, {
        'error':
            'Duration must be greater than 0 (specify "duration_minutes" or "duration_seconds")',
      });
      return;
    }

    final description = (body['description'] as String?) ?? '';
    final fixedStartTime = body['fixed_start_time'] as String?;

    if (fixedStartTime != null && fixedStartTime.trim().isNotEmpty) {
      final parts = fixedStartTime.trim().split(':');
      if (parts.length != 2) {
        _sendJson(response, HttpStatus.badRequest, {
          'error':
              'Invalid "fixed_start_time" format "$fixedStartTime". Expected HH:MM',
        });
        return;
      }
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
        _sendJson(response, HttpStatus.badRequest, {
          'error':
              'Invalid "fixed_start_time" value. Hours must be 0-23, minutes 0-59',
        });
        return;
      }
    }

    try {
      final issue = await state.resolveIssueStrict(issueKey);
      final log = await state.addManualLog(
        issueId: issue.issueId,
        durationSeconds: totalSeconds,
        description: description,
        fixedStartTime: fixedStartTime?.trim(),
      );

      _sendJson(response, HttpStatus.created, _formatLog(log, state));
    } on JiraApiException catch (e) {
      final status = e.statusCode == HttpStatus.notFound
          ? HttpStatus.notFound
          : HttpStatus.badGateway;
      _sendJson(response, status, {'error': e.toString()});
    } catch (e) {
      _sendJson(response, HttpStatus.badRequest, {'error': e.toString()});
    }
  }

  Future<void> _handlePatchLog(
    HttpRequest request,
    HttpResponse response,
    String id,
  ) async {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.serviceUnavailable, {
        'error': 'AppState not available',
      });
      return;
    }

    final log = state.logs.where((l) => l.id == id).firstOrNull;
    if (log == null) {
      _sendJson(response, HttpStatus.notFound, {
        'error': 'Log with id "$id" not found',
      });
      return;
    }

    final body = await _parseJsonBody(request, response);
    if (body == null) return;

    final durationMinutes = body['duration_minutes'] as int?;
    final durationSeconds = body['duration_seconds'] as int?;
    final totalSeconds =
        durationSeconds ??
        (durationMinutes != null
            ? durationMinutes * 60
            : log.accumulatedSeconds);

    final description = (body['description'] as String?) ?? log.description;

    final hasFixedStartTime = body.containsKey('fixed_start_time');
    final fixedStartTime = body['fixed_start_time'] as String?;
    final clearFixedStartTime =
        (body['clear_fixed_start_time'] as bool?) ??
        (hasFixedStartTime &&
            (fixedStartTime == null || fixedStartTime.trim().isEmpty));

    if (fixedStartTime != null && fixedStartTime.trim().isNotEmpty) {
      final parts = fixedStartTime.trim().split(':');
      if (parts.length != 2) {
        _sendJson(response, HttpStatus.badRequest, {
          'error':
              'Invalid "fixed_start_time" format "$fixedStartTime". Expected HH:MM',
        });
        return;
      }
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
        _sendJson(response, HttpStatus.badRequest, {
          'error':
              'Invalid "fixed_start_time" value. Hours must be 0-23, minutes 0-59',
        });
        return;
      }
    }

    try {
      await state.editLog(
        logId: id,
        durationSeconds: totalSeconds,
        description: description,
        fixedStartTime: fixedStartTime?.trim(),
        clearFixedStartTime: clearFixedStartTime,
      );

      final updated = state.logs.firstWhere((l) => l.id == id);
      _sendJson(response, HttpStatus.ok, _formatLog(updated, state));
    } catch (e) {
      _sendJson(response, HttpStatus.badRequest, {'error': e.toString()});
    }
  }

  Future<void> _handleSplitLog(
    HttpRequest request,
    HttpResponse response,
    String id,
  ) async {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.serviceUnavailable, {
        'error': 'AppState not available',
      });
      return;
    }

    final log = state.logs.where((l) => l.id == id).firstOrNull;
    if (log == null) {
      _sendJson(response, HttpStatus.notFound, {
        'error': 'Log with id "$id" not found',
      });
      return;
    }
    if (log.isRunning) {
      _sendJson(response, HttpStatus.badRequest, {
        'error': 'Cannot split a running log. Pause it first.',
      });
      return;
    }
    if (log.isConsumed || state.isLogInDraft(id)) {
      _sendJson(response, HttpStatus.badRequest, {
        'error':
            'Cannot split a log that has already been included in a day draft.',
      });
      return;
    }

    final body = await _parseJsonBody(request, response);
    if (body == null) return;

    final part1Minutes = body['part1_minutes'] as int?;
    final part1Seconds = body['part1_seconds'] as int?;
    final splitOffset = part1Seconds ?? ((part1Minutes ?? 0) * 60);

    if (splitOffset <= 0 || splitOffset >= log.accumulatedSeconds) {
      _sendJson(response, HttpStatus.badRequest, {
        'error':
            'Split offset must be > 0 and < log duration (${log.accumulatedSeconds}s). Got $splitOffset',
      });
      return;
    }

    final part1Desc = body['part1_description'] as String?;
    final part2Desc = body['part2_description'] as String?;

    try {
      final (l1, l2) = await state.splitLog(
        logId: id,
        part1DurationSeconds: splitOffset,
        part1Description: part1Desc,
        part2Description: part2Desc,
      );

      _sendJson(response, HttpStatus.ok, [
        _formatLog(l1, state),
        _formatLog(l2, state),
      ]);
    } catch (e) {
      _sendJson(response, HttpStatus.badRequest, {'error': e.toString()});
    }
  }

  Future<void> _handleMergeLogs(
    HttpRequest request,
    HttpResponse response,
  ) async {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.serviceUnavailable, {
        'error': 'AppState not available',
      });
      return;
    }

    final body = await _parseJsonBody(request, response);
    if (body == null) return;

    final sourceLogIdsRaw = body['source_log_ids'];
    if (sourceLogIdsRaw is! List || sourceLogIdsRaw.length < 2) {
      _sendJson(response, HttpStatus.badRequest, {
        'error':
            'Field "source_log_ids" must be an array with at least 2 log IDs',
      });
      return;
    }

    final sourceLogIds = sourceLogIdsRaw.map((e) => e.toString()).toList();
    final targetIssueKey = body['target_issue_key'] as String?;
    String? targetIssueId;
    if (targetIssueKey != null && targetIssueKey.trim().isNotEmpty) {
      try {
        final issue = await state.resolveIssueStrict(targetIssueKey.trim());
        targetIssueId = issue.issueId;
      } on JiraApiException catch (e) {
        final status = e.statusCode == HttpStatus.notFound
            ? HttpStatus.notFound
            : HttpStatus.badGateway;
        _sendJson(response, status, {
          'error': 'Target issue "$targetIssueKey" could not be resolved: $e',
        });
        return;
      } catch (e) {
        _sendJson(response, HttpStatus.badRequest, {
          'error': 'Target issue "$targetIssueKey" could not be resolved: $e',
        });
        return;
      }
    }

    final description = body['description'] as String?;

    try {
      final merged = await state.mergeLogs(
        logIds: sourceLogIds,
        targetIssueId: targetIssueId,
        description: description,
      );

      _sendJson(response, HttpStatus.ok, _formatLog(merged, state));
    } catch (e) {
      _sendJson(response, HttpStatus.badRequest, {'error': e.toString()});
    }
  }

  Future<void> _handleDeleteLog(
    HttpRequest request,
    HttpResponse response,
    String id,
  ) async {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.serviceUnavailable, {
        'error': 'AppState not available',
      });
      return;
    }

    final log = state.logs.where((l) => l.id == id).firstOrNull;
    if (log == null) {
      _sendJson(response, HttpStatus.notFound, {
        'error': 'Log with id "$id" not found',
      });
      return;
    }

    try {
      await state.deleteLog(id);
      _sendJson(response, HttpStatus.ok, {'status': 'deleted', 'id': id});
    } catch (e) {
      _sendJson(response, HttpStatus.badRequest, {'error': e.toString()});
    }
  }

  Future<void> _handleGetDay(HttpRequest request, HttpResponse response) async {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.serviceUnavailable, {
        'error': 'AppState not available',
      });
      return;
    }

    final dateParam = request.uri.queryParameters['date'];
    late final DateTime targetDate;
    try {
      targetDate = dateParam == null || dateParam.trim().isEmpty
          ? state.selectedDate
          : _parseDateOnly(dateParam.trim());
    } on FormatException {
      _sendJson(response, HttpStatus.badRequest, {
        'error': 'Invalid date format. Expected YYYY-MM-DD',
      });
      return;
    }

    final dateStr =
        '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

    late final List<ImportedWorklog> existingWorklogs;
    try {
      existingWorklogs = await state.fetchJiraWorklogsForDateScoped(targetDate);
    } catch (e) {
      _sendJson(response, HttpStatus.badGateway, {
        'error': 'Не удалось загрузить worklogs Jira для $dateStr: $e',
      });
      return;
    }

    // Read the local snapshot after the Jira await so segments and revision match.
    final draft = state.store.getDayDraft(
      scope: state.activeScope,
      date: dateStr,
    );
    final segments = draft == null
        ? const <Segment>[]
        : state.store.getSegments(draftId: draft.id);
    final breaks = draft == null
        ? const <Break>[]
        : state.store.getBreaks(draftId: draft.id);
    final revision = draft == null ? null : state.dayDraftRevision(draft);
    final issuesMap = {for (final i in state.issues) i.issueId: i};

    final existingList = existingWorklogs
        .map(
          (e) => {
            'id': e.id,
            'issue_id': e.issueId,
            'issue_key': e.issueKey ?? issuesMap[e.issueId]?.key ?? e.issueId,
            'start_utc': e.startUtc.toIso8601String(),
            'start_local': e.startUtc.toLocal().toIso8601String(),
            'duration_seconds': e.durationSeconds,
            'duration_minutes': (e.durationSeconds / 60).round(),
            'comment': e.comment,
          },
        )
        .toList();

    Map<String, dynamic>? draftMap;
    if (draft != null) {
      draftMap = {
        'id': draft.id,
        'date': draft.date,
        'revision': revision,
        'start_utc': draft.startUtc.toIso8601String(),
        'end_utc': draft.endUtc.toIso8601String(),
        'status': draft.status.name,
        'segments': segments
            .map(
              (s) => {
                'id': s.id,
                'source_log_id': s.sourceLogId,
                'issue_key': issuesMap[s.issueId]?.key ?? s.issueId,
                'start_utc': s.startUtc.toIso8601String(),
                'start_local':
                    '${s.startUtc.toLocal().hour.toString().padLeft(2, '0')}:${s.startUtc.toLocal().minute.toString().padLeft(2, '0')}',
                'duration_seconds': s.durationSeconds,
                'duration_minutes': (s.durationSeconds / 60).round(),
                'description': s.description,
                'send_state': s.sendState.name,
                'is_fixed': s.isFixed,
              },
            )
            .toList(),
        'breaks': breaks
            .map(
              (b) => {
                'id': b.id,
                'start_utc': b.startUtc.toIso8601String(),
                'start_local':
                    '${b.startUtc.toLocal().hour.toString().padLeft(2, '0')}:${b.startUtc.toLocal().minute.toString().padLeft(2, '0')}',
                'duration_seconds': b.durationSeconds,
                'duration_minutes': (b.durationSeconds / 60).round(),
              },
            )
            .toList(),
      };
    }

    _sendJson(response, HttpStatus.ok, {
      'date': dateStr,
      'existing_worklogs': existingList,
      'draft': draftMap,
      'revision': revision,
    });
  }

  Future<void> _handlePostDay(
    HttpRequest request,
    HttpResponse response,
  ) async {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.serviceUnavailable, {
        'error': 'AppState not available',
      });
      return;
    }

    final body = await _parseJsonBody(request, response);
    if (body == null) return;

    final dateStr = body['date'] as String? ?? state.selectedDateString;
    late final DateTime targetDate;
    try {
      targetDate = _parseDateOnly(dateStr);
    } on FormatException {
      _sendJson(response, HttpStatus.badRequest, {
        'error': 'Invalid date format "$dateStr". Expected YYYY-MM-DD',
      });
      return;
    }

    final rawSegments = body['segments'];
    if (rawSegments is! List || rawSegments.isEmpty) {
      _sendJson(response, HttpStatus.badRequest, {
        'error': 'Field "segments" must be a non-empty array',
      });
      return;
    }

    final inputSegments = <AgentSegmentInput>[];

    for (var i = 0; i < rawSegments.length; i++) {
      final item = rawSegments[i];
      if (item is! Map<String, dynamic>) {
        _sendJson(response, HttpStatus.badRequest, {
          'error': 'Each segment must be an object at index $i',
        });
        return;
      }

      final issueKey = item['issue_key'] as String?;
      if (issueKey != null && issueKey.trim().isEmpty) {
        _sendJson(response, HttpStatus.badRequest, {
          'error': 'Segment "issue_key" cannot be empty at index $i',
        });
        return;
      }

      final sourceLogId = item['source_log_id'] as String?;
      if (sourceLogId == null || sourceLogId.trim().isEmpty) {
        _sendJson(response, HttpStatus.badRequest, {
          'error': 'Segment at index $i missing "source_log_id"',
        });
        return;
      }

      final startRaw = item['start'] as String?;
      if (startRaw == null || startRaw.trim().isEmpty) {
        _sendJson(response, HttpStatus.badRequest, {
          'error': 'Segment at index $i missing "start"',
        });
        return;
      }

      DateTime startUtc;
      final trimmedStart = startRaw.trim();
      if (trimmedStart.contains(':') && !trimmedStart.contains('T')) {
        // Формат HH:MM или H:MM локального времени дня
        final parts = trimmedStart.split(':');
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null ||
            minute == null ||
            hour < 0 ||
            hour > 23 ||
            minute < 0 ||
            minute > 59) {
          _sendJson(response, HttpStatus.badRequest, {
            'error':
                'Invalid time format "$startRaw" at index $i. Expected HH:MM',
          });
          return;
        }
        final localDt = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hour,
          minute,
        );
        startUtc = localDt.toUtc();
      } else {
        // Формат ISO 8601
        try {
          startUtc = DateTime.parse(trimmedStart).toUtc();
        } catch (e) {
          _sendJson(response, HttpStatus.badRequest, {
            'error': 'Invalid ISO timestamp "$startRaw" at index $i',
          });
          return;
        }
      }

      final durMinutes = item['duration_minutes'] as int?;
      final durSeconds = item['duration_seconds'] as int?;
      final totalSec = durSeconds ?? ((durMinutes ?? 0) * 60);

      if (totalSec <= 0) {
        _sendJson(response, HttpStatus.badRequest, {
          'error':
              'Segment at index $i duration must be > 0 (specify "duration_minutes" or "duration_seconds")',
        });
        return;
      }

      final desc = (item['description'] as String?) ?? '';
      final isFixed =
          (item['is_fixed'] as bool?) ?? (item['fixed_start_time'] != null);
      final fixedStartTime = item['fixed_start_time'] as String?;

      inputSegments.add(
        AgentSegmentInput(
          issueKey: issueKey?.trim(),
          sourceLogId: sourceLogId.trim(),
          startUtc: startUtc,
          durationSeconds: totalSec,
          description: desc,
          isFixed: isFixed,
          fixedStartTime: fixedStartTime?.trim(),
        ),
      );
    }

    late final List<ImportedWorklog> existingWorklogs;
    try {
      existingWorklogs = await state.fetchJiraWorklogsForDateScoped(targetDate);
    } catch (e) {
      _sendJson(response, HttpStatus.badGateway, {
        'error': 'Не удалось загрузить worklogs Jira для $dateStr: $e',
      });
      return;
    }

    try {
      final draft = await state.applyAgentDayPlan(
        targetDate: targetDate,
        inputSegments: inputSegments,
        existingWorklogs: existingWorklogs,
        baseRevision: body['base_revision'] as String?,
      );

      final totalWorkSec = inputSegments.fold<int>(
        0,
        (sum, s) => sum + s.durationSeconds,
      );

      _sendJson(response, HttpStatus.ok, {
        'status': 'ok',
        'draft_id': draft.id,
        'date': draft.date,
        'revision': state.dayDraftRevision(draft),
        'segments_count': inputSegments.length,
        'total_work_seconds': totalWorkSec,
        'total_work_minutes': (totalWorkSec / 60).round(),
      });
    } on DayBuilderException catch (e) {
      _sendJson(response, HttpStatus.badRequest, {'error': e.message});
    } on AgentDayRevisionConflict catch (e) {
      _sendJson(response, HttpStatus.conflict, {'error': e.message});
    } catch (e) {
      _sendJson(response, HttpStatus.badRequest, {'error': e.toString()});
    }
  }

  String _buildHelpMarkdown() {
    return '''# Jira Time Tracker Local Agent API

Локальный REST API для интеграции AI-агентов (Claude, Antigravity, MCP-серверов и скриптов).

Базовый URL: `$url`

## Модель и правила
- `LocalLog` — источник работы; `Segment` — отдельный worklog, который пользователь сможет отправить в Jira.
- Каждый segment в `POST /api/day` обязан содержать `source_log_id`. Несколько segments могут ссылаться на один источник в пределах одного дня.
- Рабочие segments и существующие Jira worklogs могут пересекаться по времени; каждый segment останется отдельным worklog после подтверждения в UI. Паузы не пересекаются с работой.
- Источник должен быть остановлен, не отправлен и не занят активным черновиком другой даты. Чтобы разнести работу на разные даты, сначала раздели source через `POST /api/logs/{id}/split`.
- Агент заменяет черновик целиком. Перед записью вызови `GET /api/day?date=YYYY-MM-DD`; если `draft` существует, передай его top-level `revision` как `base_revision`. Ответ `409` требует перечитать день и собрать snapshot заново.
- Jira worklogs в GET/POST `/api/day` загружаются для указанной даты; при ошибке Jira возвращается `502`.
- Финальную отправку worklogs в Jira всегда выполняет пользователь в приложении.

## Поиск и очередь
- `GET /api/issues?q=текст` — поиск по локальному каталогу: key, summary и status. Удалённый fuzzy search не выполняется.
- `GET /api/issues/PROJ-123` — актуальная карточка Jira: текст описания, все доступные комментарии и метаданные вложений с `download_path`.
- `GET /api/issues/PROJ-123/attachments/10001` — бинарное содержимое вложения; ID берётся из карточки. Файл не сохраняется приложением на диск.
- `GET /api/issues/PROJ-123/worklogs` — все доступные worklogs Jira по задаче, включая других авторов; `is_mine` отмечает записи текущего аккаунта.
- `GET /api/logs?q=текст&issue_key=PROJ-123&availability=free` — очередь и фильтры. `availability`: `free`, `running` или `in_draft`; запись также содержит `draft_date`.
- `POST /api/logs` создаёт source для известной локальной/Jira-задачи; при неизвестной задаче и ошибке Jira запрос отклоняется, fallback-задача не создаётся.
- `POST /api/logs/{id}/split` и `POST /api/logs/merge` меняют исходные логи очереди. `PATCH /api/logs/{id}` и `DELETE /api/logs/{id}` управляют свободными логами.
- `GET /api/quick-issues` возвращает быстрые задачи текущего Jira-подключения в порядке добавления. Поля: `issue_id`, `key`, `summary`, `note` (локальное описание); без активного подключения ответ `409`.
- `POST /api/quick-issues` принимает `{"issue_key":"PROJ-123","note":"Подсказка"}` и добавляет проверенную через Jira задачу. Повторный POST сохраняет позицию и обновляет `note`, если оно передано.
- `PATCH /api/quick-issues/{issueId}` принимает `{"note":"Новое описание"}`; `null` очищает описание. `DELETE /api/quick-issues/{issueId}` убирает ссылку из быстрого списка, не удаляя задачу и логи.

## Snapshot дня
1. Получи доступные источники через `GET /api/logs` и данные дня через `GET /api/day?date=...`.
2. Для каждого segment передай `source_log_id`, `start` (`HH:MM` или ISO-8601), длительность и описание. `issue_key` необязателен; если передан, он должен совпадать с задачей источника.
3. Передай массив `segments` целиком. Если GET вернул draft, включи его revision в `base_revision`.

```json
{
  "date": "2026-09-17",
  "base_revision": "revision-from-GET",
  "segments": [
    {"source_log_id": "uuid-1", "start": "09:00", "duration_minutes": 30, "description": "Разбор"},
    {"source_log_id": "uuid-1", "start": "09:45", "duration_minutes": 30, "description": "Реализация"}
  ]
}
```

`GET /api/help` содержит эту справку; `GET /api/openapi.json` возвращает OpenAPI 3.0.0.
''';
  }

  Map<String, dynamic> _buildOpenApiSpec() {
    return {
      'openapi': '3.0.0',
      'info': {
        'title': 'Jira Time Tracker Agent API',
        'version': '1.0.0',
        'description':
            'Local REST API for AI agents to record time and save day drafts. Jira submission is only available in the UI.',
      },
      'servers': [
        {'url': url, 'description': 'Local Tracker Instance'},
      ],
      'paths': {
        '/api/help': {
          'get': {
            'summary': 'Get human-readable Markdown help',
            'responses': {
              '200': {'description': 'Markdown text'},
            },
          },
        },
        '/api/openapi.json': {
          'get': {
            'summary': 'Get OpenAPI 3.0 specification',
            'responses': {
              '200': {'description': 'OpenAPI JSON schema'},
            },
          },
        },
        '/api/issues': {
          'get': {
            'summary': 'Search the local issue catalog',
            'parameters': [
              {
                'name': 'q',
                'in': 'query',
                'required': false,
                'schema': {'type': 'string'},
              },
            ],
            'responses': {
              '200': {
                'description':
                    'Issues matching key, summary, or status; no remote fuzzy search',
              },
              '503': {'description': 'AppState unavailable'},
            },
          },
        },
        '/api/issues/{issueKey}': {
          'get': {
            'summary':
                'Read current Jira issue text, all visible comments and attachment metadata',
            'parameters': [
              {
                'name': 'issueKey',
                'in': 'path',
                'required': true,
                'schema': {'type': 'string', 'example': 'PROJ-123'},
              },
            ],
            'responses': {
              '200': {
                'description':
                    'Fresh Jira issue details; comments are fully paginated',
                'content': {
                  'application/json': {
                    'schema': {
                      'type': 'object',
                      'properties': {
                        'issue_id': {'type': 'string'},
                        'issue_key': {'type': 'string'},
                        'summary': {'type': 'string'},
                        'description': {'type': 'string', 'nullable': true},
                        'status': {'type': 'string', 'nullable': true},
                        'issue_type': {'type': 'string', 'nullable': true},
                        'priority': {'type': 'string', 'nullable': true},
                        'assignee': {'type': 'string', 'nullable': true},
                        'labels': {
                          'type': 'array',
                          'items': {'type': 'string'},
                        },
                        'created': {'type': 'string', 'nullable': true},
                        'updated': {'type': 'string', 'nullable': true},
                        'comments': {
                          'type': 'array',
                          'items': {
                            'type': 'object',
                            'properties': {
                              'id': {'type': 'string'},
                              'author_account_id': {
                                'type': 'string',
                                'nullable': true,
                              },
                              'author_name': {
                                'type': 'string',
                                'nullable': true,
                              },
                              'created': {'type': 'string', 'nullable': true},
                              'updated': {'type': 'string', 'nullable': true},
                              'body': {'type': 'string', 'nullable': true},
                            },
                          },
                        },
                        'attachments': {
                          'type': 'array',
                          'items': {
                            'type': 'object',
                            'properties': {
                              'id': {'type': 'string'},
                              'filename': {'type': 'string'},
                              'mime_type': {'type': 'string', 'nullable': true},
                              'size_bytes': {
                                'type': 'integer',
                                'nullable': true,
                              },
                              'created': {'type': 'string', 'nullable': true},
                              'author_account_id': {
                                'type': 'string',
                                'nullable': true,
                              },
                              'author_name': {
                                'type': 'string',
                                'nullable': true,
                              },
                              'download_path': {'type': 'string'},
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
              '400': {'description': 'Invalid issue key or ID'},
              '404': {'description': 'Issue not found in Jira'},
              '409': {'description': 'No active Jira connection'},
              '502': {
                'description': 'Jira issue or comments could not be loaded',
              },
            },
          },
        },
        '/api/issues/{issueKey}/attachments/{attachmentId}': {
          'get': {
            'summary': 'Download one attachment belonging to the Jira issue',
            'parameters': [
              {
                'name': 'issueKey',
                'in': 'path',
                'required': true,
                'schema': {'type': 'string'},
              },
              {
                'name': 'attachmentId',
                'in': 'path',
                'required': true,
                'schema': {'type': 'string', 'pattern': r'^\d+$'},
              },
            ],
            'responses': {
              '200': {
                'description':
                    'Binary attachment with Content-Disposition filename',
                'content': {
                  'application/octet-stream': {
                    'schema': {'type': 'string', 'format': 'binary'},
                  },
                },
              },
              '400': {'description': 'Invalid issue key or attachment ID'},
              '404': {'description': 'Issue or attachment not found'},
              '409': {'description': 'No active Jira connection'},
              '502': {'description': 'Jira attachment could not be loaded'},
            },
          },
        },
        '/api/issues/{issueKey}/worklogs': {
          'get': {
            'summary': 'Read all visible Jira worklogs for one issue',
            'parameters': [
              {
                'name': 'issueKey',
                'in': 'path',
                'required': true,
                'description': 'Jira issue key or numeric ID',
                'schema': {'type': 'string', 'example': 'PROJ-123'},
              },
            ],
            'responses': {
              '200': {
                'description':
                    'Issue and its visible Jira worklogs, including author_account_id and is_mine',
                'content': {
                  'application/json': {
                    'schema': {
                      'type': 'object',
                      'properties': {
                        'issue_id': {'type': 'string'},
                        'issue_key': {'type': 'string'},
                        'worklogs': {
                          'type': 'array',
                          'items': {
                            'type': 'object',
                            'properties': {
                              'id': {'type': 'string'},
                              'start_utc': {'type': 'string'},
                              'start_local': {'type': 'string'},
                              'duration_seconds': {'type': 'integer'},
                              'comment': {'type': 'string', 'nullable': true},
                              'author_account_id': {'type': 'string'},
                              'is_mine': {'type': 'boolean'},
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
              '400': {'description': 'Invalid issue key or ID'},
              '404': {'description': 'Issue not found in Jira'},
              '409': {'description': 'No active Jira connection'},
              '502': {'description': 'Jira worklogs could not be loaded'},
            },
          },
        },
        '/api/logs': {
          'get': {
            'summary': 'List unconsumed logs with availability',
            'parameters': [
              {
                'name': 'q',
                'in': 'query',
                'required': false,
                'schema': {'type': 'string'},
              },
              {
                'name': 'issue_key',
                'in': 'query',
                'required': false,
                'schema': {'type': 'string'},
              },
              {
                'name': 'availability',
                'in': 'query',
                'required': false,
                'schema': {
                  'type': 'string',
                  'enum': ['free', 'running', 'in_draft'],
                },
              },
            ],
            'responses': {
              '200': {
                'description': 'Logs include availability and draft_date',
              },
            },
          },
          'post': {
            'summary': 'Create a new time log for an issue',
            'requestBody': {
              'required': true,
              'content': {
                'application/json': {
                  'schema': {
                    'type': 'object',
                    'required': ['issue_key'],
                    'properties': {
                      'issue_key': {'type': 'string', 'example': 'PROJ-123'},
                      'duration_minutes': {'type': 'integer', 'example': 45},
                      'duration_seconds': {'type': 'integer', 'example': 2700},
                      'description': {
                        'type': 'string',
                        'example': 'Debugging issue',
                      },
                      'fixed_start_time': {
                        'type': 'string',
                        'example': '11:00',
                        'description': 'Optional fixed start time (HH:MM)',
                      },
                    },
                  },
                },
              },
            },
            'responses': {
              '201': {'description': 'Log created'},
              '400': {'description': 'Invalid parameters'},
              '404': {'description': 'Issue not found in Jira'},
              '502': {'description': 'Jira could not resolve the issue'},
            },
          },
        },
        '/api/logs/merge': {
          'post': {
            'summary': 'Merge multiple unsubmitted time logs into one',
            'requestBody': {
              'required': true,
              'content': {
                'application/json': {
                  'schema': {
                    'type': 'object',
                    'required': ['source_log_ids'],
                    'properties': {
                      'source_log_ids': {
                        'type': 'array',
                        'items': {'type': 'string'},
                        'example': ['uuid-1', 'uuid-2'],
                      },
                      'target_issue_key': {
                        'type': 'string',
                        'example': 'PROJ-123',
                        'description':
                            'Optional target issue key (defaults to first log issue)',
                      },
                      'description': {
                        'type': 'string',
                        'example': 'Combined description',
                      },
                    },
                  },
                },
              },
            },
            'responses': {
              '200': {'description': 'Merged log'},
              '400': {'description': 'Invalid parameters or logs not found'},
            },
          },
        },
        '/api/logs/{id}': {
          'patch': {
            'summary': 'Update an unsubmitted time log',
            'parameters': [
              {
                'name': 'id',
                'in': 'path',
                'required': true,
                'schema': {'type': 'string'},
              },
            ],
            'requestBody': {
              'required': false,
              'content': {
                'application/json': {
                  'schema': {
                    'type': 'object',
                    'properties': {
                      'duration_minutes': {'type': 'integer', 'example': 45},
                      'duration_seconds': {'type': 'integer', 'example': 2700},
                      'description': {
                        'type': 'string',
                        'example': 'Updated description',
                      },
                      'fixed_start_time': {
                        'type': 'string',
                        'example': '11:00',
                      },
                      'clear_fixed_start_time': {
                        'type': 'boolean',
                        'example': false,
                      },
                    },
                  },
                },
              },
            },
            'responses': {
              '200': {'description': 'Log updated'},
              '404': {'description': 'Log not found or already consumed'},
            },
          },
          'delete': {
            'summary': 'Delete an unsubmitted time log',
            'parameters': [
              {
                'name': 'id',
                'in': 'path',
                'required': true,
                'schema': {'type': 'string'},
              },
            ],
            'responses': {
              '200': {'description': 'Log deleted'},
              '404': {'description': 'Log not found'},
            },
          },
        },
        '/api/logs/{id}/split': {
          'post': {
            'summary': 'Split an unsubmitted time log into two parts',
            'parameters': [
              {
                'name': 'id',
                'in': 'path',
                'required': true,
                'schema': {'type': 'string'},
              },
            ],
            'requestBody': {
              'required': true,
              'content': {
                'application/json': {
                  'schema': {
                    'type': 'object',
                    'properties': {
                      'part1_minutes': {'type': 'integer', 'example': 30},
                      'part1_seconds': {'type': 'integer', 'example': 1800},
                      'part1_description': {
                        'type': 'string',
                        'example': 'First half',
                      },
                      'part2_description': {
                        'type': 'string',
                        'example': 'Second half',
                      },
                    },
                  },
                },
              },
            },
            'responses': {
              '200': {'description': 'Array of two created logs'},
              '400': {'description': 'Invalid split offset or log in draft'},
              '404': {'description': 'Log not found'},
            },
          },
        },
        '/api/day': {
          'get': {
            'summary': 'Get target-date Jira worklogs and day snapshot',
            'parameters': [
              {
                'name': 'date',
                'in': 'query',
                'required': false,
                'description':
                    'Target date (YYYY-MM-DD), defaults to the date currently selected in the UI',
                'schema': {'type': 'string', 'example': '2026-09-17'},
              },
            ],
            'responses': {
              '200': {
                'description':
                    'Day data with fresh date-scoped worklogs and revision',
              },
              '400': {'description': 'Invalid date'},
              '502': {'description': 'Jira worklogs could not be loaded'},
            },
          },
          'post': {
            'summary':
                'Atomically replace the complete day draft; worklogs may overlap',
            'requestBody': {
              'required': true,
              'content': {
                'application/json': {
                  'schema': {
                    'type': 'object',
                    'required': ['segments'],
                    'properties': {
                      'date': {'type': 'string', 'example': '2026-09-17'},
                      'base_revision': {
                        'type': 'string',
                        'description':
                            'Required when replacing an existing draft; use revision from GET /api/day',
                      },
                      'segments': {
                        'type': 'array',
                        'items': {
                          'type': 'object',
                          'required': ['source_log_id', 'start'],
                          'properties': {
                            'source_log_id': {
                              'type': 'string',
                              'description':
                                  'Existing stopped, unconsumed queue source',
                            },
                            'issue_key': {
                              'type': 'string',
                              'example': 'PROJ-123',
                              'description':
                                  'Optional; validated against source',
                            },
                            'start': {'type': 'string', 'example': '09:00'},
                            'duration_minutes': {
                              'type': 'integer',
                              'example': 60,
                            },
                            'duration_seconds': {
                              'type': 'integer',
                              'example': 3600,
                            },
                            'description': {
                              'type': 'string',
                              'example': 'Code review',
                            },
                            'is_fixed': {'type': 'boolean', 'example': true},
                            'fixed_start_time': {
                              'type': 'string',
                              'example': '11:00',
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
            'responses': {
              '200': {
                'description':
                    'Complete snapshot stored; response includes new revision',
              },
              '400': {'description': 'Invalid source or schedule'},
              '409': {
                'description':
                    'Draft revision is stale or day submission has begun',
              },
              '502': {'description': 'Jira worklogs could not be loaded'},
            },
          },
        },
        '/api/quick-issues': {
          'get': {
            'summary': 'List quick issues for the active Jira connection',
            'responses': {
              '200': {
                'description':
                    'Quick issues in insertion order for the active Jira scope',
                'content': {
                  'application/json': {
                    'schema': {
                      'type': 'array',
                      'items': {
                        'type': 'object',
                        'properties': {
                          'issue_id': {'type': 'string', 'example': '10042'},
                          'key': {'type': 'string', 'example': 'PROJ-123'},
                          'summary': {
                            'type': 'string',
                            'example': 'Implement feature',
                          },
                          'note': {
                            'type': 'string',
                            'nullable': true,
                            'example': 'Review first',
                          },
                        },
                      },
                    },
                  },
                },
              },
              '409': {'description': 'No active verified Jira connection'},
            },
          },
          'post': {
            'summary': 'Add or update one quick issue in the active Jira scope',
            'requestBody': {
              'required': true,
              'content': {
                'application/json': {
                  'schema': {
                    'type': 'object',
                    'required': ['issue_key'],
                    'properties': {
                      'issue_key': {'type': 'string', 'example': 'PROJ-123'},
                      'note': {'type': 'string', 'nullable': true},
                    },
                  },
                },
              },
            },
            'responses': {
              '201': {'description': 'Quick issue added'},
              '200': {
                'description':
                    'Existing quick issue returned; note updated if supplied',
              },
              '400': {'description': 'Invalid input'},
              '404': {'description': 'Issue not found in Jira'},
              '409': {'description': 'No connection or read-only instance'},
              '502': {'description': 'Jira issue lookup failed'},
            },
          },
        },
        '/api/quick-issues/{issueId}': {
          'patch': {
            'summary': 'Update the local note of a quick issue',
            'parameters': [
              {
                'name': 'issueId',
                'in': 'path',
                'required': true,
                'schema': {'type': 'string'},
              },
            ],
            'requestBody': {
              'required': true,
              'content': {
                'application/json': {
                  'schema': {
                    'type': 'object',
                    'required': ['note'],
                    'properties': {
                      'note': {'type': 'string', 'nullable': true},
                    },
                  },
                },
              },
            },
            'responses': {
              '200': {'description': 'Updated quick issue'},
              '400': {'description': 'Invalid note'},
              '404': {'description': 'Quick issue not found'},
              '409': {'description': 'No connection or read-only instance'},
            },
          },
          'delete': {
            'summary':
                'Remove a quick issue link without deleting issue or logs',
            'parameters': [
              {
                'name': 'issueId',
                'in': 'path',
                'required': true,
                'schema': {'type': 'string'},
              },
            ],
            'responses': {
              '204': {'description': 'Quick issue removed'},
              '404': {'description': 'Quick issue not found'},
              '409': {'description': 'No connection or read-only instance'},
            },
          },
        },
      },
    };
  }
}
