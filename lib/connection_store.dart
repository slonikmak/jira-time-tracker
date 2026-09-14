import 'dart:io';
import 'models.dart';
import 'secure_storage.dart';

/// Управление учётными данными Jira и конфигурацией подключения.
class ConnectionStore {
  final SecureStorage _secureStorage;
  final Map<String, String> _environment;

  static const String _keyToken = 'jira_token';
  static const String _keyConnection = 'jira_connection_meta';
  static const String defaultBaseUrl = 'https://esprowteam.atlassian.net';

  ConnectionStore({
    required SecureStorage secureStorage,
    Map<String, String>? environment,
  }) : _secureStorage = secureStorage,
       _environment = environment ?? Platform.environment;

  /// Загружает данные для формы настроек (сценарий A16).
  /// Если сохранённых данных нет — подставляет значения из переменных окружения.
  /// Если пользователь ранее сохранил подключение — сохранённые значения побеждают.
  Future<JiraConnectionForm> loadForm() async {
    final savedConnection = await getSavedConnection();
    final savedToken = await getSavedToken();

    if (savedConnection != null &&
        savedToken != null &&
        savedToken.isNotEmpty) {
      return JiraConnectionForm(
        baseUrl: savedConnection.baseUrl,
        email: savedConnection.email,
        token: savedToken,
      );
    }

    final envUrl = _environment['JIRA_BASE_URL'];
    final envEmail = _environment['JIRA_EMAIL'];
    final envToken = _environment['JIRA_TOKEN'];

    return JiraConnectionForm(
      baseUrl: (envUrl != null && envUrl.isNotEmpty) ? envUrl : defaultBaseUrl,
      email: envEmail ?? '',
      token: envToken ?? '',
    );
  }

  /// Возвращает подтверждённое сохранённое подключение.
  Future<JiraConnection?> getSavedConnection() async {
    final raw = await _secureStorage.read(_keyConnection);
    if (raw == null || raw.isEmpty) return null;
    try {
      return JiraConnection.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  /// Возвращает сохранённый API токен из защищённого хранилища.
  Future<String?> getSavedToken() async {
    return _secureStorage.read(_keyToken);
  }

  /// Сохраняет проверенное подключение и токен в защищённое хранилище.
  Future<void> saveConnection(JiraConnection connection, String token) async {
    await _secureStorage.write(_keyConnection, connection.toJson());
    await _secureStorage.write(_keyToken, token);
  }

  /// Очищает сохранённое подключение.
  Future<void> clearConnection() async {
    await _secureStorage.delete(_keyConnection);
    await _secureStorage.delete(_keyToken);
  }
}
