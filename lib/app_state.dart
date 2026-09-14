import 'package:flutter/foundation.dart';
import 'connection_store.dart';
import 'jira_client.dart';
import 'local_store.dart';
import 'models.dart';

/// Состояние приложения, координация данных и подключений.
class AppState extends ChangeNotifier {
  final LocalStore store;
  final ConnectionStore connectionStore;
  final JiraClient jiraClient;
  final bool isReadOnly;

  int _selectedTabIndex = 0;
  String? _statusMessage;
  JiraConnection? _currentConnection;

  AppState({
    required this.store,
    required this.connectionStore,
    required this.jiraClient,
    required this.isReadOnly,
    JiraConnection? initialConnection,
  }) : _currentConnection = initialConnection;

  int get selectedTabIndex => _selectedTabIndex;
  String? get statusMessage => _statusMessage;
  JiraConnection? get currentConnection => _currentConnection;

  /// Активный scope (normalized baseUrl#accountId) для изоляции данных в SQLite (A17).
  String get activeScope => _currentConnection?.scope ?? 'default';

  Future<void> loadSavedConnection() async {
    final conn = await connectionStore.getSavedConnection();
    if (conn != null) {
      _currentConnection = conn;
      notifyListeners();
    }
  }

  void selectTab(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      notifyListeners();
    }
  }

  Future<void> updateConnection(JiraConnection connection, String token) async {
    await connectionStore.saveConnection(connection, token);
    _currentConnection = connection;
    notifyListeners();
  }

  Future<void> removeConnection() async {
    await connectionStore.clearConnection();
    _currentConnection = null;
    notifyListeners();
  }

  void setStatusMessage(String? message) {
    _statusMessage = message;
    notifyListeners();
  }

  void clearStatusMessage() {
    if (_statusMessage != null) {
      _statusMessage = null;
      notifyListeners();
    }
  }
}
