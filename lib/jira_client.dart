import 'app_message.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

/// Ошибка при взаимодействии с Jira API.
class JiraApiException implements Exception, MessageException {
  @override
  final Object messageText;
  String get message => messageText.toString();
  final int? statusCode;

  const JiraApiException(this.messageText, {this.statusCode});

  @override
  String toString() => message;
}

/// Классификация результата выполнения POST запроса worklog в Jira.
enum JiraPostResultKind { success, failed, unknown }

/// Результат отправки интервала в Jira.
class JiraPostWorklogResult {
  final JiraPostResultKind kind;
  final String? worklogId;
  final int? statusCode;
  final Object? errorText;
  String? get errorMessage => errorText?.toString();

  const JiraPostWorklogResult({
    required this.kind,
    this.worklogId,
    this.statusCode,
    Object? errorMessage,
  }) : errorText = errorMessage;

  factory JiraPostWorklogResult.success(String worklogId) =>
      JiraPostWorklogResult(
        kind: JiraPostResultKind.success,
        worklogId: worklogId,
      );

  factory JiraPostWorklogResult.failed({
    int? statusCode,
    Object? errorMessage,
  }) => JiraPostWorklogResult(
    kind: JiraPostResultKind.failed,
    statusCode: statusCode,
    errorMessage: errorMessage,
  );

  factory JiraPostWorklogResult.unknown({
    int? statusCode,
    Object? errorMessage,
  }) => JiraPostWorklogResult(
    kind: JiraPostResultKind.unknown,
    statusCode: statusCode,
    errorMessage: errorMessage,
  );
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
        AppMessage(
          'couldNotGetTheJiraSiteSCloudid',
          [response.statusCode],
          'Не удалось получить cloudId Jira-сайта (код: ${response.statusCode})',
        ),
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is JiraApiException) rethrow;
      throw JiraApiException(
        AppMessage(
          'networkErrorRequestingCloudid',
          [e],
          'Сетевая ошибка при запросе cloudId: $e',
        ),
      );
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
        AppMessage(
          'invalidEmailOrApiTokenUnauthorized',
          [],
          'Неверный email или API токен (401 Unauthorized)',
        ),
        statusCode: 401,
      );
    } else if (response.statusCode == 403) {
      throw JiraApiException(
        AppMessage(
          'accessDeniedForbidden',
          [],
          'Доступ запрещён (403 Forbidden)',
        ),
        statusCode: 403,
      );
    } else if (response.statusCode == 429) {
      final retryAfter = response.headers['retry-after'];
      throw JiraApiException(
        AppMessage(
          'rateLimitExceededTooManyRequests',
          [
            retryAfter != null
                ? AppMessage('retryAfterSeconds', [
                    retryAfter,
                  ], ". Повторите через $retryAfter сек.")
                : "",
          ],
          'Превышен лимит запросов (429 Too Many Requests)${retryAfter != null ? AppMessage('retryAfterSeconds', [retryAfter], ". Повторите через $retryAfter сек.") : ""}',
        ),
        statusCode: 429,
      );
    } else {
      throw JiraApiException(
        AppMessage(
          'jiraApiError',
          [response.statusCode, response.reasonPhrase ?? ''],
          'Ошибка Jira API: ${response.statusCode} ${response.reasonPhrase ?? ''}',
        ),
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
      throw JiraApiException(
        AppMessage('jiraUrlIsMissing', [], 'Не указан URL Jira'),
      );
    }
    if (cleanEmail.isEmpty) {
      throw JiraApiException(
        AppMessage(
          'atlassianAccountEmailIsMissing',
          [],
          'Не указан Email аккаунта Atlassian',
        ),
      );
    }
    if (cleanToken.isEmpty) {
      throw JiraApiException(
        AppMessage(
          'atlassianApiTokenIsMissing',
          [],
          'Не указан API токен Atlassian',
        ),
      );
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
        AppMessage(
          'couldNotConnectViaEitherTheDirectOr',
          [scopedError.messageText],
          'Не удалось подключиться ни прямым, ни scoped-маршрутом: ${scopedError.message}',
        ),
        statusCode: scopedError.statusCode,
      );
    } catch (e) {
      throw JiraApiException(
        AppMessage(
          'errorCheckingTheScopedRoute',
          [e],
          'Ошибка при проверке scoped-маршрута: $e',
        ),
      );
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
      '${connection.apiBaseUrl}/rest/api/3/issue/$cleanIdOrKey?fields=summary,status',
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

      String? statusName;
      final statusField = fields['status'];
      if (statusField is Map<String, dynamic>) {
        statusName = statusField['name'] as String?;
      } else if (statusField is String) {
        statusName = statusField;
      }

      return Issue(
        scope: connection.scope,
        issueId: issueId,
        key: canonicalKey,
        summary: summary,
        status: statusName,
        lastUsedAtUtc: DateTime.now().toUtc(),
      );
    } else if (response.statusCode == 404) {
      throw JiraApiException(
        AppMessage(
          'issueWasNotFoundInJiraNotFound',
          [cleanIdOrKey],
          'Задача "$cleanIdOrKey" не найдена в Jira (404 Not Found)',
        ),
        statusCode: 404,
      );
    } else if (response.statusCode == 401) {
      throw JiraApiException(
        AppMessage(
          'jiraAuthenticationErrorUnauthorized',
          [],
          'Ошибка авторизации Jira (401 Unauthorized)',
        ),
        statusCode: 401,
      );
    } else if (response.statusCode == 403) {
      throw JiraApiException(
        AppMessage(
          'accessToTheJiraIssueIsDeniedForbidden',
          [],
          'Нет доступа к задаче в Jira (403 Forbidden)',
        ),
        statusCode: 403,
      );
    } else {
      throw JiraApiException(
        AppMessage(
          'errorLoadingIssue',
          [cleanIdOrKey, response.statusCode, response.reasonPhrase ?? ''],
          'Ошибка загрузки задачи "$cleanIdOrKey": ${response.statusCode} ${response.reasonPhrase ?? ''}',
        ),
        statusCode: response.statusCode,
      );
    }
  }

  /// Fresh issue text, all visible comments, and attachment metadata.
  Future<Map<String, dynamic>> getIssueDetails({
    required String issueIdOrKey,
    required JiraConnection connection,
    required String token,
  }) async {
    final issue = await _getIssueData(
      issueIdOrKey,
      'summary,description,status,issuetype,priority,assignee,labels,created,updated,attachment',
      connection,
      token,
    );
    final fields = issue['fields'] as Map<String, dynamic>? ?? {};
    final comments = <Map<String, dynamic>>[];
    var startAt = 0;
    var total = 1;
    while (startAt < total) {
      final uri = Uri.parse(
        '${connection.apiBaseUrl}/rest/api/3/issue/$issueIdOrKey/comment',
      ).replace(queryParameters: {'startAt': '$startAt', 'maxResults': '100'});
      final page = await _getAuthorizedJson(uri, connection, token);
      final rawComments = page['comments'] as List? ?? [];
      total = page['total'] as int? ?? 0;
      if (rawComments.isEmpty && startAt < total) {
        throw JiraApiException(
          AppMessage(
            'jiraReturnedAnIncompleteCommentList',
            [],
            'Jira вернула неполный список комментариев',
          ),
        );
      }
      for (final raw in rawComments) {
        final comment = raw as Map<String, dynamic>;
        final author = comment['author'] as Map<String, dynamic>? ?? {};
        comments.add({
          'id': comment['id']?.toString(),
          'author_account_id': author['accountId'],
          'author_name': author['displayName'],
          'created': comment['created'],
          'updated': comment['updated'],
          'body': _extractTextFromComment(comment['body']),
        });
      }
      startAt += rawComments.length;
    }
    final issueKey = issue['key']?.toString() ?? issueIdOrKey;
    return {
      'issue_id': issue['id']?.toString() ?? issueIdOrKey,
      'issue_key': issueKey,
      'summary': fields['summary'],
      'description': _extractTextFromComment(fields['description']),
      'status': (fields['status'] as Map?)?['name'],
      'issue_type': (fields['issuetype'] as Map?)?['name'],
      'priority': (fields['priority'] as Map?)?['name'],
      'assignee': (fields['assignee'] as Map?)?['displayName'],
      'labels': fields['labels'] as List? ?? [],
      'created': fields['created'],
      'updated': fields['updated'],
      'comments': comments,
      'attachments': [
        for (final raw in fields['attachment'] as List? ?? [])
          if (raw is Map<String, dynamic>)
            {
              'id': raw['id']?.toString(),
              'filename': raw['filename'],
              'mime_type': raw['mimeType'],
              'size_bytes': raw['size'],
              'created': raw['created'],
              'author_account_id': (raw['author'] as Map?)?['accountId'],
              'author_name': (raw['author'] as Map?)?['displayName'],
              'download_path': '/api/issues/$issueKey/attachments/${raw['id']}',
            },
      ],
    };
  }

  /// Returns a stream only for an attachment listed on the requested issue.
  Future<(Map<String, dynamic>, http.StreamedResponse)>
  downloadIssueAttachment({
    required String issueIdOrKey,
    required String attachmentId,
    required JiraConnection connection,
    required String token,
  }) async {
    final issue = await _getIssueData(
      issueIdOrKey,
      'attachment',
      connection,
      token,
    );
    final fields = issue['fields'] as Map<String, dynamic>? ?? {};
    final attachments = fields['attachment'] as List? ?? [];
    final attachment = attachments
        .whereType<Map<String, dynamic>>()
        .where((item) => item['id']?.toString() == attachmentId)
        .firstOrNull;
    if (attachment == null) {
      throw JiraApiException(
        AppMessage(
          'attachmentWasNotFoundInTheSpecifiedJira',
          [],
          'Вложение не найдено в указанной задаче Jira',
        ),
        statusCode: 404,
      );
    }
    final uri = Uri.parse(
      '${connection.apiBaseUrl}/rest/api/3/attachment/content/$attachmentId',
    ).replace(queryParameters: {'redirect': 'false'});
    final request = http.Request('GET', uri)
      ..headers['Authorization'] = buildBasicAuthHeader(connection.email, token)
      ..followRedirects = false;
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw JiraApiException(
        AppMessage(
          'errorLoadingJiraAttachmentCode',
          [response.statusCode],
          'Ошибка загрузки вложения Jira (код: ${response.statusCode})',
        ),
        statusCode: response.statusCode,
      );
    }
    return (attachment, response);
  }

  Future<Map<String, dynamic>> _getIssueData(
    String issueIdOrKey,
    String fields,
    JiraConnection connection,
    String token,
  ) {
    final uri = Uri.parse(
      '${connection.apiBaseUrl}/rest/api/3/issue/$issueIdOrKey',
    ).replace(queryParameters: {'fields': fields});
    return _getAuthorizedJson(uri, connection, token);
  }

  Future<Map<String, dynamic>> _getAuthorizedJson(
    Uri uri,
    JiraConnection connection,
    String token,
  ) async {
    final request = http.Request('GET', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = buildBasicAuthHeader(connection.email, token)
      ..followRedirects = false;
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw JiraApiException(
        AppMessage(
          'errorLoadingJiraDataCode',
          [response.statusCode],
          'Ошибка загрузки данных Jira (код: ${response.statusCode})',
        ),
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
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
    final jql =
        'worklogAuthor = "${connection.accountId}" AND '
        "worklogDate >= '$fromDateStr' AND worklogDate <= '$toDateStr'";

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
          AppMessage(
            'errorSearchingJiraForIssuesWithWorklogsCode',
            [response.statusCode],
            'Ошибка поиска задач с worklogs в Jira (код: ${response.statusCode})',
          ),
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
    const maxResults = 500;
    var total = 0;
    var isFirst = true;

    while (isFirst || startAt < total) {
      isFirst = false;
      final uri = Uri.parse(
        '${connection.apiBaseUrl}/rest/api/3/issue/$issueIdOrKey/worklog?startAt=$startAt&maxResults=$maxResults&expand=properties',
      );
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json', 'Authorization': authHeader},
      );

      if (response.statusCode != 200) {
        throw JiraApiException(
          AppMessage(
            'errorLoadingWorklogsForIssueCode',
            [issueIdOrKey, response.statusCode],
            'Ошибка загрузки worklogs для задачи "$issueIdOrKey" (код: ${response.statusCode})',
          ),
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

        String? segmentProp;
        final props = m['properties'] as List?;
        if (props != null) {
          for (final p in props) {
            if (p is Map && p['key'] == 'jira-time-tracker.segment') {
              final val = p['value'];
              if (val is Map) {
                segmentProp = val['id']?.toString();
              }
            }
          }
        }

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
              segmentPropertyId: segmentProp,
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

    // 3. Читаем задачи параллельно, оставляя небольшой предел для Jira.
    final entries = issueMap.entries.toList();
    var next = 0;
    Future<List<ImportedWorklog>> loadIssues() async {
      final worklogs = <ImportedWorklog>[];
      while (next < entries.length) {
        final entry = entries[next++];
        worklogs.addAll(
          await getIssueWorklogs(
            issueIdOrKey: entry.key,
            issueKey: entry.value,
            connection: connection,
            token: token,
          ),
        );
      }
      return worklogs;
    }

    final workers = entries.length < 4 ? entries.length : 4;
    final batches = await Future.wait(
      List.generate(workers, (_) => loadIssues()),
    );
    final allRawWorklogs = batches.expand((logs) => logs);

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

  /// Отправка интервала времени (worklog) в Jira с параметром adjustEstimate=leave (сценарий A14).
  ///
  /// Чётко классифицирует результат:
  /// - 201 Created -> success(worklogId)
  /// - 4xx Client error -> failed(statusCode, error)
  /// - 5xx Server error, обрыв связи, таймаут -> unknown(statusCode, error)
  Future<JiraPostWorklogResult> postWorklog({
    required String issueIdOrKey,
    required Map<String, dynamic> payload,
    required JiraConnection connection,
    required String token,
  }) async {
    final base = connection.apiBaseUrl;
    final uri = Uri.parse(
      '$base/rest/api/3/issue/$issueIdOrKey/worklog?adjustEstimate=leave',
    );
    final authHeader = buildBasicAuthHeader(connection.email, token);

    try {
      final response = await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': authHeader,
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final id = (data['id'] as String?) ?? data['id']?.toString();
          if (id != null && id.isNotEmpty) {
            return JiraPostWorklogResult.success(id);
          }
          return JiraPostWorklogResult.unknown(
            statusCode: response.statusCode,
            errorMessage: AppMessage(
              'jiraSResponseDoesNotContainTheCreated',
              [],
              'Ответ Jira 201 не содержит ID созданного worklog',
            ),
          );
        } catch (e) {
          return JiraPostWorklogResult.unknown(
            statusCode: response.statusCode,
            errorMessage: AppMessage(
              'invalidJsonInJiraSResponse',
              [e],
              'Некорректный JSON в ответе Jira 201: $e',
            ),
          );
        }
      }

      if (response.statusCode >= 400 && response.statusCode < 500) {
        Object msg = AppMessage('jiraRejectedTheRequestCode', [
          response.statusCode,
        ], 'Отказ Jira (код ${response.statusCode})');
        try {
          final errData = jsonDecode(response.body);
          if (errData is Map && errData['errorMessages'] is List) {
            final list = errData['errorMessages'] as List;
            if (list.isNotEmpty) {
              msg = list.join(', ');
            }
          } else if (errData is Map && errData['errors'] is Map) {
            final errors = (errData['errors'] as Map).values.join(', ');
            if (errors.isNotEmpty) {
              msg = errors;
            }
          }
        } catch (_) {}
        return JiraPostWorklogResult.failed(
          statusCode: response.statusCode,
          errorMessage: msg,
        );
      }

      return JiraPostWorklogResult.unknown(
        statusCode: response.statusCode,
        errorMessage: AppMessage(
          'jiraServerErrorCode',
          [response.statusCode],
          'Серверная ошибка Jira (код ${response.statusCode})',
        ),
      );
    } catch (e) {
      return JiraPostWorklogResult.unknown(
        statusCode: null,
        errorMessage: AppMessage('connectionLostOrTimedOut', [
          e,
        ], 'Обрыв связи или таймаут: $e'),
      );
    }
  }

  /// Загрузка конкретной записи worklog по ID (для ручного разрешения unknown, сценарий A15).
  Future<ImportedWorklog?> getWorklogById({
    required String issueIdOrKey,
    required String worklogId,
    required JiraConnection connection,
    required String token,
  }) async {
    final base = connection.apiBaseUrl;
    final uri = Uri.parse(
      '$base/rest/api/3/issue/$issueIdOrKey/worklog/$worklogId?expand=properties',
    );
    final authHeader = buildBasicAuthHeader(connection.email, token);

    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json', 'Authorization': authHeader},
      );

      if (response.statusCode == 200) {
        final m = jsonDecode(response.body) as Map<String, dynamic>;
        final id = (m['id'] as String?) ?? m['id'].toString();
        final author = (m['author'] as Map<String, dynamic>?) ?? {};
        final authorAccountId = (author['accountId'] as String?) ?? '';
        final startedStr = (m['started'] as String?) ?? '';
        final timeSpentSec = (m['timeSpentSeconds'] as int?) ?? 0;
        final commentText = _extractTextFromComment(m['comment']);

        String? segmentProp;
        final props = m['properties'] as List?;
        if (props != null) {
          for (final p in props) {
            if (p is Map && p['key'] == 'jira-time-tracker.segment') {
              final val = p['value'];
              if (val is Map) {
                segmentProp = val['id']?.toString();
              }
            }
          }
        }

        DateTime? startUtc;
        try {
          startUtc = DateTime.parse(startedStr).toUtc();
        } catch (_) {}

        if (startUtc != null) {
          return ImportedWorklog(
            id: id,
            issueId: issueIdOrKey,
            startUtc: startUtc,
            durationSeconds: timeSpentSec,
            authorAccountId: authorAccountId,
            comment: commentText,
            segmentPropertyId: segmentProp,
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Получение свойства worklog (для сверки unknown через /properties, сценарий A15).
  Future<Map<String, dynamic>?> getWorklogProperty({
    required String issueIdOrKey,
    required String worklogId,
    required String propertyKey,
    required JiraConnection connection,
    required String token,
  }) async {
    final base = connection.apiBaseUrl;
    final uri = Uri.parse(
      '$base/rest/api/3/issue/$issueIdOrKey/worklog/$worklogId/properties/$propertyKey',
    );
    final authHeader = buildBasicAuthHeader(connection.email, token);

    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json', 'Authorization': authHeader},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
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
          if (node['type'] == 'hardBreak') buffer.writeln();
          if (node['content'] is List) {
            for (final child in node['content'] as List) {
              extract(child);
            }
            if (node['type'] == 'paragraph' ||
                node['type'] == 'heading' ||
                node['type'] == 'listItem') {
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
