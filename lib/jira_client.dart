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

  void close() {
    _client.close();
  }
}
