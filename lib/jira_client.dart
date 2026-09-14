import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

/// Ошибка при взаимодействии с Jira API.
class JiraApiException implements Exception {
  final String message;
  final int? statusCode;

  const JiraApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Клиент для работы с Jira Cloud REST API.
class JiraClient {
  final http.Client _client;

  JiraClient({http.Client? client}) : _client = client ?? http.Client();

  static String buildBasicAuthHeader(String email, String token) {
    final credentials = '$email:$token';
    return 'Basic ${base64Encode(utf8.encode(credentials))}';
  }

  static String normalizeBaseUrl(String url) {
    var trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    return trimmed;
  }

  /// Получает cloudId по публичному эндпоинту /_edge/tenant_info (без credentials).
  Future<String> fetchCloudId(String baseUrl) async {
    final normalized = normalizeBaseUrl(baseUrl);
    final uri = Uri.parse('$normalized/_edge/tenant_info');
    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final cloudId = data['cloudId'] as String?;
        if (cloudId != null && cloudId.isNotEmpty) {
          return cloudId;
        }
      }
      throw JiraApiException(
        'Не удалось получить cloudId Jira-сайта (код: ${response.statusCode})',
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is JiraApiException) rethrow;
      throw JiraApiException('Сетевая ошибка при запросе cloudId: $e');
    }
  }

  /// Выполняет запрос к /rest/api/3/myself по указанному Uri.
  Future<JiraAccountInfo> _fetchMyself(
    Uri uri,
    String email,
    String token,
  ) async {
    final authHeader = buildBasicAuthHeader(email, token);
    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json', 'Authorization': authHeader},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return JiraAccountInfo(
        accountId: data['accountId'] as String? ?? '',
        displayName: data['displayName'] as String? ?? '',
        email: data['emailAddress'] as String? ?? email,
      );
    } else if (response.statusCode == 401) {
      throw JiraApiException(
        'Неверный email или API токен (401 Unauthorized)',
        statusCode: 401,
      );
    } else if (response.statusCode == 403) {
      throw JiraApiException(
        'Доступ запрещён (403 Forbidden)',
        statusCode: 403,
      );
    } else if (response.statusCode == 429) {
      final retryAfter = response.headers['retry-after'];
      throw JiraApiException(
        'Превышен лимит запросов (429 Too Many Requests)${retryAfter != null ? ". Повторите через $retryAfter сек." : ""}',
        statusCode: 429,
      );
    } else {
      throw JiraApiException(
        'Ошибка Jira API: ${response.statusCode} ${response.reasonPhrase ?? ''}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Read-only проверка подключения (сценарий A16, A17).
  /// Сначала пробует прямой маршрут GET /rest/api/3/myself на сайте.
  /// При 401 пробует scoped маршрут через cloudId на api.atlassian.com.
  Future<JiraConnection> testConnection({
    required String baseUrl,
    required String email,
    required String token,
  }) async {
    final cleanBaseUrl = normalizeBaseUrl(baseUrl);
    final cleanEmail = email.trim();
    final cleanToken = token.trim();

    if (cleanBaseUrl.isEmpty) {
      throw const JiraApiException('Не указан URL Jira');
    }
    if (cleanEmail.isEmpty) {
      throw const JiraApiException('Не указан Email аккаунта Atlassian');
    }
    if (cleanToken.isEmpty) {
      throw const JiraApiException('Не указан API токен Atlassian');
    }

    // 1. Попытка прямого маршрута
    final directUri = Uri.parse('$cleanBaseUrl/rest/api/3/myself');
    try {
      final account = await _fetchMyself(directUri, cleanEmail, cleanToken);
      final scope = '$cleanBaseUrl#${account.accountId}';
      return JiraConnection(
        baseUrl: cleanBaseUrl,
        email: cleanEmail,
        accountId: account.accountId,
        displayName: account.displayName,
        route: JiraAuthRoute.direct,
        scope: scope,
      );
    } on JiraApiException catch (directError) {
      // Если это не 401 (например 403, 429 или сетевой сбой), пробуем scoped только при 401
      if (directError.statusCode != 401) {
        rethrow;
      }
    } catch (_) {
      // При сетевой ошибке прямого маршрута нет смысла идти дальше
      rethrow;
    }

    // 2. Попытка scoped маршрута
    try {
      final cloudId = await fetchCloudId(cleanBaseUrl);
      final scopedUri = Uri.parse(
        'https://api.atlassian.com/ex/jira/$cloudId/rest/api/3/myself',
      );
      final account = await _fetchMyself(scopedUri, cleanEmail, cleanToken);
      final scope = '$cleanBaseUrl#${account.accountId}';
      return JiraConnection(
        baseUrl: cleanBaseUrl,
        email: cleanEmail,
        accountId: account.accountId,
        displayName: account.displayName,
        route: JiraAuthRoute.scoped,
        cloudId: cloudId,
        scope: scope,
      );
    } on JiraApiException catch (scopedError) {
      throw JiraApiException(
        'Не удалось подключиться ни прямым, ни scoped-маршрутом: ${scopedError.message}',
        statusCode: scopedError.statusCode,
      );
    } catch (e) {
      throw JiraApiException('Ошибка при проверке scoped-маршрута: $e');
    }
  }

  /// Получает данные задачи (id, canonical key, summary) по ID или ключу.
  Future<Issue> getIssue(
    String idOrKey, {
    required JiraConnection connection,
    required String token,
  }) async {
    final cleanIdOrKey = idOrKey.trim();
    final uri = Uri.parse(
      '${connection.apiBaseUrl}/rest/api/3/issue/$cleanIdOrKey?fields=summary',
    );
    final authHeader = buildBasicAuthHeader(connection.email, token);

    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json', 'Authorization': authHeader},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final fields = data['fields'] as Map<String, dynamic>? ?? {};
      final summary = (fields['summary'] as String?) ?? '';
      final canonicalKey = (data['key'] as String?) ?? cleanIdOrKey;
      final issueId = (data['id'] as String?) ?? cleanIdOrKey;

      return Issue(
        scope: connection.scope,
        issueId: issueId,
        key: canonicalKey,
        summary: summary,
        lastUsedAtUtc: DateTime.now().toUtc(),
      );
    } else if (response.statusCode == 404) {
      throw JiraApiException(
        'Задача "$cleanIdOrKey" не найдена в Jira (404 Not Found)',
        statusCode: 404,
      );
    } else if (response.statusCode == 401) {
      throw const JiraApiException(
        'Ошибка авторизации Jira (401 Unauthorized)',
        statusCode: 401,
      );
    } else if (response.statusCode == 403) {
      throw const JiraApiException(
        'Нет доступа к задаче в Jira (403 Forbidden)',
        statusCode: 403,
      );
    } else {
      throw JiraApiException(
        'Ошибка загрузки задачи "$cleanIdOrKey": ${response.statusCode} ${response.reasonPhrase ?? ''}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Поиск задач с worklogs за диапазон дат через POST /rest/api/3/search/jql с пагинацией (A12).
  Future<List<Map<String, String>>> searchIssuesWithWorklogs({
    required DateTime date,
    required JiraConnection connection,
    required String token,
  }) async {
    final fromDate = date.subtract(const Duration(days: 1));
    final toDate = date.add(const Duration(days: 1));
    final fromDateStr =
        '${fromDate.year.toString().padLeft(4, '0')}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
    final toDateStr =
        '${toDate.year.toString().padLeft(4, '0')}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';
    final jql = "worklogDate >= '$fromDateStr' AND worklogDate <= '$toDateStr'";

    final uri = Uri.parse('${connection.apiBaseUrl}/rest/api/3/search/jql');
    final authHeader = buildBasicAuthHeader(connection.email, token);

    final issues = <Map<String, String>>[];
    String? nextPageToken;
    var isLast = false;

    while (!isLast) {
      final body = <String, dynamic>{
        'jql': jql,
        'fields': ['summary'],
      };
      if (nextPageToken != null) {
        body['nextPageToken'] = nextPageToken;
      }

      final response = await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': authHeader,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw JiraApiException(
          'Ошибка поиска задач с worklogs в Jira (код: ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawIssues = (data['issues'] as List?) ?? [];

      for (final item in rawIssues) {
        final m = item as Map<String, dynamic>;
        final id = (m['id'] as String?) ?? m['id'].toString();
        final key = (m['key'] as String?) ?? id;
        final fields = (m['fields'] as Map<String, dynamic>?) ?? {};
        final summary = (fields['summary'] as String?) ?? '';
        issues.add({'id': id, 'key': key, 'summary': summary});
      }

      nextPageToken = data['nextPageToken'] as String?;
      isLast =
          (data['isLast'] as bool?) ??
          (nextPageToken == null || nextPageToken.isEmpty);
      if (nextPageToken == null || nextPageToken.isEmpty) {
        isLast = true;
      }
    }

    return issues;
  }

  /// Загрузка всех страниц worklogs задачи через GET /rest/api/3/issue/{id}/worklog (A12).
  Future<List<ImportedWorklog>> getIssueWorklogs({
    required String issueIdOrKey,
    String? issueKey,
    required JiraConnection connection,
    required String token,
  }) async {
    final authHeader = buildBasicAuthHeader(connection.email, token);
    final worklogs = <ImportedWorklog>[];
    var startAt = 0;
    const maxResults = 50;
    var total = 0;
    var isFirst = true;

    while (isFirst || startAt < total) {
      isFirst = false;
      final uri = Uri.parse(
        '${connection.apiBaseUrl}/rest/api/3/issue/$issueIdOrKey/worklog?startAt=$startAt&maxResults=$maxResults',
      );
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json', 'Authorization': authHeader},
      );

      if (response.statusCode != 200) {
        throw JiraApiException(
          'Ошибка загрузки worklogs для задачи "$issueIdOrKey" (код: ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      total = (data['total'] as int?) ?? 0;
      final rawList = (data['worklogs'] as List?) ?? [];

      for (final raw in rawList) {
        final m = raw as Map<String, dynamic>;
        final id = (m['id'] as String?) ?? m['id'].toString();
        final author = (m['author'] as Map<String, dynamic>?) ?? {};
        final authorAccountId = (author['accountId'] as String?) ?? '';
        final startedStr = (m['started'] as String?) ?? '';
        final timeSpentSec = (m['timeSpentSeconds'] as int?) ?? 0;
        final commentText = _extractTextFromComment(m['comment']);

        DateTime? startUtc;
        try {
          startUtc = DateTime.parse(startedStr).toUtc();
        } catch (_) {}

        if (startUtc != null && timeSpentSec > 0) {
          worklogs.add(
            ImportedWorklog(
              id: id,
              issueId: issueIdOrKey,
              issueKey: issueKey,
              startUtc: startUtc,
              durationSeconds: timeSpentSec,
              authorAccountId: authorAccountId,
              comment: commentText,
            ),
          );
        }
      }

      startAt += rawList.length;
      if (rawList.isEmpty) break;
    }

    return worklogs;
  }

  /// Полная загрузка существующих записей дня из Jira с фильтрацией по accountId и дате (сценарий A12).
  Future<List<ImportedWorklog>> fetchDayWorklogs({
    required DateTime date,
    required Duration timeZoneOffset,
    required JiraConnection connection,
    required String token,
    List<String> additionalIssueIds = const [],
  }) async {
    // 1. Поиск задач с записями с буфером +-1 день
    final foundIssues = await searchIssuesWithWorklogs(
      date: date,
      connection: connection,
      token: token,
    );

    // 2. Объединяем найденные задачи и локально известные задачи
    final issueMap = <String, String>{}; // id -> key
    for (final fi in foundIssues) {
      final id = fi['id']!;
      final key = fi['key']!;
      issueMap[id] = key;
    }
    for (final addId in additionalIssueIds) {
      if (!issueMap.containsKey(addId)) {
        issueMap[addId] = addId;
      }
    }

    // 3. Загружаем все страницы worklogs для всех задач
    final allRawWorklogs = <ImportedWorklog>[];
    for (final entry in issueMap.entries) {
      final logs = await getIssueWorklogs(
        issueIdOrKey: entry.key,
        issueKey: entry.value,
        connection: connection,
        token: token,
      );
      allRawWorklogs.addAll(logs);
    }

    // 4. Фильтруем строго по accountId пользователя и пересечению с локальным днем
    final localDayStartUtc = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).subtract(timeZoneOffset);
    final localDayEndUtc = localDayStartUtc.add(const Duration(days: 1));

    final filtered =
        <String, ImportedWorklog>{}; // id -> worklog (deduplication)

    for (final w in allRawWorklogs) {
      if (w.authorAccountId != connection.accountId) {
        continue;
      }

      // Проверяем пересечение с локальными календарными сутками
      final intersects =
          w.startUtc.isBefore(localDayEndUtc) &&
          w.endUtc.isAfter(localDayStartUtc);

      if (intersects) {
        filtered[w.id] = w;
      }
    }

    final result = filtered.values.toList()
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return result;
  }

  static String? _extractTextFromComment(dynamic comment) {
    if (comment == null) return null;
    if (comment is String) return comment;
    if (comment is Map<String, dynamic>) {
      final buffer = StringBuffer();
      void extract(dynamic node) {
        if (node is Map<String, dynamic>) {
          if (node['type'] == 'text' && node['text'] != null) {
            buffer.write(node['text']);
          }
          if (node['content'] is List) {
            for (final child in node['content'] as List) {
              extract(child);
            }
            if (node['type'] == 'paragraph') {
              buffer.writeln();
            }
          }
        } else if (node is List) {
          for (final item in node) {
            extract(item);
          }
        }
      }

      extract(comment);
      final res = buffer.toString().trim();
      return res.isEmpty ? null : res;
    }
    return null;
  }

  void close() {
    _client.close();
  }
}
