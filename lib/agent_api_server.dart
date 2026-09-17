import 'dart:convert';
import 'dart:io';
import 'app_state.dart';
import 'day_builder.dart';
import 'models.dart';
import 'service_tickets.dart';

/// Встроенный HTTP REST API сервер для взаимодействия с AI-агентами.
class AgentApiServer {
  final AppState? appState;
  final int initialPort;

  HttpServer? _server;
  int _actualPort = 0;

  AgentApiServer({
    this.appState,
    this.initialPort = 8765,
  });

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

Ты можешь взаимодействовать с локальным трекером времени пользователя через HTTP API на `$baseUrl`.

## Основные правила
1. Финальная отправка ворклогов в Jira всегда выполняется пользователем в интерфейсе приложения (кнопка «Отправить в Jira»). Твоя задача — залогировать время и/или составить расписание дня.
2. Время начала сегментов можно передавать в локальном формате "HH:MM" (например, "09:00", "13:30") или в ISO-8601 UTC.
3. В расписании дня паузы между сегментами образуются автоматически. Сегменты не должны пересекаться.

## Служебные тикеты (созвоны, код-ревью, почта и общие активности)
Если пользователь просит залогировать типовую активность без указания конкретного номера задачи в Jira, используй подходящий служебный тикет (EG-*):
- `EG-294`: Созвоны, синки, таунхоллы, митинги (Non-utilized Meeting/Events)
- `EG-304`: Собеседования, HR-активности (Recruiting)
- `EG-297`: Разбор и написание писем (Work with e-mails)
- `EG-295`: Общая активность, мелкие задачи без тикета (Other)
- `EG-301`: Обучение, самообразование, курсы (Personal Training)
- `EG-302`: Планирование продукта, роадмап (Product Planning)
- `EG-303`: Настройка софта / железа (Equipment setup)
- `EG-296`: Помощь клиентам, разбор инцидентов (Customer support)
- `EG-299`: Помощь сисадминам / инфраструктура (SysAdmin Assistance)
- `EG-300`: Помощь саппорту (Support Assistance)
- `EG-6`: Внутренние инструменты и скрипты (Methods/Tools Development)
- `EG-12`: Передача знаний / KT (Knowledge Transfer Meetings)
Полный список всех 18 служебных тикетов доступен через `GET /api/service-tickets`.

## Доступные эндпоинты

### 1. Получить список неотправленных логов
GET /api/logs
Ответ:
[
  {
    "id": "uuid-1",
    "issue_key": "PROJ-123",
    "issue_summary": "Описание задачи",
    "duration_minutes": 60,
    "description": "Сделал фичу"
  }
]

### 2. Залогировать затраченное время
POST /api/logs
Content-Type: application/json
{
  "issue_key": "PROJ-123",
  "duration_minutes": 90,
  "description": "Опциональный комментарий"
}
(Также поддерживается "duration_seconds" вместо "duration_minutes").

### 3. Изменить или удалить лог
PATCH /api/logs/{id}
{
  "duration_minutes": 45,
  "description": "Обновленный комментарий"
}

DELETE /api/logs/{id}

### 4. Получить состояние дня
GET /api/day?date=YYYY-MM-DD
(Параметр date опционален, по умолчанию — сегодня).
Возвращает существующие ворклоги Jira (jira_worklogs) и текущий черновик расписания (draft) с сегментами и паузами.

### 5. Сохранить расписание дня
POST /api/day
Content-Type: application/json
{
  "date": "YYYY-MM-DD",
  "segments": [
    {
      "issue_key": "PROJ-123",
      "start": "09:00",
      "duration_minutes": 90,
      "description": "Работа над модулем"
    },
    {
      "issue_key": "PROJ-456",
      "start": "11:00",
      "duration_minutes": 60,
      "source_log_id": "optional-log-uuid"
    }
  ]
}

### 6. Получить список служебных тикетов
GET /api/service-tickets
Ответ:
[
  {
    "key": "EG-294",
    "category": "Non-utilized Meeting/Events",
    "description": "Созвоны, синги, таунхоллы (не привязанные к конкретной задаче)"
  }
]

### 7. Справка и документация
- GET /api/help (справка по эндпоинтам)
- GET /api/openapi.json (OpenAPI 3.0 спецификация)
''';
  }

  void _handleRequest(HttpRequest request) async {
    final response = request.response;

    // CORS заголовки для всех ответов
    response.headers.set('Access-Control-Allow-Origin', '*');
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

      // Маршруты Ticket 02
      if (path == '/api/logs') {
        if (request.method == 'GET') {
          await _handleGetLogs(request, response);
          return;
        } else if (request.method == 'POST') {
          await _handlePostLogs(request, response);
          return;
        }
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

      if (path == '/api/service-tickets' && request.method == 'GET') {
        _handleGetServiceTickets(request, response);
        return;
      }

      // 404 Not Found
      _sendJson(
        response,
        HttpStatus.notFound,
        {'error': 'Not Found', 'path': path, 'method': request.method},
      );
    } catch (e, st) {
      _sendJson(
        response,
        HttpStatus.internalServerError,
        {'error': e.toString(), 'stackTrace': st.toString()},
      );
    }
  }

  void _handleGetServiceTickets(HttpRequest request, HttpResponse response) {
    final list = kServiceTickets.map((t) => {
      'key': t.key,
      'category': t.category,
      'description': t.description,
    }).toList();
    _sendJson(response, HttpStatus.ok, list);
  }

  void _sendHelp(HttpResponse response) {
    response.headers.contentType = ContentType('text', 'markdown', charset: 'utf-8');
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

  Future<Map<String, dynamic>?> _parseJsonBody(HttpRequest request, HttpResponse response) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      if (content.trim().isEmpty) return {};
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      _sendJson(response, HttpStatus.badRequest, {'error': 'JSON body must be an object'});
      return null;
    } catch (e) {
      _sendJson(response, HttpStatus.badRequest, {'error': 'Invalid JSON: $e'});
      return null;
    }
  }

  Future<void> _handleGetLogs(HttpRequest request, HttpResponse response) async {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.ok, []);
      return;
    }

    final unconsumed = state.unconsumedLogs;
    final issuesMap = {for (final i in state.issues) i.issueId: i};

    final result = unconsumed.map((log) {
      final issue = issuesMap[log.issueId];
      final key = issue?.key ?? log.issueId;
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
      };
    }).toList();

    _sendJson(response, HttpStatus.ok, result);
  }

  Future<void> _handlePostLogs(HttpRequest request, HttpResponse response) async {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.serviceUnavailable, {'error': 'AppState not available'});
      return;
    }

    final body = await _parseJsonBody(request, response);
    if (body == null) return;

    final issueKey = body['issue_key'] as String?;
    if (issueKey == null || issueKey.trim().isEmpty) {
      _sendJson(response, HttpStatus.badRequest, {'error': 'Field "issue_key" is required'});
      return;
    }

    final durationMinutes = body['duration_minutes'] as int?;
    final durationSeconds = body['duration_seconds'] as int?;
    final totalSeconds = durationSeconds ?? ((durationMinutes ?? 0) * 60);

    if (totalSeconds <= 0) {
      _sendJson(response, HttpStatus.badRequest, {
        'error': 'Duration must be greater than 0 (specify "duration_minutes" or "duration_seconds")'
      });
      return;
    }

    final description = (body['description'] as String?) ?? '';

    try {
      final issue = await state.resolveOrCreateIssue(issueKey);
      final log = await state.addManualLog(
        issueId: issue.issueId,
        durationSeconds: totalSeconds,
        description: description,
      );

      _sendJson(response, HttpStatus.created, {
        'id': log.id,
        'issue_id': issue.issueId,
        'issue_key': issue.key,
        'issue_title': issue.summary,
        'duration_seconds': log.accumulatedSeconds,
        'duration_minutes': (log.accumulatedSeconds / 60).round(),
        'description': log.description,
        'created_at': log.createdAtUtc.toIso8601String(),
      });
    } catch (e) {
      _sendJson(response, HttpStatus.badRequest, {'error': e.toString()});
    }
  }

  Future<void> _handlePatchLog(HttpRequest request, HttpResponse response, String id) async {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.serviceUnavailable, {'error': 'AppState not available'});
      return;
    }

    final log = state.logs.where((l) => l.id == id).firstOrNull;
    if (log == null) {
      _sendJson(response, HttpStatus.notFound, {'error': 'Log with id "$id" not found'});
      return;
    }

    final body = await _parseJsonBody(request, response);
    if (body == null) return;

    final durationMinutes = body['duration_minutes'] as int?;
    final durationSeconds = body['duration_seconds'] as int?;
    final totalSeconds = durationSeconds ??
        (durationMinutes != null ? durationMinutes * 60 : log.accumulatedSeconds);

    final description = (body['description'] as String?) ?? log.description;

    try {
      await state.editLog(
        logId: id,
        durationSeconds: totalSeconds,
        description: description,
      );

      final updated = state.logs.firstWhere((l) => l.id == id);
      final issue = state.issues.where((i) => i.issueId == updated.issueId).firstOrNull;

      _sendJson(response, HttpStatus.ok, {
        'id': updated.id,
        'issue_key': issue?.key ?? updated.issueId,
        'duration_seconds': updated.accumulatedSeconds,
        'duration_minutes': (updated.accumulatedSeconds / 60).round(),
        'description': updated.description,
      });
    } catch (e) {
      _sendJson(response, HttpStatus.badRequest, {'error': e.toString()});
    }
  }

  Future<void> _handleDeleteLog(HttpRequest request, HttpResponse response, String id) async {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.serviceUnavailable, {'error': 'AppState not available'});
      return;
    }

    final log = state.logs.where((l) => l.id == id).firstOrNull;
    if (log == null) {
      _sendJson(response, HttpStatus.notFound, {'error': 'Log with id "$id" not found'});
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
      _sendJson(response, HttpStatus.serviceUnavailable, {'error': 'AppState not available'});
      return;
    }

    final dateParam = request.uri.queryParameters['date'];
    DateTime targetDate;
    if (dateParam != null && dateParam.trim().isNotEmpty) {
      try {
        targetDate = DateTime.parse(dateParam.trim());
      } catch (e) {
        _sendJson(response, HttpStatus.badRequest, {
          'error': 'Invalid date format. Expected YYYY-MM-DD'
        });
        return;
      }
    } else {
      targetDate = state.selectedDate;
    }

    final dateStr =
        '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

    final draft = state.store.getDayDraft(scope: state.activeScope, date: dateStr);
    List<Segment> segments = [];
    List<Break> breaks = [];
    if (draft != null) {
      segments = state.store.getSegments(draftId: draft.id);
      breaks = state.store.getBreaks(draftId: draft.id);
    }

    final issuesMap = {for (final i in state.issues) i.issueId: i};

    final existingList = state.importedWorklogs.map((e) => {
      'id': e.id,
      'issue_id': e.issueId,
      'issue_key': e.issueKey ?? issuesMap[e.issueId]?.key ?? e.issueId,
      'start_utc': e.startUtc.toIso8601String(),
      'start_local': e.startUtc.toLocal().toIso8601String(),
      'duration_seconds': e.durationSeconds,
      'duration_minutes': (e.durationSeconds / 60).round(),
      'comment': e.comment,
    }).toList();

    Map<String, dynamic>? draftMap;
    if (draft != null) {
      draftMap = {
        'id': draft.id,
        'date': draft.date,
        'start_utc': draft.startUtc.toIso8601String(),
        'end_utc': draft.endUtc.toIso8601String(),
        'status': draft.status.name,
        'segments': segments.map((s) => {
          'id': s.id,
          'issue_key': issuesMap[s.issueId]?.key ?? s.issueId,
          'start_utc': s.startUtc.toIso8601String(),
          'start_local': '${s.startUtc.toLocal().hour.toString().padLeft(2, '0')}:${s.startUtc.toLocal().minute.toString().padLeft(2, '0')}',
          'duration_seconds': s.durationSeconds,
          'duration_minutes': (s.durationSeconds / 60).round(),
          'description': s.description,
          'send_state': s.sendState.name,
        }).toList(),
        'breaks': breaks.map((b) => {
          'id': b.id,
          'start_utc': b.startUtc.toIso8601String(),
          'start_local': '${b.startUtc.toLocal().hour.toString().padLeft(2, '0')}:${b.startUtc.toLocal().minute.toString().padLeft(2, '0')}',
          'duration_seconds': b.durationSeconds,
          'duration_minutes': (b.durationSeconds / 60).round(),
        }).toList(),
      };
    }

    _sendJson(response, HttpStatus.ok, {
      'date': dateStr,
      'existing_worklogs': existingList,
      'draft': draftMap,
    });
  }

  Future<void> _handlePostDay(HttpRequest request, HttpResponse response) async {
    final state = appState;
    if (state == null) {
      _sendJson(response, HttpStatus.serviceUnavailable, {'error': 'AppState not available'});
      return;
    }

    final body = await _parseJsonBody(request, response);
    if (body == null) return;

    final dateStr = body['date'] as String? ?? state.selectedDateString;
    DateTime targetDate;
    try {
      targetDate = DateTime.parse(dateStr);
    } catch (e) {
      _sendJson(response, HttpStatus.badRequest, {
        'error': 'Invalid date format "$dateStr". Expected YYYY-MM-DD'
      });
      return;
    }

    final rawSegments = body['segments'];
    if (rawSegments is! List || rawSegments.isEmpty) {
      _sendJson(response, HttpStatus.badRequest, {
        'error': 'Field "segments" must be a non-empty array'
      });
      return;
    }

    final inputSegments = <AgentSegmentInput>[];

    for (var i = 0; i < rawSegments.length; i++) {
      final item = rawSegments[i];
      if (item is! Map<String, dynamic>) {
        _sendJson(response, HttpStatus.badRequest, {
          'error': 'Each segment must be an object at index $i'
        });
        return;
      }

      final issueKey = item['issue_key'] as String?;
      if (issueKey == null || issueKey.trim().isEmpty) {
        _sendJson(response, HttpStatus.badRequest, {
          'error': 'Segment at index $i missing "issue_key"'
        });
        return;
      }

      final startRaw = item['start'] as String?;
      if (startRaw == null || startRaw.trim().isEmpty) {
        _sendJson(response, HttpStatus.badRequest, {
          'error': 'Segment at index $i missing "start"'
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
        if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
          _sendJson(response, HttpStatus.badRequest, {
            'error': 'Invalid time format "$startRaw" at index $i. Expected HH:MM'
          });
          return;
        }
        final localDt = DateTime(targetDate.year, targetDate.month, targetDate.day, hour, minute);
        startUtc = localDt.toUtc();
      } else {
        // Формат ISO 8601
        try {
          startUtc = DateTime.parse(trimmedStart).toUtc();
        } catch (e) {
          _sendJson(response, HttpStatus.badRequest, {
            'error': 'Invalid ISO timestamp "$startRaw" at index $i'
          });
          return;
        }
      }

      final durMinutes = item['duration_minutes'] as int?;
      final durSeconds = item['duration_seconds'] as int?;
      final totalSec = durSeconds ?? ((durMinutes ?? 0) * 60);

      if (totalSec <= 0) {
        _sendJson(response, HttpStatus.badRequest, {
          'error': 'Segment at index $i duration must be > 0 (specify "duration_minutes" or "duration_seconds")'
        });
        return;
      }

      final desc = (item['description'] as String?) ?? '';
      final sourceLogId = item['source_log_id'] as String?;

      inputSegments.add(
        AgentSegmentInput(
          issueKey: issueKey.trim(),
          startUtc: startUtc,
          durationSeconds: totalSec,
          description: desc,
          sourceLogId: sourceLogId,
        ),
      );
    }

    try {
      final draft = await state.applyAgentDayPlan(
        targetDate: targetDate,
        inputSegments: inputSegments,
      );

      final totalWorkSec = inputSegments.fold<int>(0, (sum, s) => sum + s.durationSeconds);

      _sendJson(response, HttpStatus.ok, {
        'status': 'ok',
        'draft_id': draft.id,
        'date': draft.date,
        'segments_count': inputSegments.length,
        'total_work_seconds': totalWorkSec,
        'total_work_minutes': (totalWorkSec / 60).round(),
      });
    } on DayBuilderException catch (e) {
      _sendJson(response, HttpStatus.badRequest, {'error': e.message});
    } catch (e) {
      _sendJson(response, HttpStatus.badRequest, {'error': e.toString()});
    }
  }

  String _buildHelpMarkdown() {
    return '''# Jira Time Tracker Local Agent API

Локальный REST API для интеграции AI-агентов (Claude, Antigravity, MCP-серверов и скриптов).

Базовый URL: `$url`

## Эндпоинты

### 1. Справка и метаданные
- `GET /api/help` — эта документация в формате Markdown.
- `GET /api/openapi.json` — машиночитаемая схема OpenAPI 3.0.0.

### 2. Управление очередью логов
- `GET /api/logs` — список свободных (неотправленных) логов времени.
- `POST /api/logs` — добавить новое списание времени:
  ```bash
  curl -X POST $url/api/logs \\
    -H "Content-Type: application/json" \\
    -d '{"issue_key": "PROJ-123", "duration_minutes": 45, "description": "Работа над багом"}'
  ```
- `PATCH /api/logs/{id}` — скорректировать длительность или описание свободного лога.
- `DELETE /api/logs/{id}` — удалить ошибочный лог.

### 3. Расписание дня
- `GET /api/day?date=YYYY-MM-DD` — получить существующие в Jira записи (`existing_worklogs`) и текущий черновик дня.
- `POST /api/day` — передать готовое расписание дня, собранное агентом:
  ```bash
  curl -X POST $url/api/day \\
    -H "Content-Type: application/json" \\
    -d '{
      "date": "2026-09-17",
      "segments": [
        {
          "issue_key": "PROJ-123",
          "start": "09:00",
          "duration_minutes": 60,
          "description": "Анализ кода"
        }
      ]
    }'
  ```

### 4. Служебные тикеты (Service Tickets)
- `GET /api/service-tickets` — получить список всех 18 служебных тикетов компании (EG-*) с описанием (созвоны, код-ревью, письма, саппорт и т.д.):
  ```bash
  curl $url/api/service-tickets
  ```

*Примечание: Финальная отправка дня в Jira выполняется пользователем в приложении нажатием кнопки «Отправить в Jira».*
''';
  }

  Map<String, dynamic> _buildOpenApiSpec() {
    return {
      'openapi': '3.0.0',
      'info': {
        'title': 'Jira Time Tracker Agent API',
        'version': '1.0.0',
        'description': 'Local REST API for AI agents to log time and submit day schedules.',
      },
      'servers': [
        {'url': url, 'description': 'Local Tracker Instance'}
      ],
      'paths': {
        '/api/help': {
          'get': {
            'summary': 'Get human-readable Markdown help',
            'responses': {
              '200': {'description': 'Markdown text'}
            }
          }
        },
        '/api/openapi.json': {
          'get': {
            'summary': 'Get OpenAPI 3.0 specification',
            'responses': {
              '200': {'description': 'OpenAPI JSON schema'}
            }
          }
        },
        '/api/logs': {
          'get': {
            'summary': 'List unsubmitted time logs',
            'responses': {
              '200': {'description': 'Array of time logs'}
            }
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
                      'description': {'type': 'string', 'example': 'Debugging issue'}
                    }
                  }
                }
              }
            },
            'responses': {
              '201': {'description': 'Log created'},
              '400': {'description': 'Invalid parameters'},
              '404': {'description': 'Issue not found in Jira'}
            }
          }
        },
        '/api/logs/{id}': {
          'patch': {
            'summary': 'Update an unsubmitted time log',
            'parameters': [
              {'name': 'id', 'in': 'path', 'required': true, 'schema': {'type': 'string'}}
            ],
            'responses': {
              '200': {'description': 'Log updated'},
              '404': {'description': 'Log not found or already consumed'}
            }
          },
          'delete': {
            'summary': 'Delete an unsubmitted time log',
            'parameters': [
              {'name': 'id', 'in': 'path', 'required': true, 'schema': {'type': 'string'}}
            ],
            'responses': {
              '200': {'description': 'Log deleted'},
              '404': {'description': 'Log not found'}
            }
          }
        },
        '/api/day': {
          'get': {
            'summary': 'Get day schedule and existing Jira worklogs',
            'parameters': [
              {
                'name': 'date',
                'in': 'query',
                'required': false,
                'description': 'Target date (YYYY-MM-DD), defaults to today',
                'schema': {'type': 'string', 'example': '2026-09-17'}
              }
            ],
            'responses': {
              '200': {'description': 'Day data with existing worklogs and draft'}
            }
          },
          'post': {
            'summary': 'Submit an agent-composed day schedule into the app draft',
            'requestBody': {
              'required': true,
              'content': {
                'application/json': {
                  'schema': {
                    'type': 'object',
                    'required': ['segments'],
                    'properties': {
                      'date': {'type': 'string', 'example': '2026-09-17'},
                      'segments': {
                        'type': 'array',
                        'items': {
                          'type': 'object',
                          'required': ['issue_key', 'start'],
                          'properties': {
                            'issue_key': {'type': 'string', 'example': 'PROJ-123'},
                            'start': {'type': 'string', 'example': '09:00'},
                            'duration_minutes': {'type': 'integer', 'example': 60},
                            'duration_seconds': {'type': 'integer', 'example': 3600},
                            'description': {'type': 'string', 'example': 'Code review'},
                            'source_log_id': {'type': 'string'}
                          }
                        }
                      }
                    }
                  }
                }
              }
            },
            'responses': {
              '200': {'description': 'Day draft created and loaded into app'},
              '400': {'description': 'Validation error (overlaps, out-of-bounds)'}
            }
          }
        },
        '/api/service-tickets': {
          'get': {
            'summary': 'List standard company service tickets (EG-*)',
            'responses': {
              '200': {
                'description': 'Array of service tickets',
                'content': {
                  'application/json': {
                    'schema': {
                      'type': 'array',
                      'items': {
                        'type': 'object',
                        'properties': {
                          'key': {'type': 'string', 'example': 'EG-294'},
                          'category': {'type': 'string', 'example': 'Non-utilized Meeting/Events'},
                          'description': {'type': 'string', 'example': 'Созвоны, синги, таунхоллы'}
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    };
  }
}
